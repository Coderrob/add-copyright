# See https://aka.ms/vscode-remote/devcontainer/base.Dockerfile
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Install common tools used by the tests
RUN apt-get update && apt-get install -y --no-install-recommends \
  git \
  curl \
  ca-certificates \
  bash \
  bats \
  jq \
  shellcheck \
  && rm -rf /var/lib/apt/lists/*

USER vscode
