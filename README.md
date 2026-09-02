# SonarSource GitHub Action for pre-commit

![GitHub Release](https://img.shields.io/github/v/release/SonarSource/gh-action_pre-commit)
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=SonarSource_gh-action_pre-commit&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=SonarSource_gh-action_pre-commit)
[![.github/workflows/it-test.yml](https://github.com/SonarSource/gh-action_pre-commit/actions/workflows/it-test.yml/badge.svg)](https://github.com/SonarSource/gh-action_pre-commit/actions/workflows/it-test.yml)

Run [pre-commit](https://pre-commit.com/) hooks at CI level.

This action is for **SonarSource internal** repositories. It authenticates to Vault and routes pip/npm downloads through
Repox so hooks can install on `sonar-*` runners where those public registries are blocked. Node runtimes keep using
nodeenv's default `https://nodejs.org/download/release/` (not blocked).

## Breaking change (major version)

Routing installs through Repox is a **breaking change** and will be released as a **major version**. Existing 1.x pins
keep the previous behavior until callers upgrade.

After upgrading:

- The calling job **must** grant `id-token: write` (Vault OIDC) and `contents: read`.
- Workflows without that permission, **fork PRs** (no org Vault OIDC), and runners **without Repox/Vault** (typical
  `ubuntu-latest` outside Sonar CI) will fail at credential fetch. That is expected.

## Usage

### enforce pre-commit only to files changed within a pull request

Place a `.pre-commit-config.yaml` at the root of your project.

Create a new GitHub workflow:

```yaml
# .github/workflows/pre-commit.yml
on:
  pull_request:

jobs:
  pre-commit:
    name: "pre-commit"
    runs-on: sonar-xs
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: SonarSource/gh-action_pre-commit@0.0.1 <--- replace with the last major tag
        with:
          extra-args: >
            --from-ref=origin/${{ github.event.pull_request.base.ref }}
            --to-ref=${{ github.event.pull_request.head.sha }}
```

> Notice: the extra-args parameter defined upper ensure that only files changed within the PR are checked by pre-commit.
> If you rather like to ensure that **all files** are valid, have a look at the example below.

### enforce pre-commit to all files systematically

Place a `.pre-commit-config.yaml` at the root of your project.

Create a new GitHub workflow:

```yaml
# .github/workflows/pre-commit.yml
on:
  branch:
    - master

jobs:
  pre-commit:
    name: "pre-commit"
    runs-on: sonar-xs
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: SonarSource/gh-action_pre-commit@0.0.1 <--- replace with last major tag
        with:
          extra-args: --all-files
```

## Options

| Option name      | Description                                                        | Default                   |
| ---------------- | ------------------------------------------------------------------ | ------------------------- |
| `config-path`    | Used to specify a custom path to a given `.pre-commit-config.yaml` | `.pre-commit-config.yaml` |
| `extra-args`     | Used to pass extra pre-commit args to the pre-commit run command   | -                         |
| `ignore-failure` | Used to not fail the gh-action in case of pre-commit check failure | `false`                   |

### Required job permissions

| Permission        | Why                                                                   |
| ----------------- | --------------------------------------------------------------------- |
| `id-token: write` | Lets the action authenticate to Vault and configure Repox for pip/npm |
| `contents: read`  | Checkout and hook installation                                        |

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
