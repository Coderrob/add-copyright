SHELL := /bin/bash

.PHONY: help build-devcontainer test-act open-devcontainer

help:
	@echo "Usage: make <target>"
	@echo "Targets:"
	@echo "  help                 Show this help"
	@echo "  build-devcontainer   Build the devcontainer Docker image (features not applied by plain docker build)"
	@echo "  test-act             Run the act-based integration test (requires act in PATH or run inside the devcontainer)"
	@echo "  open-devcontainer    Tip for opening the repo in VS Code Dev Container"

build-devcontainer:
	@echo "Building devcontainer image (.devcontainer/Dockerfile) as add-copyright-devcontainer..."
	@docker build -f .devcontainer/Dockerfile -t add-copyright-devcontainer .

test-act:
	@echo "Preparing to run act test..."
	@chmod +x ./scripts/run_act_test.sh || true
	@./scripts/run_act_test.sh

open-devcontainer:
	@echo "Open this repository in VS Code and select: 'Dev Containers: Reopen in Container'"
	@echo "If you have the devcontainer CLI installed you can also run:"
	@echo "  devcontainer open ."
