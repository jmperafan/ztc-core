"""
Drop warehouse objects that this dbt project no longer owns.

Two independent modes:

    --ci-schemas   Drop the per-PR CI schemas (CI_PR_<n>_*) for given PRs.
                   These are ephemeral by construction: the CI job creates them
                   via schema_override and nothing ever removes them.

    --orphans      Drop relations that live in one of THIS project's own schemas
                   but no longer correspond to a node in target/manifest.json
                   (i.e. a model was deleted from the repo, so dbt stopped
                   managing the table but never dropped it).

Requires:
    pip install snowflake-connector-python cryptography

Authenticates with an RSA key pair; Snowflake retired username+password auth.

SAFETY
------
ANALYTICS_DEV is a shared sandbox: it holds schemas belonging to many other
people and unrelated workloads. So this script never decides on its own what
"looks unused". It will only ever drop something that clears every one of:

  1. The schema matches an explicit allowlist pattern for the chosen mode.
     In --orphans mode that allowlist is derived from the manifest itself, so
     the script cannot wander into a schema this project does not write to.
  2. The schema is not on the hard denylist (RAW, INFORMATION_SCHEMA, ...).
  3. The manifest passed a sanity check. A truncated or failed `dbt parse`
     would make every relation look orphaned, so a manifest with implausibly
     few nodes aborts the run instead of dropping the whole project.
  4. --apply was passed. Without it this is a dry run and only prints.

Environment variables (set these before running):
    SNOWFLAKE_ACCOUNT              - e.g. xy12345.us-east-1
    SNOWFLAKE_USER                 - your Snowflake username
    SNOWFLAKE_PRIVATE_KEY_PATH     - path to your PKCS#8 private key (.p8)
    SNOWFLAKE_PRIVATE_KEY_PASSPHRASE
                                   - (optional) omit for an unencrypted key
    SNOWFLAKE_ROLE                 - (optional) defaults to TRANSFORMER
    SNOWFLAKE_DATABASE             - database to clean, e.g. ANALYTICS_DEV
    SNOWFLAKE_WAREHOUSE            - your Snowflake warehouse name

Examples:
    # See what would be dropped for closed PRs 11 and 12 (no changes made)
    python scripts/cleanup_warehouse.py --ci-schemas --pr-numbers 11,12

    # Actually drop them
    python scripts/cleanup_warehouse.py --ci-schemas --pr-numbers 11,12 --apply

    # Reap every closed PR, using gh to supply the numbers
    python scripts/cleanup_warehouse.py --ci-schemas --apply --pr-numbers \\
        "$(gh pr list --state closed --limit 200 --json number \\
           --jq '[.[].number] | join(",")')"

    # Report models deleted from the repo whose tables still exist
    python scripts/cleanup_warehouse.py --orphans
"""

import argparse
import json
import os
import re
import sys

import snowflake.connector
from cryptography.hazmat.primitives import serialization

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
# Resolved in configure() rather than at import time so that --help works
# without Snowflake credentials present.
CFG: dict = {}

REQUIRED_ENV = (
    "SNOWFLAKE_ACCOUNT",
    "SNOWFLAKE_USER",
    "SNOWFLAKE_PRIVATE_KEY_PATH",
    "SNOWFLAKE_DATABASE",
    "SNOWFLAKE_WAREHOUSE",
)

MANIFEST_PATH = os.path.join(os.path.dirname(__file__), "..", "target", "manifest.json")

# Schemas that must never be dropped, whatever else the logic concludes.
DENYLIST = {
    "RAW",
    "INFORMATION_SCHEMA",
    "PUBLIC",
    "SNAPSHOTS",
}

# A `dbt parse` that failed or ran on a partial project would yield a tiny
# manifest and make every existing relation look orphaned. Refuse to act on
# anything that small.
MIN_PLAUSIBLE_NODES = 20

# --orphans only considers schemas carrying one of this project's layer
# suffixes (dbt_jperafan_core, ci_pr_26_staging, ...).
#
# This is not cosmetic. ztc-core and ztc-analytics share the same profile base
# schema (dbt_jperafan) and the same database, so the *unsuffixed* schema holds
# both projects' output. Deriving the target list from ztc-core's manifest
# alone would mark ztc-analytics' models (python_court_stats, fct_weather,
# metricflow_time_spine, ...) as orphans and drop them. Restricting to
# suffixed schemas keeps each project inside relations it genuinely owns.
LAYER_SCHEMA_RE = re.compile(r"_(STAGING|INTERMEDIATE|CORE)$")

# Per-PR CI schemas, e.g. CI_PR_26, CI_PR_26_CORE. The PR number is captured so
# a schema is only ever dropped for a PR the caller explicitly named.
CI_SCHEMA_RE = re.compile(r"^CI_PR_(\d+)(?:_(?P<suffix>.*))?$")

