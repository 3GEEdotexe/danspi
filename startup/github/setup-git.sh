#!/usr/bin/env bash
set -euo pipefail

# Repository configuration
GIT_NAME="Daniel Youngk"
GIT_EMAIL="Daniel.youngk@proton.me"
GH_USER="3GEEdotexe"
REPO_NAME="danspi"
LOCAL_DIR="$HOME/00_projects/startup"

# Detect script directory automatically
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TOKEN_FILE="$SCRIPT_DIR/md.md"
REMOTE_URL="https://github.com/${GH_USER}/${REPO_NAME}.git"

echo "-----------------------------------------"
echo "Configuring GitHub access for Pi"
echo "-----------------------------------------"

echo "Script directory:"
echo "$SCRIPT_DIR"

echo
echo "Looking for token file:"
echo "$TOKEN_FILE"

if [[ ! -f "$TOKEN_FILE" ]]; then
    echo
    echo "ERROR: Token file not found."
    echo "Make sure md.md is in the same folder as setup-git.sh"
    exit 1
fi

TOKEN=$(cat "$TOKEN_FILE")

echo
echo "Setting git identity..."
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"

echo
echo "Enabling credential storage..."
git config --global credential.helper store

echo
echo "Preparing project directory..."
mkdir -p "$LOCAL_DIR"

if [[ ! -d "$LOCAL_DIR/.git" ]]; then
    echo "Initializing git repo..."
    git -C "$LOCAL_DIR" init
fi

echo
echo "Setting GitHub remote..."
if git -C "$LOCAL_DIR" remote get-url origin >/dev/null 2>&1; then
    git -C "$LOCAL_DIR" remote set-url origin "$REMOTE_URL"
else
    git -C "$LOCAL_DIR" remote add origin "$REMOTE_URL"
fi

echo
echo "Setting branch to main..."
git -C "$LOCAL_DIR" branch -M main

echo
echo "Saving GitHub credentials..."
cat > "$HOME/.git-credentials" <<EOF
https://${GH_USER}:${TOKEN}@github.com
EOF

chmod 600 "$HOME/.git-credentials"

echo
echo "-----------------------------------------"
echo "GitHub setup complete."
echo
echo "Now run:"
echo
echo "cd $LOCAL_DIR"
echo "git add ."
echo "git commit -m \"initial commit\""
echo "git push -u origin main"
echo
echo "After verifying it works, delete:"
echo "$TOKEN_FILE"
echo "-----------------------------------------"
