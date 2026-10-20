#!/usr/bin/env bash
# Installs the lab toolchain on Ubuntu 22.04/24.04, on a native machine or inside WSL2:
#   Docker Engine (native Linux only; WSL2 uses Docker Desktop), kubectl, Minikube,
#   Python 3.10+, git, apparmor-utils, and the Python packages in requirements.txt.
# Safe to re-run: anything already installed is skipped.
#
# To install Docker Engine inside WSL2 instead of using Docker Desktop:
#   INSTALL_DOCKER_ENGINE_IN_WSL=1 setup/install-ubuntu.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=setup/common.sh
source "$SCRIPT_DIR/common.sh"

if [[ "$(uname -s)" != "Linux" ]] || ! command -v apt-get >/dev/null 2>&1; then
  echo "This script is for Ubuntu (native or WSL2). On macOS run setup/install-macos.sh." >&2
  exit 1
fi

SUDO=""
[[ $EUID -ne 0 ]] && SUDO="sudo"
ARCH="$(linux_arch)"
NEED_RELOGIN=0

# Downloads $1 to $2 and checks it against the published SHA-256 at $1.sha256.
download_verified() {
  curl -fsSLo "$2" "$1"
  echo "$(curl -fsSL "$1.sha256")  $2" | sha256sum --check --quiet
}

install_docker_engine() {
  # https://docs.docker.com/engine/install/ubuntu/
  $SUDO install -m 0755 -d /etc/apt/keyrings
  $SUDO curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  $SUDO chmod a+r /etc/apt/keyrings/docker.asc
  local codename
  # shellcheck disable=SC1091
  codename="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $codename stable" |
    $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null
  $SUDO apt-get update -y
  $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  # WSL2 distros without systemd fall back to the SysV service script.
  $SUDO systemctl enable --now docker 2>/dev/null || $SUDO service docker start
}

if is_wsl; then
  echo "Detected WSL2."
  case "$(pwd)" in
    /mnt/*) warn "You're under /mnt (the Windows drive). Clone the repo into your WSL home (~/) instead; /mnt/c is slow and breaks file permissions." ;;
  esac
fi

step "Base packages: git, curl, Python 3, venv, pip"
$SUDO apt-get update -y
$SUDO apt-get install -y ca-certificates curl gnupg git python3 python3-venv python3-pip

step "Docker"
if command -v docker >/dev/null 2>&1; then
  echo "✓ $(docker --version)"
elif is_wsl && [[ "${INSTALL_DOCKER_ENGINE_IN_WSL:-0}" != "1" ]]; then
  warn "docker isn't available in this WSL distro."
  echo "  Recommended: install Docker Desktop for Windows, then enable"
  echo "  Settings > Resources > WSL integration > <your Ubuntu distro>, and re-run this script."
  echo "  Alternative: INSTALL_DOCKER_ENGINE_IN_WSL=1 $0"
else
  install_docker_engine
fi
if [[ $EUID -ne 0 ]] && getent group docker >/dev/null && ! id -nG "$USER" | grep -qw docker; then
  $SUDO usermod -aG docker "$USER"
  NEED_RELOGIN=1
fi

step "kubectl"
if command -v kubectl >/dev/null 2>&1; then
  echo "✓ kubectl $(kubectl version --client 2>/dev/null | head -1)"
else
  tmp="$(mktemp -d)"
  ver="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  download_verified "https://dl.k8s.io/release/$ver/bin/linux/$ARCH/kubectl" "$tmp/kubectl"
  $SUDO install -m 0755 "$tmp/kubectl" /usr/local/bin/kubectl
  rm -rf "$tmp"
  echo "Installed kubectl $ver"
fi

step "Minikube"
if command -v minikube >/dev/null 2>&1; then
  echo "✓ $(minikube version --short 2>/dev/null)"
else
  tmp="$(mktemp -d)"
  download_verified "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-$ARCH" "$tmp/minikube"
  $SUDO install -m 0755 "$tmp/minikube" /usr/local/bin/minikube
  rm -rf "$tmp"
  echo "Installed $(minikube version --short)"
fi

step "AppArmor utilities"
$SUDO apt-get install -y apparmor apparmor-utils
if is_wsl; then
  warn "AppArmor isn't enforced by WSL2's default kernel. Exercise 5 needs native Ubuntu (or a Linux VM)."
fi

step "Python virtual environment (.venv)"
if find_python >/dev/null; then
  "$SCRIPT_DIR/setup-python-venv.sh"
else
  warn "Python 3.10+ not found. Ubuntu 22.04+ ships it; on older releases install python3.10 from the deadsnakes PPA."
fi

step "Done"
if [[ $NEED_RELOGIN -eq 1 ]]; then
  echo "You were added to the 'docker' group. Log out and back in (WSL: run 'wsl --shutdown' in PowerShell"
  echo "and reopen Ubuntu), or run 'newgrp docker', so docker works without sudo."
fi
echo "Check everything with:  setup/verify.sh"
