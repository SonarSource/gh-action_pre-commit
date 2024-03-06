# Developer notes

> You want to contribute to this project ? Please read the following

## IT Tests

This project define integrations tests in `.github/workflows/it-test.yml`.

Test assertions are done using [nick-fields/assert-action](https://github.com/nick-fields/assert-action).

Resources used for tests are placed within `.github/tests/resources/` directory

### Side note

At the moment, GitHub branch protection do not allow to define checks based
on a REGEX as we can find in other CI tools such as Jenkins.

In order to work around this limitation this project make
use of [re-actors/alls-green](https://github.com/re-actors/alls-green).

All tests have to be declared in `.github/workflows/it-test.yml`
the job called `it-tests` declares a list of needs:

```yaml
    ...
    needs:
       ...
      - it-tests-output-logs-failure
      - it-tests-output-logs-success
      - < your new test > <-------------- Add your tests here
```
