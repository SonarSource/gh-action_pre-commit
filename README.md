# SonarSource GitHub Action for pre-commit

![GitHub Release](https://img.shields.io/github/v/release/SonarSource/gh-action_pre-commit)
![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=SonarSource_gh-action_pre-commit&metric=alert_status)
![.github/workflows/it-test.yml](https://github.com/SonarSource/gh-action_pre-commit/actions/workflows/it-test.yml/badge.svg)

Run [pre-commit](https://pre-commit.com/) hooks at CI level.

This action is for **SonarSource internal** repositories. It authenticates to Vault and routes pip/npm downloads through
Repox so hooks can install on `sonar-*` runners where those public registries are blocked. Node runtimes keep using
nodeenv's default `https://nodejs.org/download/release/` (not blocked).

## Breaking change (v2)

v2 is a **major version**. Existing 1.x pins keep the previous behavior until callers upgrade.

- `**id-token: write` is required** (Vault OIDC for Repox). `contents: read` was already required. Workflows without
`id-token: write` and **fork PRs** (no org Vault OIDC) will fail at credential fetch. That is expected.
- `**merge_group` is supported.** v2 defaults to incremental `--from-ref` / `--to-ref` on merge-queue events
  (`base_sha`…`head_sha`). Hook failures fail the job; do not ignore them on that trigger.
- **PRs default to the same diff validation** on `pull_request`. You no longer need `extra-args`.
- **Branch triggers are supported.** On `push` / `workflow_dispatch` (and other events) the action
defaults to `--all-files`.
- `**status` and `logs` outputs are removed.**
- `ignore-failure` **input is removed.** Hook failures fail the action step.
- **Bundled `pre-commit` is 4.6.2.** When the action installs the CLI itself (no `pre-commit` on `PATH`), it pins
  `pre-commit==4.6.2` instead of `3.7.1`. Callers that run `SonarSource/mise-action-wrapper` (or otherwise pre-install
  `pre-commit`) keep using that version. Hook caches are keyed by the CLI version and the Python interpreter in use.

If the job has already cloned this repository (`origin` owner/repo matches), the action **skips** `actions/checkout`. If
`--from-ref` / `--to-ref` are missing locally, it runs `git fetch origin`. That fetch uses credentials persisted by the
caller's `actions/checkout` (`persist-credentials: true`, the default). Do not set `persist-credentials: false` unless
the needed refs are already local (`fetch-depth: 0`).

## Usage

Place a `.pre-commit-config.yaml` at the root of your project.

On pull requests the action checks files changed in the PR. On branch events it checks all files. `merge_group` is also
supported: the action defaults to incremental `--from-ref` / `--to-ref` on that trigger (`base_sha`…`head_sha`).

Hook runtimes are not installed by this action. If a hook needs a language or tool on the runner (`language: system` /
`language: script`, a specific Python for `language_version`, Go, Ruby, and so on), install it in an earlier step (for
example `SonarSource/mise-action-wrapper`) before this action runs.

```yaml
# .github/workflows/pre-commit.yml
on:
  pull_request:
  push:
    branches:
      - master

name: pre-commit

jobs:
  pre-commit:
    runs-on: sonar-xs
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0
      - uses: SonarSource/gh-action_pre-commit@v2
```

`fetch-depth: 0` makes `--from-ref` / `--to-ref` resolvable. If checkout is omitted, this action clones the repo itself.
When checkout is skipped, this action still expects persisted credentials from `actions/checkout` so it can fetch
missing refs. Pass `extra-args` only when you need different pre-commit flags.

### Pre-installed pre-commit

The action looks for `pre-commit` and `python3` on `PATH` independently:

- Skips `setup-python` when `python3` is already on `PATH` and reports a version.
- Skips the private venv when `pre-commit` is already on `PATH`.
- If `python3` is missing, installs Python 3.14.7 (including when `pre-commit` is already present, e.g. a mise zipapp).
- If `pre-commit` is missing, installs `pre-commit==4.6.2` into an action-private venv.

The action does not check that a pre-installed interpreter is new enough for the pre-commit version in use. Callers
that pre-install both tools are responsible for pairing them. The action's own pin is Python 3.14.7 with
`pre-commit==4.6.2` (requires Python >= 3.10). A `python` binary without `python3` is not detected; expose the
interpreter as `python3` (`SonarSource/mise-action-wrapper` does this).

The hook cache is keyed by the CLI version and the interpreter in use (the one already on `PATH`, or 3.14.7 when this
action installed it). Listing both `pre-commit` and `python` in `mise.toml` (typical after
`SonarSource/mise-action-wrapper`) skips both installs.

```yaml
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0
      - uses: SonarSource/mise-action-wrapper@v1
      - uses: SonarSource/gh-action_pre-commit@v2
```

## Options

| Option name   | Description                                                               | Default                                                       |
| ------------- | ------------------------------------------------------------------------- | ------------------------------------------------------------- |
| `config-path` | Used to specify a custom path to a given `.pre-commit-config.yaml`        | `.pre-commit-config.yaml`                                     |
| `extra-args`  | Extra args for `pre-commit run`. Diff on PR / merge queue; else all files | PR/`merge_group`: `--from-ref`/`--to-ref`; else `--all-files` |

### Required job permissions

| Permission        | Why                                                                   |
| ----------------- | --------------------------------------------------------------------- |
| `id-token: write` | Lets the action authenticate to Vault and configure Repox for pip/npm |
| `contents: read`  | Checkout, fetching refs, and cloning hook repos from github.com       |

### Package registries used by common hooks

| Registry                                     | Used by                                                              | Covered by this action                                          |
| -------------------------------------------- | -------------------------------------------------------------------- | --------------------------------------------------------------- |
| PyPI (`pypi.org`)                            | `pre-commit-hooks`, `yamllint`, `check-jsonschema`, `sonar-secrets`  | Yes (`~/.pip/pip.conf`)                                         |
| npm (`registry.npmjs.org`)                   | `markdownlint-cli`, `renovatebot/pre-commit-hooks`, `mirrors-eslint` | Yes (`NPM_CONFIG_REGISTRY`, global npmrc)                       |
| Node runtime (`nodejs.org/download/release`) | `language: node` hooks via nodeenv                                   | No — `nodejs.org` is reachable; nodeenv uses its default mirror |
| Go module proxy                              | `actionlint`, `terraform-docs` (golang hooks)                        | No — uses `proxy.golang.org`                                    |
| RubyGems                                     | `markdownlint/markdownlint` (legacy)                                 | No                                                              |
| Maven / Gradle                               | Not used by pre-commit hook runtimes in SonarSource                  | N/A                                                             |

`language: script` / `language: system` hooks (e.g. `shellcheck`, `terraform-fmt`) do not download packages.

## Versioning

This project is using [Semantic Versioning](https://semver.org/).

The `master` branch shall not be referenced by end-users, please use tags instead and
[Renovate](https://docs.renovatebot.com/) or [Dependabot](https://docs.github.com/en/code-security/dependabot) to stay
up to date.

## Contribute

Contributions are welcome, please have a look at [DEV.md](./DEV.md)
