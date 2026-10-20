#!/usr/bin/env bash
# Checks that every tool the labs need is installed, printing PASS/FAIL and the
# version for each. Exits non-zero if any required check fails.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV_PY="$REPO_ROOT/.venv/bin/python"
# shellcheck source=setup/common.sh
source "$SCRIPT_DIR/common.sh"

if [[ -t 1 ]]; then
  GREEN=$'\e[32m' RED=$'\e[31m' YELLOW=$'\e[33m' DIM=$'\e[2m' RESET=$'\e[0m'
else
  GREEN="" RED="" YELLOW="" DIM="" RESET=""
fi
passed=0 failed=0 warned=0

report() { # status name detail
  local color
  case "$1" in
    PASS) color=$GREEN passed=$((passed + 1)) ;;
    FAIL) color=$RED failed=$((failed + 1)) ;;
    WARN) color=$YELLOW warned=$((warned + 1)) ;;
    *) color=$DIM ;;
  esac
  printf '%s%-5s%s %-28s %s\n' "$color" "$1" "$RESET" "$2" "$3"
}

# check NAME COMMAND... : PASS with the command's first output line, else FAIL.
check() {
  local name=$1 out
  shift
  if out="$("$@" 2>&1)"; then
    report PASS "$name" "$(head -1 <<<"$out")"
  else
    report FAIL "$name" "$(head -1 <<<"${out:-not found}")"
  fi
}

case "$(uname -s)" in
  Darwin) OS=macos ;;
  Linux) if is_wsl; then OS=wsl; else OS=linux; fi ;;
  *) OS=other ;;
esac
echo "DevOps lab toolchain check (OS: $OS)"
echo

check git git --version
check curl curl --version
check "docker (CLI)" docker --version
if command -v docker >/dev/null 2>&1; then
  if v="$(docker info --format '{{.ServerVersion}}' 2>/dev/null)" && [[ -n "$v" ]]; then
    report PASS "docker (daemon)" "server $v"
  else
    report FAIL "docker (daemon)" "not reachable: start Docker Desktop / the docker service, or check docker group membership"
  fi
else
  report FAIL "docker (daemon)" "docker CLI missing"
fi
check kubectl kubectl version --client
check minikube minikube version --short

if PY="$(find_python)"; then
  report PASS "python 3.10+" "$("$PY" --version 2>&1) ($PY)"
else
  report FAIL "python 3.10+" "no python3.10+ on PATH"
fi

if [[ -x "$VENV_PY" ]]; then
  check "pip (.venv)" "$VENV_PY" -m pip --version
  for pkg in flask werkzeug prometheus-client docker; do
    check "  $pkg (.venv)" "$VENV_PY" -c "import importlib.metadata as m; print(m.version('$pkg'))"
  done
else
  report FAIL "pip (.venv)" ".venv missing: run setup/setup-python-venv.sh"
fi

case "$OS" in
  linux)
    check apparmor_parser apparmor_parser --version
    if [[ "$(cat /sys/module/apparmor/parameters/enabled 2>/dev/null)" == "Y" ]]; then
      report PASS "apparmor (kernel)" "enabled"
    else
      report FAIL "apparmor (kernel)" "not enabled; Exercise 5 won't work"
    fi
    ;;
  wsl)
    if command -v apparmor_parser >/dev/null 2>&1; then
      report WARN apparmor_parser "installed, but WSL2 doesn't enforce AppArmor; use native Linux for Exercise 5"
    else
      report WARN apparmor_parser "not installed; Exercise 5 needs native Linux anyway"
    fi
    ;;
  *)
    report SKIP apparmor_parser "Linux only; Exercise 5 needs native Linux"
    ;;
esac

echo
echo "${passed} passed, ${failed} failed, ${warned} warnings"
[[ $failed -eq 0 ]]
