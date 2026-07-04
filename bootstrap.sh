#!/usr/bin/env bash
#
# Bootstrap: get mise, use it to get Python 3.11, build an isolated Ansible
# venv, then run the playbook against this machine.
#
# Prerequisites (manual, one-time):
#   xcode-select --install   (provides git, python3, curl)
#   Homebrew                 (https://brew.sh)
#
# Any arguments are passed straight through to ansible-playbook, e.g.:
#   ./bootstrap.sh --tags term
#   ./bootstrap.sh --check

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV="${ANSIBLE_VENV:-$REPO_DIR/.ansible}"

# Homebrew lands here on Apple Silicon; Intel Macs use /usr/local.
BREW_PREFIX="$([ -d /opt/homebrew ] && echo /opt/homebrew || echo /usr/local)"
BREW="$BREW_PREFIX/bin/brew"
MISE="$BREW_PREFIX/bin/mise"

# 1. Verify Command Line Tools (they provide /usr/bin/python3, git, curl).
if ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
  echo "error: Xcode Command Line Tools not found." >&2
  echo "       Run this first, then re-run bootstrap:" >&2
  echo "         xcode-select --install" >&2
  exit 1
fi

# 2. Verify Homebrew (manual prerequisite — the playbook manages packages
#    with it but does not install it).
if [ ! -x "$BREW" ]; then
  echo "error: Homebrew not found at $BREW." >&2
  echo "       Install it first, then re-run bootstrap:" >&2
  echo "         https://brew.sh" >&2
  exit 1
fi

# 3. Install mise via Homebrew (idempotent; the playbook's mise.yml keeps it
#    updated afterwards).
if [ ! -x "$MISE" ]; then
  echo "==> Installing mise via Homebrew"
  "$BREW" install mise
fi

# 4. Install Python 3.11 via mise (idempotent).
echo "==> Ensuring Python 3.11 is available via mise"
"$MISE" install python@3.11

# 5. Create the Ansible venv using mise's Python 3.11.
#    If an old venv exists that was built on Python 3.9, remove it first —
#    ansible-core 2.18+ requires Python 3.10+.
if [ -x "$VENV/bin/python3" ]; then
  PY_MINOR=$("$VENV/bin/python3" -c "import sys; print(sys.version_info.minor)")
  if [ "$PY_MINOR" -lt 10 ]; then
    echo "==> Removing Python 3.9 venv, rebuilding with Python 3.11"
    rm -rf "$VENV"
  fi
fi

if [ ! -x "$VENV/bin/python3" ]; then
  echo "==> Creating Ansible venv at $VENV"
  "$MISE" exec python@3.11 -- python3 -m venv "$VENV"
fi

# 6. Install / upgrade Ansible inside the venv.
#    ansible>=11 bundles ansible-core 2.18+ and community.general 10+, both
#    required for the Homebrew module to work with current Homebrew.
echo "==> Installing Ansible into the venv"
"$VENV/bin/pip" install --quiet --upgrade pip
"$VENV/bin/pip" install --upgrade "ansible>=11"

# 7. Machine-local vars (gitignored): profile plus per-machine settings such
#    as the git identity. Set up once per machine:
#      cp local.example.yml local.yml   # then edit
#    Absent file means the personal profile; the playbook asserts the vars
#    that have no sensible default (git identity) and fails with a pointer
#    to local.example.yml. Prepended so explicit -e flags still win.
if [ -f "$REPO_DIR/local.yml" ]; then
  set -- -e "@$REPO_DIR/local.yml" "$@"
fi

# 8. Run the playbook against localhost.
#    vars_prompt in main.yml collects the sudo password once; it is forwarded
#    both to become tasks and to homebrew_cask's sudo_password parameter
#    (cask post-install symlinks that call sudo internally).
echo "==> Running playbook"
cd "$REPO_DIR"
exec "$VENV/bin/ansible-playbook" main.yml "$@"
