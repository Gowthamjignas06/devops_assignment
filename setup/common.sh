# shellcheck shell=bash
# Shared helpers for the setup scripts. Source this file; don't run it.

step() { printf '\n==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }

is_wsl() { grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; }

# Prints the path of the first Python on PATH that is 3.10 or newer.
find_python() {
  local py
  for py in python3.14 python3.13 python3.12 python3.11 python3.10 python3; do
    if command -v "$py" >/dev/null 2>&1 &&
      "$py" -c 'import sys; sys.exit(sys.version_info < (3, 10))' 2>/dev/null; then
      command -v "$py"
      return 0
    fi
  done
  return 1
}

# Prints the Go-style architecture name used by kubectl/minikube downloads.
linux_arch() {
  case "$(uname -m)" in
    x86_64) echo amd64 ;;
    aarch64 | arm64) echo arm64 ;;
    *)
      echo "Unsupported CPU architecture: $(uname -m)" >&2
      return 1
      ;;
  esac
}
