# SonarSource GitHub Action for pre-commit

![GitHub Release](https://img.shields.io/github/v/release/SonarSource/gh-action_pre-commit)
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=SonarSource_gh-action_pre-commit&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=SonarSource_gh-action_pre-commit)
[![.github/workflows/it-test.yml](https://github.com/SonarSource/gh-action_pre-commit/actions/workflows/it-test.yml/badge.svg)](https://github.com/SonarSource/gh-action_pre-commit/actions/workflows/it-test.yml)

Run [pre-commit](https://pre-commit.com/) hooks at CI level

## Usage

### enforce pre-commit only to files changed within a pull request

Place a `.pre-commit-config.yaml` at the root of your project

Create a new GitHub workflow:

```yaml
# .github/workflows/pre-commit.yml
on:
  pull_request:

jobs:
  pre-commit:
    name: "pre-commit"
    runs-on: ubuntu-latest
    steps:
      - uses: SonarSource/gh-action_pre-commit@0.0.1 <--- replace with last tag
        with:
          extra-args: --from-ref=origin/${{ github.event.pull_request.base.ref }} \
            --to-ref=${{ github.event.pull_request.head.sha }}
```

> Notice: the extra-args parameter defined upper ensure that only files changed within the PR are checked by pre-commit.
> If you rather like to ensure that **all files** are valid, then use `extra-args: --all-files` instead.

## Options

| Option name     | Description                                                        | Default                   |
|-----------------|--------------------------------------------------------------------|---------------------------|
| `config-path`   | Used to specify a custom path to a given `.pre-commit-config.yaml` | `.pre-commit-config.yaml` |
| `extra-args`    | Used to pass extra pre-commit args to the pre-commit run command   | -                         |
| `ignore-failure` | Used to not fail the gh-action in case of pre-commit check failure | `false`                    |

## Versioning

This project is using [Semantic Versioning](https://semver.org/).

The `master` branch shall not be referenced by end-users,
please use tags instead and Renovate to stay up to date.

See [GitHub: Using tags for release management](https://docs.github.com/en/actions/creating-actions/about-custom-actions#using-tags-for-release-management)
and [GitHub: Keeping your actions up to date with Dependabot](https://docs.github.com/en/code-security/supply-chain-security/keeping-your-dependencies-updated-automatically/keeping-your-actions-up-to-date-with-dependabot)

## Contribute

Contributions are welcome, please have a look at [DEV.md](./DEV.md)
