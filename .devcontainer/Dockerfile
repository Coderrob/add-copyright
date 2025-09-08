# See https://aka.ms/vscode-remote/devcontainer/base.Dockerfile
FROM mcr.microsoft.com/vscode/devcontainers/base:ubuntu

# Install common tools used by the tests
RUN apt-get update && apt-get install -y --no-install-recommends \
  git \
  curl \
  ca-certificates \
  bash \
  jq \
  && rm -rf /var/lib/apt/lists/*

USER vscode
