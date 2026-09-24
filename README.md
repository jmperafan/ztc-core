# ZTC Court Usage — Demo Playground

This project uses real court reservation, member, and weather data from Zuilense Tennis Club (Utrecht, NL) as a realistic dbt dataset for client demos.

Each demo is implemented in the project and documented in [`docs/`](docs/). When a client asks about a feature, we build it here, then walk them through it using this codebase as a reference.

## Local setup

### 1. Install dependencies

```bash
pip install -r requirements-dev.txt
```

### 2. Install and authenticate the dbt platform CLI

This project runs on the dbt platform CLI. Warehouse credentials live in the
platform under **Account settings → Credentials**, so there is no `profiles.yml`,
no `.env`, and no Snowflake secret on your machine — the CLI ships the project to
a remote runner and the runner holds the connection.

Install the CLI:

```bash
brew tap dbt-labs/dbt-cli
brew install dbt
```

Download your credentials file from the platform — account name (left side menu)
→ **Account settings** → **Your profile** → **Credentials** → select the
**ztc-core** project → download `dbt_cloud.yml` — and drop it in `~/.dbt/`:

```bash
mkdir -p ~/.dbt
mv ~/Downloads/dbt_cloud.yml ~/.dbt/dbt_cloud.yml
```

That file carries an API token, so treat it as a secret. It lives outside the
repo and should never be copied into it.

The repo half of the binding is already committed — [`dbt_project.yml`](dbt_project.yml)
declares the project it belongs to, so nothing to configure there:

```yaml
dbt-cloud:
  project-id: 70437463665591
```

Confirm the whole chain with `dbt debug`.

### 3. Install pre-commit hooks

```bash
pre-commit install
```

### 4. Run dbt

```bash
dbt debug                          # verify connection
dbt build                          # run all models + tests
dbt build --select staging         # staging layer only
dbt build --select +dim_members    # dim_members and all upstream
```

## dbt platform jobs as code

The scheduled work in this project is defined in [`jobs.yml`](jobs.yml) and applied by
[dbt-jobs-as-code](https://github.com/dbt-labs/dbt-jobs-as-code). The
[`dbt jobs`](.github/workflows/dbt-jobs.yml) workflow runs `plan` on any PR that touches
that file and `sync` when it merges, so a schedule change is a reviewable diff instead of
a click in the UI.

Both commands read the same two environment variables:

```bash
export DBT_BASE_URL=https://de392.us1.dbt.com     # scheme required, unlike the CLI's host var
export DBT_API_KEY=<service token with Job Admin>
```

Then, from the repo root:

```bash
dbt-jobs-as-code validate jobs.yml            # schema + cron, offline
dbt-jobs-as-code validate jobs.yml --online   # also checks the project/environment IDs exist
dbt-jobs-as-code plan jobs.yml --limit-projects-envs-to-yml
```

`--limit-projects-envs-to-yml` is not optional in practice. This account holds four
projects, and without it the comparison covers every job in the account — any managed job
in a sibling project would read as a deletion.

### Adopting a job that already exists

The tool matches YAML to platform jobs by an identifier appended to the job name
(`deploy [[deploy]]`), not by job ID. A job without that marker is invisible to it: never
updated, never deleted. So an existing job has to be adopted once, explicitly:

```bash
dbt-jobs-as-code link jobs.yml --dry-run   # prints the renames
dbt-jobs-as-code link jobs.yml             # applies them
```

Until that has been run, `plan` reports the jobs in `jobs.yml` as *creates* — it cannot
see the ones already in the platform, and syncing would duplicate them. Run `link` before
the first merge.

### Adding a job

Copy an existing block, give it a new key (the key is the identifier — letters, digits,
`_` and `-` only), and drop `linked_id`, which only exists for adoption. To pull a job
that was created in the UI back into this file:

```bash
dbt-jobs-as-code import-jobs --account-id 70437463654961 -p 70437463665591 --include-linked-id
```

What this does not manage: environments, credentials, connections and permissions. The
environment a job points at has to exist first. Those would be the Terraform provider.
