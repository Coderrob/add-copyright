SHELL := /bin/bash

.PHONY: help build-devcontainer validate-devcontainer test test-act open-devcontainer

help:
	@echo "Usage: make <target>"
	@echo "Targets:"
	@echo "  help                 Show this help"
	@echo "  build-devcontainer   Build the complete devcontainer with the Dev Container CLI"
	@echo "  validate-devcontainer Build, start, and run all tests in the devcontainer"
	@echo "  test                 Run the bash test suite"
	@echo "  test-act             Run the act-based integration test (requires act in PATH or run inside the devcontainer)"
	@echo "  open-devcontainer    Tip for opening the repo in VS Code Dev Container"

build-devcontainer:
	@echo "Building devcontainer (including features) with the Dev Container CLI..."
	@npx --yes @devcontainers/cli@0.88.0 build --workspace-folder .

validate-devcontainer:
	@bash ./scripts/validate_devcontainer.sh

test:
	@echo "Running bash test suite..."
	@chmod +x ./scripts/run_tests.sh || true
	@./scripts/run_tests.sh

test-act:
	@echo "Preparing to run act test..."
	@chmod +x ./scripts/run_act_test.sh || true
	@./scripts/run_act_test.sh

open-devcontainer:
	@echo "Open this repository in VS Code and select: 'Dev Containers: Reopen in Container'"
	@echo "If you have the devcontainer CLI installed you can also run:"
	@echo "  devcontainer up --workspace-folder ."
