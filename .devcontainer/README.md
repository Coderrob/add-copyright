# Devcontainer for local end-to-end testing with act

This devcontainer config installs the `act` feature from the devcontainer feature marketplace so you can run GitHub Actions locally inside the container.

How to use

- Open this repository in VS Code.

- Reopen in Container (Dev Containers: Reopen in Container). The devcontainer will build and include the `act` feature.
# Devcontainer for local end-to-end testing with act

This devcontainer helps you run the repository's GitHub Action locally using the `act` tool.

## What this provides

- A reproducible container environment for running the `Test Action Locally` workflow defined in `.github/workflows/test-action.yml`.

- The `act` tool available inside the container (installed via the devcontainer feature) so you can execute GitHub workflows locally.

## Quick start

1. Open this repository in Visual Studio Code.

2. Reopen in Container: open the command palette (Ctrl+Shift+P) and choose "Dev Containers: Reopen in Container". VS Code will build the devcontainer using `.devcontainer/Dockerfile` and apply features (including `act`).

3. In the VS Code terminal (inside the container) make the test helper executable and run it:

```bash
chmod +x ./scripts/run_act_test.sh
./scripts/run_act_test.sh
```

## What the test does

- Creates a small sample file under `src/`.

- Invokes the composite action in this repository (uses: ./) with sample inputs.

- Prints the `act` output so you can inspect logs and the exit code.

## Recommended Make targets

- `make test-act` — runs `./scripts/run_act_test.sh` (this target will `chmod` the script first).

## Troubleshooting

### Devcontainer build fails or is slow

- Problem: building the devcontainer can fail due to network issues, Docker daemon limits, or missing features.

- Remediation:

	- Ensure Docker Desktop (or your Docker daemon) is running and has sufficient resources (memory, CPUs).

	- Re-run the Reopen in Container command. Use the "Rebuild Container" option if prompted.

	- If the build fails with a missing feature, ensure your VS Code and Dev Containers extension are up-to-date.

### `act` command not found inside the container

- Problem: the devcontainer feature didn't install or the feature version is not available.

- Remediation:

	- Inside the container run `which act` and `act --version` to verify presence.

	- Rebuild the devcontainer. In VS Code, use "Dev Containers: Rebuild Container".

	- If the feature still fails, install `act` manually inside the container for debugging only:

```bash
curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
```

### Workflow fails under `act` but passes on GitHub

- Problem: `act` uses a different runner image and may not provide the same environment (pre-installed tools, secrets, or service containers).

- Remediation:

	- Inspect the logs `act` prints; they usually include the failing command and stdout/stderr.

	- Pass required environment variables or secrets to `act`, for example:

```bash
act -s GITHUB_TOKEN=xxx -e event.json
```

	- If the workflow requires a different runner, use `act`'s `-P` mapping or `--container-architecture` options to select a compatible image.

### Scripts lack execute permission on Windows

- Problem: Windows filesystem may not preserve the executable bit; inside the container the script may be non-executable.

- Remediation:

	- Run `chmod +x ./scripts/run_act_test.sh` inside the container (the Makefile target `make test-act` will attempt to `chmod` first).

### Action fails to find its bundled scripts (permission or path errors)

- Problem: `action.yml` used expressions like `${{ github.action_path }}` inside `run:` steps which are not available at runtime.

- Remediation:

	- This repository's `action.yml` has been updated to use the runtime environment variable `$GITHUB_ACTION_PATH`. If you still see errors referencing `github.action_path`, ensure your local checkout includes the updated file and re-run the test.

### `act` network or Docker permission problems

- Problem: `act` needs Docker and network access to pull images and run jobs.

- Remediation:

	- Ensure the Docker daemon is accessible to your user. On Linux, add your user to the `docker` group or run with `sudo`.

	- If `act` fails pulling images, pre-pull commonly used images or give `act` the `--reuse` flag to reuse pulled images.

If you hit an error not covered here, paste the relevant `act` logs and I can suggest targeted fixes.

