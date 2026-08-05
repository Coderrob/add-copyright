# Devcontainer for local end-to-end testing with act

This devcontainer runs the repository's Bash tests and GitHub Action integration test in a reproducible environment.

## What this provides

- Ubuntu 24.04 LTS with the repository's command-line dependencies.
- `act`, installed through a locked Dev Container feature.
- Docker-outside-of-Docker support so `act` can start runner containers as the normal `vscode` user.
- The official Dev Container CLI as the canonical build and validation path.

## Quick start

From the host, with Docker, Node.js, `npx`, and Bash available:

```bash
./scripts/validate_devcontainer.sh
```

This uses the pinned `@devcontainers/cli` version to build the complete configuration, recreate its container, and execute both test suites inside it. It validates the Dockerfile, features, feature lockfile, remote user, and Docker socket integration—not just the base Dockerfile. Any existing container for this workspace is replaced so stale dependencies cannot affect the result.

If Make is available, `make validate-devcontainer` runs the same script.

To work interactively, open the repository in Visual Studio Code and choose **Dev Containers: Reopen in Container**. Then run:

```bash
make test
make test-act
```

## What the integration test does

- Creates JavaScript and Python fixtures in the isolated Actions runner.
- Invokes the local composite action twice.
- Verifies the copyright holder, current year, full MIT notice, and original source content.
- Verifies that the calling repository contains changes after the first run.
- Verifies byte-for-byte idempotency after the second run.

## Make targets

- `make build-devcontainer` builds the full configuration with the Dev Container CLI.
- `make validate-devcontainer` builds, starts, and validates everything inside the container.
- `make test-act` runs only the `act` integration test from an already-running devcontainer.

## Troubleshooting

### Devcontainer build fails or is slow

- Ensure Docker Desktop or the Docker daemon is running and has sufficient resources.
- Retry `make build-devcontainer`; feature and image downloads may be transient.
- Keep `.devcontainer/devcontainer-lock.json` committed so feature versions remain reproducible.

### `act` is unavailable

Run `act --version` inside the container. If it is missing, rebuild with `make build-devcontainer` so the Dev Container CLI reapplies the configured features.

### Docker is unavailable to `act`

Run `docker version` inside the container. Reopen or recreate the devcontainer if the Docker socket feature was added after the container was created.

### Workflow behavior differs from GitHub-hosted runners

`act` uses `catthehacker/ubuntu:act-latest`, which approximates but does not exactly duplicate a GitHub-hosted runner. Use the hosted CI run as the final compatibility check for runner-specific behavior.