# ztc-core and ztc-analytics run CI against the SAME database and both name
# their PR schemas ci_pr_<number>, so the number alone does not identify a
# repo — ztc-core PR 6 and ztc-analytics PR 6 both map to CI_PR_6. Snowflake is
# no help either: every schema is owned by the shared TRANSFORMER role.
#
# What does distinguish them is the layer suffix. ztc-core writes
# staging/intermediate/core (plus watermark, historically); ztc-analytics writes
# marts/metrics. So only suffixes this project owns are eligible for automated
# dropping. Anything else — a bare CI_PR_<n>, or _MARTS which BOTH projects have
# used at different times — is reported for a human to look at, never dropped.
CI_OWNED_SUFFIXES = {"STAGING", "INTERMEDIATE", "CORE", "WATERMARK"}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def configure():
    """Read and validate the Snowflake environment into CFG."""
    missing = [name for name in REQUIRED_ENV if not os.environ.get(name)]
    if missing:
        sys.exit("Missing required environment variable(s): %s" % ", ".join(missing))

    CFG.update(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        private_key_path=os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"],
        private_key_passphrase=os.environ.get("SNOWFLAKE_PRIVATE_KEY_PASSPHRASE"),
        role=os.environ.get("SNOWFLAKE_ROLE", "TRANSFORMER"),
        database=os.environ["SNOWFLAKE_DATABASE"],
        warehouse=os.environ["SNOWFLAKE_WAREHOUSE"],
    )


def load_private_key() -> bytes:
    """Read the PKCS#8 key and hand it to the connector as unencrypted DER.

    The connector wants raw DER bytes, not a PEM path, so the passphrase is
    applied here and the decrypted key only ever exists in memory.
    """
    phrase = CFG["private_key_passphrase"]
    passphrase = phrase.encode() if phrase else None
    with open(CFG["private_key_path"], "rb") as f:
        key = serialization.load_pem_private_key(f.read(), password=passphrase)
    return key.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )


def get_connection():
    return snowflake.connector.connect(
        account=CFG["account"],
        user=CFG["user"],
        private_key=load_private_key(),
        role=CFG["role"],
        warehouse=CFG["warehouse"],
        database=CFG["database"],
    )


def load_manifest() -> dict:
    if not os.path.exists(MANIFEST_PATH):
        sys.exit("No manifest at %s — run `dbt parse` first." % MANIFEST_PATH)
    with open(MANIFEST_PATH) as f:
        manifest = json.load(f)

    nodes = manifest.get("nodes") or {}
    if len(nodes) < MIN_PLAUSIBLE_NODES:
        sys.exit(
            "Refusing to continue: manifest has only %d nodes (expected at least "
            "%d). A failed or partial `dbt parse` would make healthy tables look "
            "orphaned." % (len(nodes), MIN_PLAUSIBLE_NODES)
        )
    return manifest


def managed_relations(manifest: dict) -> tuple[set[str], set[tuple[str, str]]]:
    """Return (schemas this project writes to, {(schema, relation_name)}).

    Only materialized node types are considered: a relation that dbt never
    creates cannot be an orphan of one.
    """
    schemas: set[str] = set()
    relations: set[tuple[str, str]] = set()

    materialized_types = {"model", "snapshot", "seed"}
    for section in ("nodes", "sources"):
        for key, node in (manifest.get(section) or {}).items():
            if (
                section == "nodes"
                and node.get("resource_type") not in materialized_types
            ):
                continue
            if (node.get("database") or "").upper() != CFG["database"].upper():
                continue
            schema = (node.get("schema") or "").upper()
            name = (node.get("alias") or node.get("name") or "").upper()
            if not schema or not name:
                continue
            if section == "nodes":
                schemas.add(schema)
            relations.add((schema, name))
    return schemas, relations


def fetch_relations(cur, schemas: set[str]) -> list[tuple[str, str, str]]:
    """Return [(schema, name, kind)] for every relation in the given schemas."""
    if not schemas:
        return []
    placeholders = ", ".join(["%s"] * len(schemas))
    cur.execute(
        """
        SELECT table_schema, table_name, table_type
        FROM information_schema.tables
        WHERE table_schema IN (%s)
        ORDER BY table_schema, table_name
        """ % placeholders,
        tuple(sorted(schemas)),
    )
    return [(r[0].upper(), r[1].upper(), r[2]) for r in cur.fetchall()]


def fetch_ci_schemas(cur, pr_numbers: set[int]) -> tuple[list[str], list[str]]:
    """Return (droppable, ambiguous) CI schemas for the given PR numbers.

    `droppable` carries a layer suffix this project owns; `ambiguous` matches a
    named PR but could belong to ztc-analytics, so the caller must not drop it.

    Filtering happens in Python rather than via LIKE: the pattern needs literal
    underscores, and Snowflake also treats backslash as an escape inside string
    literals, which makes `ESCAPE '\\'` awkward to get right.
    """
    cur.execute("""
        SELECT schema_name
        FROM information_schema.schemata
        ORDER BY schema_name
        """)
    droppable, ambiguous = [], []
    for (name,) in cur.fetchall():
        name = name.upper()
        m = CI_SCHEMA_RE.match(name)
        if not m or int(m.group(1)) not in pr_numbers:
            continue
        suffix = (m.group("suffix") or "").upper()
        if suffix in CI_OWNED_SUFFIXES:
            droppable.append(name)
        else:
            ambiguous.append(name)
    return droppable, ambiguous


