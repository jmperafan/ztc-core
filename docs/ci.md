# CI/CD for dbt Projects

## The problem

Without CI, broken SQL ships to production. A developer changes a model, pushes to main, and the next morning the dashboard is empty or returning wrong numbers. The root cause is usually one of four things:

| Issue | Example |
| --- | --- |
| **Style drift** | Two developers format SQL differently; code review becomes about style instead of logic |
| **Convention violations** | A model is added without tests or documentation; nobody notices until it causes a downstream issue |
| **Broken SQL** | A model fails to compile or run; it reaches production before anyone catches it |
| **Unknown blast radius** | A change to a source model breaks 12 downstream models; the author only tested the one they touched |

CI solves this by running automated checks on every pull request, before any code merges.

---

## The toolchain

A mature dbt CI pipeline typically combines four tools. Each solves a different problem.

### Pre-commit hooks

**What it does**: Runs checks on the developer's machine the moment they try to commit. Catches issues before they ever reach GitHub.

**Why it matters**: The fastest possible feedback loop — problems are surfaced in seconds, not after a 5-minute CI run. It also reduces noise in pull requests: formatting issues and obvious mistakes are fixed locally before anyone else sees the code.

**Typical checks**: trailing whitespace, YAML syntax, SQL linting, blocking direct commits to `main`.

**The trade-off**: Hooks only run if the developer has installed them. They can be bypassed. Think of this as a developer quality-of-life tool, not a hard gate.

---

### SQLFluff

**What it does**: A SQL linter and auto-formatter. Enforces consistent style — capitalisation, indentation, aliasing conventions, line length, and more.

**Why it matters**: SQL style is subjective and teams argue about it. SQLFluff turns style into a configuration file instead of a conversation. Code review can focus on logic instead of formatting. It also makes diffs cleaner — if everyone's SQL is formatted the same way, changes show only the lines that actually changed.

**The trade-off**: Introducing SQLFluff on an existing project with legacy SQL requires an initial cleanup pass. Rules should be introduced incrementally rather than all at once.

---

### dbt Bouncer

**What it does**: Reads the dbt manifest (the compiled representation of your project) and enforces project conventions as code. Think of it as a linter for your project structure, not just your SQL.

**Why it matters**: As a dbt project grows, it becomes harder to enforce conventions through code review alone. dbt Bouncer makes the rules explicit and automatic:

- All staging models must be named `stg_*`
- All core models must have at least one unique test
- Staging models may only read from sources, never from other models
- No model may have more than 10 downstream dependents

When a rule is violated, dbt Bouncer posts a comment directly on the pull request explaining what failed and why. The author fixes it before the PR merges — not six months later when the technical debt has compounded.

**The trade-off**: Rules need to be defined upfront. This requires agreeing on conventions before automating them. It's an investment, but it pays off quickly on teams larger than two or three people.

---

### dbt Cloud CI

**What it does**: dbt Cloud's built-in CI feature. When a pull request is opened, dbt Cloud automatically runs a dbt build and posts the result as a GitHub status check. The PR cannot merge until the build passes.

**Why it matters**: This is the hard gate. Pre-commit and SQLFluff catch style issues early; dbt Bouncer enforces conventions; dbt Cloud CI verifies that the SQL actually runs without errors against real data.

The key feature is **Slim CI**: instead of rebuilding the entire project on every PR (which could take 30+ minutes on a large project), dbt Cloud builds only the models that changed and their downstream dependents. Everything else is deferred to the last production state. On a large project, this reduces CI run time from 30 minutes to under 2 minutes.

Each PR runs in its own isolated schema, so CI never touches development or production data.

**The trade-off**: Requires a dbt Cloud account. The Slim CI defer feature requires a successful production run to defer against.

---

## How it fits together

```
Developer commits locally
      │
      ▼
Pre-commit hooks ── instant feedback, style + syntax
      │
      ▼  (git push → PR opened)
      │
      ├── SQLFluff ──── consistent SQL style across all files
      │
      ├── dbt Bouncer ── naming conventions, test coverage, lineage rules
      │
      └── dbt Cloud CI ── actual dbt build, modified models only, isolated schema
```

Each layer catches a different class of problem. The earlier in the pipeline a problem is caught, the cheaper it is to fix.

---

## Is it worth implementing?

The investment is highest upfront — agreeing on conventions, writing the Bouncer rules, configuring the pipeline. After that, the maintenance is low.

The payoff is:

- **Fewer production incidents** caused by broken or untested SQL
- **Faster code review** because style and convention checks are automated
- **Confidence to refactor** because CI tells you immediately if a change breaks something downstream
- **Onboarding** — new team members learn the conventions automatically from the feedback they get on their first PRs

For teams with more than two or three dbt developers, or for any project where a production failure has real business impact, this is worth implementing.
