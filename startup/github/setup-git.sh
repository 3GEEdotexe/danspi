#!/usr/bin/env bash
set -euo pipefail

# Repo configuration
GIT_NAME="Daniel Youngk"
GIT_EMAIL="Daniel.youngk@proton.me"
GH_USER="3GEEdotexe"
REPO_NAME="danspi"
LOCAL_DIR="$HOME/00_projects/startup"

TOKEN_FILE="$HOME/00_projects/startup/github/md.md"
REMOTE_URL="https://github.com/${GH_USER}/${REPO_NAME}.git"

echo "-----------------------------------------"
echo "Configuring GitHub access for Pi"
echo "-----------------------------------------"

if [[ ! -f "$TOKEN_FILE" ]]; then
    echo "ERROR: Token file not found:"
    echo "$TOKEN_FILE"
    exit 1
fi

TOKEN=$(cat "$TOKEN_FILE")

echo "Setting git identity..."
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"

echo "Enabling credential storage..."
git config --global credential.helper store

echo "Checking project directory..."
mkdir -p "$LOCAL_DIR"

if [[ ! -d "$LOCAL_DIR/.git" ]]; then
    echo "Initializing repo..."
    git -C "$LOCAL_DIR" init
fi

echo "Setting GitHub remote..."
if git -C "$LOCAL_DIR" remote get-url origin >/dev/null 2>&1; then
    git -C "$LOCAL_DIR" remote set-url origin "$REMOTE_URL"
else
    git -C "$LOCAL_DIR" remote add origin "$REMOTE_URL"
fi

echo "Setting branch to main..."
git -C "$LOCAL_DIR" branch -M main

echo "Saving GitHub credentials..."
cat > "$HOME/.git-credentials" <<EOF
https://${GH_USER}:${TOKEN}@github.com
EOF

chmod 600 "$HOME/.git-credentials"

echo "-----------------------------------------"
echo "GitHub setup complete."
echo
echo "Use these commands now:"
echo
echo "cd $LOCAL_DIR"
echo "git add ."
echo "git commit -m \"message\""
echo "git push -u origin main"
echo
echo "After verifying push works you should delete:"
echo "$TOKEN_FILE"
echo "-----------------------------------------"
