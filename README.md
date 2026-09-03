# SonarSource GitHub Action for pre-commit

![GitHub Release](https://img.shields.io/github/v/release/SonarSource/gh-action_pre-commit)
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=SonarSource_gh-action_pre-commit&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=SonarSource_gh-action_pre-commit)
[![.github/workflows/it-test.yml](https://github.com/SonarSource/gh-action_pre-commit/actions/workflows/it-test.yml/badge.svg)](https://github.com/SonarSource/gh-action_pre-commit/actions/workflows/it-test.yml)

Run [pre-commit](https://pre-commit.com/) hooks at CI level.

This action is for **SonarSource internal** repositories. It authenticates to Vault and routes pip/npm downloads through
Repox so hooks can install on `sonar-*` runners where those public registries are blocked. Node runtimes keep using
nodeenv's default `https://nodejs.org/download/release/` (not blocked).

## Breaking change (v2)

v2 is a **major version**. Existing 1.x pins keep the previous behavior until callers upgrade.

- **`id-token: write` is required** (Vault OIDC for Repox). `contents: read` was already required. Workflows without
  `id-token: write` and **fork PRs** (no org Vault OIDC) will fail at credential fetch. That is expected.
- **Branch triggers are supported.** On `push` / `workflow_dispatch` (and other non-PR events) the action
  defaults to `--all-files`.
- **PRs default to diff validation.** You no longer need `extra-args` with `--from-ref` / `--to-ref`;
  that is the default on `pull_request`.

If the job has already cloned this repository (`origin` owner/repo matches), the action **skips**
`actions/checkout`. If `--from-ref` / `--to-ref` are missing locally, it runs `git fetch origin`.
That fetch uses credentials persisted by the caller's `actions/checkout` (`persist-credentials: true`,
the default). Do not set `persist-credentials: false` unless the needed refs are already local
(`fetch-depth: 0`).

## Usage

Place a `.pre-commit-config.yaml` at the root of your project.

On pull requests the action checks files changed in the PR. On branch events it checks all files.

```yaml
# .github/workflows/pre-commit.yml
on:
  pull_request:
  push:
    branches:
      - master

jobs:
  pre-commit:
    name: "pre-commit"
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

`fetch-depth: 0` makes `--from-ref` / `--to-ref` resolvable. If checkout is omitted, this action clones
the repo itself. When checkout is skipped, this action still expects persisted credentials from
`actions/checkout` so it can fetch missing refs. Pass `extra-args` only when you need different
pre-commit flags.

## Options

| Option name      | Description                                                               | Default                                         |
| ---------------- | ------------------------------------------------------------------------- | ----------------------------------------------- |
| `config-path`    | Used to specify a custom path to a given `.pre-commit-config.yaml`        | `.pre-commit-config.yaml`                       |
| `extra-args`     | Extra args for `pre-commit run`. PR: changed files; branch: `--all-files` | PR: `--from-ref`/`--to-ref`; else `--all-files` |
| `ignore-failure` | Used to not fail the gh-action in case of pre-commit check failure        | `false`                                         |

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