def drop(cur, statement: str, apply: bool):
    print("  {}{}".format("" if apply else "[dry run] ", statement))
    if apply:
        cur.execute(statement)


# ---------------------------------------------------------------------------
# Modes
# ---------------------------------------------------------------------------
def clean_ci_schemas(cur, pr_numbers: set[int], apply: bool) -> int:
    droppable, ambiguous = fetch_ci_schemas(cur, pr_numbers)

    if ambiguous:
        print(
            "Leaving %d CI schema(s) alone — no layer suffix this project owns, "
            "so they may belong to ztc-analytics. Review by hand:" % len(ambiguous)
        )
        for schema in ambiguous:
            print("  SKIP (ambiguous owner): %s" % schema)
        print("")

    if not droppable:
        print("No CI schemas owned by this project found for the given PRs.")
        return 0

    print(
        "Dropping %d CI schema(s) for PR(s) %s:"
        % (len(droppable), ", ".join(str(n) for n in sorted(pr_numbers)))
    )
    for schema in droppable:
        if schema in DENYLIST:  # belt and braces; CI_PR_* can never match
            print("  SKIP (denylist): %s" % schema)
            continue
        drop(
            cur,
            'DROP SCHEMA IF EXISTS "{}"."{}" CASCADE'.format(CFG["database"], schema),
            apply,
        )
    return len(droppable)


def clean_orphans(cur, manifest: dict, apply: bool) -> int:
    schemas, managed = managed_relations(manifest)

    skipped = {s for s in schemas if s in DENYLIST or not LAYER_SCHEMA_RE.search(s)}
    if skipped:
        print(
            "Skipping %d schema(s) not exclusively owned by this project: %s"
            % (len(skipped), ", ".join(sorted(skipped)))
        )
    schemas = schemas - skipped

    if not schemas:
        print(
            "Manifest declares no schemas in %s — nothing to inspect." % CFG["database"]
        )
        return 0

    print(
        "Inspecting %d schema(s) this project writes to: %s"
        % (len(schemas), ", ".join(sorted(schemas)))
    )

    orphans = [
        (schema, name, kind)
        for schema, name, kind in fetch_relations(cur, schemas)
        if (schema, name) not in managed
    ]
    if not orphans:
        print("No orphaned relations found.")
        return 0

    print("Found %d orphaned relation(s):" % len(orphans))
    for schema, name, kind in orphans:
        keyword = "VIEW" if "VIEW" in kind.upper() else "TABLE"
        drop(
            cur,
            'DROP %s IF EXISTS "%s"."%s"."%s"'
            % (keyword, CFG["database"], schema, name),
            apply,
        )
    return len(orphans)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def parse_args():
    p = argparse.ArgumentParser(
        description="Drop warehouse objects this dbt project no longer owns.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument(
        "--ci-schemas",
        action="store_true",
        help="Drop per-PR CI schemas. Requires --pr-numbers.",
    )
    p.add_argument(
        "--orphans",
        action="store_true",
        help="Drop relations in this project's schemas that are not in the manifest.",
    )
    p.add_argument(
        "--pr-numbers",
        default="",
        help="Comma-separated PR numbers whose CI schemas should be dropped.",
    )
    p.add_argument(
        "--apply",
        action="store_true",
        help="Execute the drops. Without this the script only prints them.",
    )
    args = p.parse_args()

    if not (args.ci_schemas or args.orphans):
        p.error("choose at least one of --ci-schemas / --orphans")
    if args.ci_schemas and not args.pr_numbers.strip():
        # Without explicit PR numbers there is no reliable signal for which CI
        # schemas are dead, so refuse rather than guess.
        p.error("--ci-schemas requires --pr-numbers (e.g. --pr-numbers 11,12)")
    return args


def main():
    args = parse_args()
    pr_numbers = {int(n) for n in (x.strip() for x in args.pr_numbers.split(",")) if n}

    configure()
    manifest = load_manifest() if args.orphans else None

    if not args.apply:
        print("DRY RUN — nothing will be dropped. Re-run with --apply to execute.\n")

    conn = get_connection()
    total = 0
    try:
        with conn.cursor() as cur:
            if args.ci_schemas:
                total += clean_ci_schemas(cur, pr_numbers, args.apply)
            if args.orphans:
                total += clean_orphans(cur, manifest, args.apply)
    finally:
        conn.close()

    verb = "Dropped" if args.apply else "Would drop"
    print("\n%s %d object(s)." % (verb, total))


if __name__ == "__main__":
    main()
