#!/bin/bash
set -euo pipefail

echo "========================================"
echo "Git SSH setup for WSL"
echo "========================================"
echo

read -rp "GitHub email for SSH key comment: " EMAIL
read -rp "GitHub username or org (example: 3GTech-LLC): " GH_OWNER
read -rp "Repo name (example: danspi): " REPO_NAME

KEY="$HOME/.ssh/id_ed25519"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

if [ ! -f "$KEY" ]; then
    echo
    echo "Creating SSH key..."
    ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY" -N ""
else
    echo
    echo "SSH key already exists: $KEY"
fi

echo
echo "Starting ssh-agent if needed..."
if ! pgrep -u "$USER" ssh-agent >/dev/null 2>&1; then
    eval "$(ssh-agent -s)" >/dev/null
fi

echo "Loading SSH key..."
ssh-add "$KEY" >/dev/null

SSH_CONFIG="$HOME/.ssh/config"
touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

if ! grep -q "^Host github.com$" "$SSH_CONFIG" 2>/dev/null; then
cat >> "$SSH_CONFIG" <<'EOC'

Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
EOC
fi

BASHRC="$HOME/.bashrc"
if ! grep -q 'ssh-agent -s' "$BASHRC" 2>/dev/null; then
cat >> "$BASHRC" <<'EOB'

# Auto-start ssh-agent and load GitHub key
if ! pgrep -u "$USER" ssh-agent >/dev/null 2>&1; then
    eval "$(ssh-agent -s)" >/dev/null
fi
ssh-add -l >/dev/null 2>&1 || ssh-add ~/.ssh/id_ed25519 >/dev/null 2>&1
EOB
fi

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo
    echo "Setting origin remote to SSH in current repo..."
    git remote set-url origin "git@github.com:${GH_OWNER}/${REPO_NAME}.git"
fi

echo
echo "----------------------------------------"
echo "Copy this public key into GitHub:"
echo "GitHub -> Settings -> SSH and GPG keys"
echo "----------------------------------------"
cat "${KEY}.pub"
echo "----------------------------------------"
echo
echo "After adding the key to GitHub, test with:"
echo "ssh -T git@github.com"
echo
echo "Then verify with:"
echo "git remote -v"
