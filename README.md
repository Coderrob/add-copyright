<p align="center">
  <img src="public/img/add-copyright-logo-small.png" alt="add-copyright logo" width="180">
</p>

# Copyright and License

Add consistent, language-aware copyright and SPDX license notices to a repository with one GitHub Actions step.

`Coderrob/add-copyright` is a composite GitHub Action backed by a portable Bash CLI. It processes supported source files in place, preserves their original content, respects Git exclusions, and avoids duplicating a current notice. The bundled compressed SPDX database supports more than 700 license identifiers without making network requests during an action run.

## Why use it?

- **Repository-local updates:** files are updated directly in the caller's checked-out workspace.
- **Language-aware comments:** block and line comment styles are selected from each file extension.
- **SPDX-backed notices:** license headers and texts come from the bundled SPDX dataset.
- **Repeatable execution:** a second run with the same year and holder leaves files unchanged.
- **Scoped operation:** select a project root or a specific working directory.
- **Git-aware discovery:** ignored files and common generated directories are skipped.
- **Observable results:** each run logs updated and skipped files plus an aggregate summary.

## Quick start

```yaml
name: Apply copyright headers

on:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  copyright:
    runs-on: ubuntu-latest
    steps:
      - name: Check out repository
        uses: actions/checkout@v6
        with:
          persist-credentials: false

      - name: Apply MIT notices
        uses: Coderrob/add-copyright@v1
        with:
          name: "Acme Corporation"
          license: MIT
          working-directory: ./src
```

The action changes the runner workspace; it does not commit or push. Review the diff in a later step, upload it as an artifact, or use a dedicated pull-request action according to your repository policy.

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `name` | Yes | — | Copyright holder written into the license notice. |
| `license` | Yes | — | SPDX license identifier such as `MIT`, `Apache-2.0`, or `BSD-3-Clause`. |
| `working-directory` | No | `.` | Directory to scan, relative to the checked-out repository. |

The action currently defines no outputs. File changes and structured log messages are its observable result.

## Behavior

For every supported source file, the action:

1. Excludes generated, editor, dependency, Git metadata, and ignored paths.
2. Resolves a bundled SPDX license record.
3. Replaces standard year, owner, and copyright placeholders.
4. Formats the notice using the file type's comment style.
5. Skips the file when the current year and holder are already present.
6. Prepends the notice while preserving the original source content.

An invalid directory, unavailable license, missing dependency, or failed file update returns a nonzero exit status. Logs identify the failing operation and the final processed/skipped/error counts.

## Supported source types

| Comment style | Extensions |
| --- | --- |
| `#` | `.sh`, `.bash`, `.py`, `.rb`, `.yml`, `.yaml` |
| `//` | `.go`, `.swift` |
| `/* ... */` | `.js`, `.ts`, `.java`, `.c`, `.cpp`, `.h`, `.hpp`, `.cs`, `.php`, `.json` |

Unsupported extensions are skipped without modifying their content.

## Common patterns

### Apply Apache-2.0 notices to the whole repository

```yaml
- uses: Coderrob/add-copyright@v1
  with:
    name: "Acme Corporation"
    license: Apache-2.0
```

### Process separate application areas

```yaml
- uses: Coderrob/add-copyright@v1
  with:
    name: "Acme Corporation"
    license: MIT
    working-directory: ./frontend

- uses: Coderrob/add-copyright@v1
  with:
    name: "Acme Corporation"
    license: MIT
    working-directory: ./backend
```

### Open automated update pull requests

Keep write permissions in the automation workflow—not in this action—and configure the checkout step without persisted credentials. This repository's maintenance workflows demonstrate that separation: the local action changes files, a change-detection step verifies the diff, and `peter-evans/create-pull-request@v8` publishes a narrowly scoped branch.

## Local CLI

The same implementation can be run without GitHub Actions:

```bash
./scripts/copyright.sh ./src MIT "Acme Corporation"
```

Required tools are Bash, Git, `find`, `grep`, `jq`, `sed`, `gzip`, and standard Unix file utilities.

Set `DEBUG=1` to include file-discovery and formatting diagnostics:

```bash
DEBUG=1 ./scripts/copyright.sh ./src Apache-2.0 "Acme Corporation"
```

## Development and validation

The canonical validation path uses the pinned official Dev Container CLI:

```bash
./scripts/validate_devcontainer.sh
```

It performs the following operations transparently:

1. Builds `.devcontainer/devcontainer.json`, including locked features.
2. Recreates the workspace container so stale dependencies cannot influence results.
3. Runs ShellCheck and the shell quality policy.
4. Runs the complete BATS suite.
5. Runs the local `action-integration` job through `act`.

The devcontainer requires Docker, Node.js, `npx`, and Bash on the host. A Make wrapper is also available:

```bash
make validate-devcontainer
```

For focused work inside an already-running devcontainer:

```bash
./scripts/run_tests.sh       # ShellCheck, quality policy, and BATS
./scripts/run_act_test.sh    # GitHub Action integration through act
bats scripts/tests/copyright.bats
```

## Shell engineering policy

All shell implementation and tests live under `scripts/`. The automated quality gate requires every Bash function to:

- have adjacent function-level documentation;
- remain at or below 25 physical lines;
- have cyclomatic complexity below 4;
- pass ShellCheck.

Functions favor local state, readonly configuration, explicit return codes, small orchestration boundaries, and log messages at externally meaningful transitions. BATS covers successful updates, idempotency, exclusions, invalid inputs, line and block comments, release behavior, workflow configuration, and compressed SPDX updates.

## License database maintenance

The monthly `Update Licenses` workflow runs `scripts/update_licenses.sh` and opens a pull request when SPDX data changes. Runtime records are stored as `licenses/<identifier>.json.gz` to keep the action checkout compact.

To test the updater without changing this checkout, use the BATS fixture:

```bash
bats scripts/tests/update_licenses.bats
```

## Troubleshooting

### The working directory is rejected

Confirm the checkout step ran first and that `working-directory` is relative to the repository root created by checkout.

### A license cannot be found

Use the canonical SPDX identifier and preserve its punctuation, for example `Apache-2.0` or `GPL-3.0-only`.

### A file was skipped

Check its extension, `.gitignore`, excluded directory, and whether a notice for the current year and holder already exists. Re-run locally with `DEBUG=1` for discovery details.

### `act` cannot reach Docker

Run validation through the devcontainer. Its Docker-outside-of-Docker feature forwards the daemon socket and configures access for the `vscode` user.

## Security model

The action itself requires no token and performs no network or Git write operations. Callers control checkout credentials, workflow permissions, commits, pushes, and pull requests. Use least-privilege permissions and keep write access limited to the job that publishes reviewed changes.

## License

This project is distributed under the [Apache License 2.0](LICENSE).
