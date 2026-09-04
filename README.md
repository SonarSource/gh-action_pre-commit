# SonarSource GitHub Action for pre-commit

![GitHub Release](https://img.shields.io/github/v/release/SonarSource/gh-action_pre-commit)
![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=SonarSource_gh-action_pre-commit&metric=alert_status)
![.github/workflows/it-test.yml](https://github.com/SonarSource/gh-action_pre-commit/actions/workflows/it-test.yml/badge.svg)

Run [pre-commit](https://pre-commit.com/) hooks at CI level.

This action is for **SonarSource internal** repositories. It authenticates to Vault and routes pip/npm downloads through
Repox so hooks can install on `sonar-*` runners where those public registries are blocked. Node runtimes keep using
nodeenv's default `https://nodejs.org/download/release/` (not blocked).

## `v2` breaking changes

### Permission changes

- `id-token: write` permission is now required
- The repository must be granted Vault access to the Artifactory `private-reader` / `public-reader` token used for Repox
authentication (the reader is chosen from the repository visibility)

### Input and output parameter changes

- `extra-args` now has event-based defaults. Drop the old PR-only `--from-ref` / `--to-ref` to use the now automatically
supported `merge_group` and `push` triggers:
  - on `pull_request` and `merge_group` events: incremental `--from-ref` / `--to-ref` (`base`...`head`).
  - on `push`, `workflow_dispatch`, and other events: `--all-files`.
- `ignore-failure` input is removed and can be safely dropped from the workflow. Hook failures now always fail the
action step, including on `push` and `merge_group` triggers.
- `status` and `logs` outputs are removed.

### Pre-commit version update

- The action installs the `pre-commit` CLI only when it is not already available in the environment. `v1` installed
  `3.7.1`; `v2` installs `4.6.2`. If a caller already provides `pre-commit` on `PATH` (for example using
  `SonarSource/mise-action-wrapper`), that version is used unchanged.

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

This project uses [Semantic Versioning](https://semver.org/). Tags and `v*` branches follow the same pattern as
[ci-github-actions](https://github.com/SonarSource/ci-github-actions).

The `master` branch shall not be referenced by end-users. Pin a release [tag](#tags) or a major-version
[branch](#branches), and use [Renovate](https://docs.renovatebot.com/) or
[Dependabot](https://docs.github.com/en/code-security/dependabot) to stay up to date.

### Tags

Releases are GitHub tags such as [2.0.0](https://github.com/SonarSource/gh-action_pre-commit/releases/tag/2.0.0):

```yaml
- uses: SonarSource/gh-action_pre-commit@2.0.0
```

### Branches

Branches prefixed with `v` point at the latest tag of that major version, for example
[`v2`](https://github.com/SonarSource/gh-action_pre-commit/tree/v2) and
[`v1`](https://github.com/SonarSource/gh-action_pre-commit/tree/v1). After each release the matching `v*` branch is
updated to the new tag.

```yaml
- uses: SonarSource/gh-action_pre-commit@v2
```

## Upgrade notes

Callers typically pin the major-version branch (`@v1`, `@v2`). That branch is moved to each new tag of that major line
after a release, so patch and minor updates are picked up without a workflow change.

To pin a specific release instead, use the semver tag (`@2.0.0`).

To upgrade across a major version, change the pin (`@v1` → `@v2`) and apply the
`v2` [breaking changes](#v2-breaking-changes).

## Release

Follow semantic versioning when choosing the new version number:

- Increase the **patch** number for **bug fixes**, **improvements**, and **documentation updates**,
- Increase the **minor** number for **new features**,
- Increase the **major** number for **breaking changes**.

1. Create a new GitHub release on
   [https://github.com/SonarSource/gh-action_pre-commit/releases](https://github.com/SonarSource/gh-action_pre-commit/releases).
   Edit the generated release notes to curate the highlights and key fixes. Include any **breaking changes**.
2. After release, the `v*` branch must be updated for pointing to the new tag.

   ```shell
    git fetch --tags
    git update-ref -m "reset: update branch v2 to tag 2.y.z" refs/heads/v2 2.y.z
    git push origin v2
   ```

3. Communicate the new release on the
   [#ops-platform-releases](https://sonarsource.enterprise.slack.com/archives/C0A6RL3L9BP) Slack channel. Communicate
   major updates, changes and migrations that require action from users following as indicated in the
   [Updates, Changes and Migrations for Squads - Platform](https://xtranet-sonarsource.atlassian.net/wiki/spaces/Platform/pages/4385374219/Updates+Changes+and+Migrations+for+Squads+-+Platform#Usage-of-Communication-Channels)
   xtranet page.

## Contribute

Contributions are welcome, please have a look at [DEV.md](./DEV.md)
