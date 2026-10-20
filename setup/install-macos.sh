#!/usr/bin/env bash
# Installs the lab toolchain on macOS with Homebrew:
#   Docker Desktop, kubectl, Minikube, Python 3.12, git, and the Python packages
#   in requirements.txt (into .venv). AppArmor is Linux-only and is skipped.
# Safe to re-run: anything already installed is skipped.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=setup/common.sh
source "$SCRIPT_DIR/common.sh"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script is for macOS. On Ubuntu or WSL2 run setup/install-ubuntu.sh." >&2
  exit 1
fi

load_brew() {
  local b
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$b" ]]; then
      eval "$("$b" shellenv)"
      return 0
    fi
  done
  return 1
}

brew_install() {
  if brew list --formula "$1" >/dev/null 2>&1; then
    echo "✓ $1 already installed"
  else
    brew install "$1"
  fi
}

step "Homebrew"
command -v brew >/dev/null 2>&1 || load_brew || true
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  load_brew
fi
brew --version | head -1

step "git"
if command -v git >/dev/null 2>&1; then
  echo "✓ $(git --version)"
else
  brew_install git
fi

step "kubectl and Minikube"
brew_install kubernetes-cli
brew_install minikube

step "Python 3.12"
if PY="$(find_python)"; then
  echo "✓ $("$PY" --version) at $PY"
else
  brew_install python@3.12
fi

step "Docker Desktop"
if [[ -d /Applications/Docker.app ]] || brew list --cask docker-desktop >/dev/null 2>&1; then
  echo "✓ Docker Desktop already installed"
else
  brew install --cask docker-desktop
fi
if ! docker info >/dev/null 2>&1; then
  echo "Docker isn't running yet. Starting Docker Desktop..."
  open -a Docker || true
  echo "Accept the licence prompt if one appears, then wait until Docker Desktop says it's running."
  echo "Give it at least 4 CPUs and 8 GB RAM (Settings > Resources) for the 3-node cluster in Exercise 10."
fi

step "AppArmor"
echo "Skipped: AppArmor is Linux-only. Exercise 5 needs a native Ubuntu machine or VM."

step "Python virtual environment (.venv)"
"$SCRIPT_DIR/setup-python-venv.sh"

step "Done"
echo "Check everything with:  setup/verify.sh"
