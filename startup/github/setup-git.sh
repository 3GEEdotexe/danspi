#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./setup-github-ssh-simple.sh "Your Name" "you@example.com" "git@github.com:USERNAME/REPO.git" "/path/to/local/folder"
#
# Example:
#   ./setup-github-ssh-simple.sh \
#     "Daniel Youngk" \
#     "you@example.com" \
#     "git@github.com:danielyoungk/startup.git" \
#     "$HOME/00_projects/startup"

GIT_NAME="${1:-Your Name}"
GIT_EMAIL="${2:-you@example.com}"
REMOTE_URL="${3:-git@github.com:USERNAME/REPO.git}"
LOCAL_DIR="${4:-$HOME/repo}"

KEY_DIR="$HOME/.ssh"
KEY_PATH="$KEY_DIR/id_ed25519"
PUB_PATH="$KEY_DIR/id_ed25519.pub"
SSH_CONFIG="$KEY_DIR/config"

OUT_DIR="$HOME/00_projects/startup/debug"
OUT_FILE="$OUT_DIR/github_public_key.txt"

echo "=================================================="
echo "GitHub SSH setup - simplest method"
echo "=================================================="
echo "Git name   : $GIT_NAME"
echo "Git email  : $GIT_EMAIL"
echo "Remote URL : $REMOTE_URL"
echo "Local dir  : $LOCAL_DIR"
echo "=================================================="
echo

mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"
mkdir -p "$OUT_DIR"

echo "[1/8] Setting git identity..."
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"

echo
echo "[2/8] Generating SSH key if needed..."
if [[ ! -f "$KEY_PATH" ]]; then
  ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$KEY_PATH"
else
  echo "Existing key found at $KEY_PATH"
fi

chmod 600 "$KEY_PATH"
chmod 644 "$PUB_PATH"

echo
echo "[3/8] Saving a copy of the public key..."
cp "$PUB_PATH" "$OUT_FILE"
chmod 644 "$OUT_FILE"

echo
echo "[4/8] Starting ssh-agent and loading key..."
if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
  eval "$(ssh-agent -s)"
fi
ssh-add -D >/dev/null 2>&1 || true
ssh-add "$KEY_PATH"

echo
echo "[5/8] Writing GitHub SSH config..."
touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

if ! grep -q "^Host github.com$" "$SSH_CONFIG" 2>/dev/null; then
  cat >> "$SSH_CONFIG" <<EOF

Host github.com
  HostName github.com
  User git
  IdentityFile $KEY_PATH
  IdentitiesOnly yes
EOF
else
  echo "GitHub host entry already exists in $SSH_CONFIG"
fi

echo
echo "=================================================="
echo "MANUAL STEP REQUIRED ON GITHUB"
echo "=================================================="
echo "On another computer:"
echo "  1. Open GitHub"
echo "  2. Go to: Settings -> SSH and GPG keys"
echo "  3. Click: New SSH key"
echo "  4. Title: danspi"
echo "  5. Key type: Authentication Key"
echo "  6. Paste the ENTIRE contents of this file:"
echo "     $OUT_FILE"
echo "=================================================="
echo
echo "Public key contents:"
echo "--------------------------------------------------"
cat "$OUT_FILE"
echo
echo "--------------------------------------------------"

while true; do
  read -r -p "Type y after you have added this key to GitHub: " CONFIRM
  if [[ "$CONFIRM" == "y" ]]; then
    break
  fi
  echo "Not continuing. Type exactly: y"
done

echo
echo "[6/8] Testing GitHub SSH authentication..."
set +e
SSH_OUTPUT="$(ssh -T git@github.com 2>&1)"
SSH_RC=$?
set -e

echo "$SSH_OUTPUT"
echo

# GitHub often returns exit code 1 even on success because shell access is not provided.
if [[ "$SSH_RC" -ne 0 && "$SSH_RC" -ne 1 ]]; then
  echo "ERROR: SSH test did not succeed."
  echo "Double-check that you added the FULL public key from:"
  echo "  $OUT_FILE"
  exit 1
fi

echo "[7/8] Linking repo..."
mkdir -p "$LOCAL_DIR"

if [[ -d "$LOCAL_DIR/.git" ]]; then
  echo "Existing git repo detected."
  git -C "$LOCAL_DIR" remote remove origin >/dev/null 2>&1 || true
  git -C "$LOCAL_DIR" remote add origin "$REMOTE_URL"
elif [[ -n "$(ls -A "$LOCAL_DIR" 2>/dev/null)" ]]; then
  echo "Folder exists and is not empty, but is not a git repo."
  git -C "$LOCAL_DIR" init
  git -C "$LOCAL_DIR" remote add origin "$REMOTE_URL"
else
  echo "Cloning repo into $LOCAL_DIR ..."
  git clone "$REMOTE_URL" "$LOCAL_DIR"
fi

echo
echo "[8/8] Final remote check..."
git -C "$LOCAL_DIR" remote -v || true

echo
echo "=================================================="
echo "Done."
echo
echo "Public key saved at:"
echo "  $OUT_FILE"
echo
echo "Next:"
echo "  cd \"$LOCAL_DIR\""
echo "  git status"
echo "  git add ."
echo "  git commit -m \"message\""
echo "  git push -u origin main"
echo "=================================================="
