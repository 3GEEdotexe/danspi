#!/usr/bin/env bash
set -euo pipefail

# setup-github-ssh-offline.sh
#
# Expected files in the SAME folder as this script:
#   id_ed25519
#   id_ed25519.pub
#
# Usage:
#   ./setup-github-ssh-offline.sh "Your Name" "you@example.com" "git@github.com:USERNAME/REPO.git" "/path/to/local/folder"
#
# Example:
#   ./setup-github-ssh-offline.sh \
#     "Daniel Youngk" \
#     "you@example.com" \
#     "git@github.com:danielyoungk/startup.git" \
#     "$HOME/00_projects/startup"

GIT_NAME="${1:-Your Name}"
GIT_EMAIL="${2:-you@example.com}"
REMOTE_URL="${3:-git@github.com:USERNAME/REPO.git}"
LOCAL_DIR="${4:-$HOME/repo}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_PRIV="$SCRIPT_DIR/id_ed25519"
SRC_PUB="$SCRIPT_DIR/id_ed25519.pub"

DST_DIR="$HOME/.ssh"
DST_PRIV="$DST_DIR/id_ed25519"
DST_PUB="$DST_DIR/id_ed25519.pub"
SSH_CONFIG="$DST_DIR/config"

echo "=================================================="
echo "GitHub SSH setup from offline key files"
echo "=================================================="
echo "Git name   : $GIT_NAME"
echo "Git email  : $GIT_EMAIL"
echo "Remote URL : $REMOTE_URL"
echo "Local dir  : $LOCAL_DIR"
echo "Script dir : $SCRIPT_DIR"
echo "=================================================="
echo

echo "[1/7] Checking for key files next to this script..."
if [[ ! -f "$SRC_PRIV" ]]; then
  echo "ERROR: Missing private key file:"
  echo "  $SRC_PRIV"
  echo
  echo "Put the PRIVATE key file named exactly 'id_ed25519'"
  echo "in the same folder as this script."
  exit 1
fi

if [[ ! -f "$SRC_PUB" ]]; then
  echo "ERROR: Missing public key file:"
  echo "  $SRC_PUB"
  echo
  echo "Put the PUBLIC key file named exactly 'id_ed25519.pub'"
  echo "in the same folder as this script."
  exit 1
fi

echo
echo "[2/7] Confirm the GitHub-side step is already done..."
echo "On another computer, you must already have added the PUBLIC key"
echo "to GitHub here:"
echo "  Settings -> SSH and GPG keys -> New SSH key"
echo

while true; do
  read -r -p "Type y once the public key has been added to GitHub: " CONFIRM
  if [[ "$CONFIRM" == "y" ]]; then
    break
  fi
  echo "Not continuing. Type exactly: y"
done

echo
echo "[3/7] Installing SSH keys on this Pi..."
mkdir -p "$DST_DIR"
chmod 700 "$DST_DIR"

cp "$SRC_PRIV" "$DST_PRIV"
cp "$SRC_PUB" "$DST_PUB"

chmod 600 "$DST_PRIV"
chmod 644 "$DST_PUB"

echo
echo "[4/7] Setting git identity..."
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"

echo
echo "[5/7] Starting ssh-agent and loading key..."
if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
  eval "$(ssh-agent -s)"
fi

ssh-add -D >/dev/null 2>&1 || true
ssh-add "$DST_PRIV"

echo
echo "[6/7] Writing ~/.ssh/config entry for GitHub..."
touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

if ! grep -q "^Host github.com$" "$SSH_CONFIG" 2>/dev/null; then
  cat >> "$SSH_CONFIG" <<EOF

Host github.com
  HostName github.com
  User git
  IdentityFile $DST_PRIV
  IdentitiesOnly yes
EOF
else
  echo "GitHub SSH host entry already exists."
fi

echo
echo "Testing GitHub SSH..."
set +e
SSH_OUTPUT="$(ssh -T git@github.com 2>&1)"
SSH_RC=$?
set -e

echo "$SSH_OUTPUT"
echo

# GitHub commonly returns code 1 even on successful authentication
# because shell access is not provided.
if [[ "$SSH_RC" -ne 0 && "$SSH_RC" -ne 1 ]]; then
  echo "ERROR: GitHub SSH test did not succeed."
  echo "Double-check that the matching PUBLIC key was added to GitHub."
  exit 1
fi

echo
echo "[7/7] Linking the repo..."
if [[ -d "$LOCAL_DIR/.git" ]]; then
  echo "Existing git repo detected."
  git -C "$LOCAL_DIR" remote remove origin >/dev/null 2>&1 || true
  git -C "$LOCAL_DIR" remote add origin "$REMOTE_URL"
elif [[ -d "$LOCAL_DIR" && -n "$(ls -A "$LOCAL_DIR" 2>/dev/null)" ]]; then
  echo "Folder exists and is not empty, but is not a git repo."
  git -C "$LOCAL_DIR" init
  git -C "$LOCAL_DIR" remote add origin "$REMOTE_URL"
else
  echo "Cloning repo into $LOCAL_DIR ..."
  git clone "$REMOTE_URL" "$LOCAL_DIR"
fi

echo
echo "Remote configuration:"
git -C "$LOCAL_DIR" remote -v || true

echo
echo "=================================================="
echo "Done."
echo
echo "Next:"
echo "  cd \"$LOCAL_DIR\""
echo "  git status"
echo "  git add ."
echo "  git commit -m \"message\""
echo "  git push -u origin main"
echo "=================================================="
