#!/usr/bin/env bash
# Creates .venv at the repo root and installs requirements.txt into it.
# Safe to re-run: an existing, healthy venv is reused and only updated.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV="$REPO_ROOT/.venv"
# shellcheck source=setup/common.sh
source "$SCRIPT_DIR/common.sh"

PY="$(find_python)" || {
  echo "ERROR: Python 3.10+ not found on PATH. Run the install script for your OS first." >&2
  exit 1
}

# Recreate the venv if it is broken or was built with Python < 3.10.
if [[ -d "$VENV" ]] && ! "$VENV/bin/python" -c 'import sys; sys.exit(sys.version_info < (3, 10))' 2>/dev/null; then
  echo "Existing .venv is broken or uses Python < 3.10; recreating it."
  rm -rf "$VENV"
fi

if [[ ! -d "$VENV" ]]; then
  echo "Creating .venv with $("$PY" --version)"
  "$PY" -m venv "$VENV"
else
  echo "Reusing .venv ($("$VENV/bin/python" --version))"
fi

"$VENV/bin/python" -m pip install --quiet --upgrade pip
"$VENV/bin/python" -m pip install --quiet -r "$REPO_ROOT/requirements.txt"

echo "Installed packages:"
"$VENV/bin/python" -m pip list --format=freeze | grep -iE '^(flask|werkzeug|prometheus.client|docker)=='
echo
echo "Activate it in each new terminal with:  source .venv/bin/activate"
