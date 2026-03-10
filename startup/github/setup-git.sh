#!/usr/bin/env bash
set -euo pipefail

# setup-github-ssh-walkthrough.sh
#
# What this does:
# 1) Sets your git name/email
# 2) Generates an SSH key on the Pi if needed
# 3) Shows you the public key
# 4) Pauses until you type exactly: y
#    after adding that key to GitHub
# 5) Tests SSH auth to GitHub
# 6) Either points an existing local repo to origin, or clones the repo
#
# Usage:
#   ./setup-github-ssh-walkthrough.sh "Your Name" "you@example.com" "git@github.com:USERNAME/REPO.git" "/path/to/local/folder"
#
# Example:
#   ./setup-github-ssh-walkthrough.sh \
#     "Daniel Youngk" \
#     "you@example.com" \
#     "git@github.com:danielyoungk/startup.git" \
#     "$HOME/00_projects/startup"

GIT_NAME="${1:-Your Name}"
GIT_EMAIL="${2:-you@example.com}"
REMOTE_URL="${3:-git@github.com:USERNAME/REPO.git}"
LOCAL_DIR="${4:-$HOME/repo}"

KEY_PATH="$HOME/.ssh/id_ed25519"
PUB_PATH="$HOME/.ssh/id_ed25519.pub"
SSH_CONFIG="$HOME/.ssh/config"

echo "=================================================="
echo "GitHub SSH walkthrough"
echo "=================================================="
echo "Git name   : $GIT_NAME"
echo "Git email  : $GIT_EMAIL"
echo "Remote URL : $REMOTE_URL"
echo "Local dir  : $LOCAL_DIR"
echo "=================================================="
echo

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

echo "[1/7] Setting git identity..."
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"

echo
echo "[2/7] Ensuring SSH key exists..."
if [[ ! -f "$KEY_PATH" ]]; then
  ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$KEY_PATH"
else
  echo "Existing key found: $KEY_PATH"
fi

chmod 600 "$KEY_PATH"
chmod 644 "$PUB_PATH"

echo
echo "[3/7] Starting ssh-agent and loading key..."
if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
  eval "$(ssh-agent -s)"
fi
ssh-add -D >/dev/null 2>&1 || true
ssh-add "$KEY_PATH"

echo
echo "[4/7] Configuring ~/.ssh/config for GitHub..."
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
echo "1. Go to GitHub in your browser"
echo "2. Open: Settings -> SSH and GPG keys"
echo "3. Click: New SSH key"
echo "4. Title it something like: danspi"
echo "5. Key type: Authentication Key"
echo "6. Paste this EXACT public key:"
echo "--------------------------------------------------"
cat "$PUB_PATH"
echo "--------------------------------------------------"
echo "7. Click: Add SSH key"
echo "=================================================="
echo

while true; do
  read -r -p "Type y after you have added this key to GitHub: " CONFIRM
  if [[ "$CONFIRM" == "y" ]]; then
    break
  fi
  echo "Not continuing. Type exactly: y"
done

echo
echo "[5/7] Testing GitHub SSH authentication..."
set +e
SSH_OUTPUT="$(ssh -T git@github.com 2>&1)"
SSH_RC=$?
set -e

echo "$SSH_OUTPUT"
echo

# GitHub commonly returns exit code 1 even on successful auth because shell access is not provided.
if [[ "$SSH_RC" -ne 0 && "$SSH_RC" -ne 1 ]]; then
  echo "ERROR: SSH test failed."
  echo "Make sure you pasted the full public key shown above into GitHub."
  exit 1
fi

echo "[6/7] Linking local folder to repo..."
if [[ -d "$LOCAL_DIR/.git" ]]; then
  echo "Existing git repo detected."
  git -C "$LOCAL_DIR" remote remove origin >/dev/null 2>&1 || true
  git -C "$LOCAL_DIR" remote add origin "$REMOTE_URL"
else
  if [[ -d "$LOCAL_DIR" && -n "$(ls -A "$LOCAL_DIR" 2>/dev/null)" ]]; then
    echo "Local folder exists and is not empty, but is not a git repo."
    echo "Initializing repo and linking origin..."
    git -C "$LOCAL_DIR" init
    git -C "$LOCAL_DIR" remote add origin "$REMOTE_URL"
  else
    echo "Cloning repo into $LOCAL_DIR ..."
    git clone "$REMOTE_URL" "$LOCAL_DIR"
  fi
fi

echo
echo "[7/7] Final remote check..."
git -C "$LOCAL_DIR" remote -v || true

echo
echo "=================================================="
echo "Done."
echo
echo "Next commands:"
echo "  cd \"$LOCAL_DIR\""
echo "  git status"
echo "  git add ."
echo "  git commit -m \"message\""
echo "  git push -u origin main"
echo "=================================================="
