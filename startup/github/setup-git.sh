#!/usr/bin/env bash
set -e

# ============================================
# danspi GitHub SSH reset/setup script
# Run this FROM ~/00_projects
# ============================================

REPO_NAME="danspi"
CLONE_DIR="danspi.startup"
GITHUB_USER="3GEEdotexe"
REPO_URL="git@github.com:3GEEdotexe/danspi.git"

echo "-----------------------------------------"
echo "Resetting local repo"
echo "-----------------------------------------"

# Remove existing clone
if [ -d "$CLONE_DIR" ]; then
    echo "Removing old repo..."
    rm -rf "$CLONE_DIR"
fi

echo "-----------------------------------------"
echo "Preparing SSH directory"
echo "-----------------------------------------"

mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Generate SSH key if none exists
if [ ! -f ~/.ssh/id_ed25519 ]; then
    echo "Generating new SSH key..."
    ssh-keygen -t ed25519 -C "Daniel.youngk@proton.me" -f ~/.ssh/id_ed25519 -N ""
fi

chmod 600 ~/.ssh/id_ed25519

echo "-----------------------------------------"
echo "Starting ssh-agent"
echo "-----------------------------------------"

eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

echo "-----------------------------------------"
echo "Writing SSH config"
echo "-----------------------------------------"

cat > ~/.ssh/config <<EOF
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
EOF

chmod 600 ~/.ssh/config

echo "-----------------------------------------"
echo "Your PUBLIC KEY (add this to GitHub)"
echo "-----------------------------------------"
echo
cat ~/.ssh/id_ed25519.pub
echo
echo "-----------------------------------------"
echo "1) Copy the key above"
echo "2) Go to:"
echo "   https://github.com/settings/keys"
echo "3) Click 'New SSH key'"
echo "4) Paste the key"
echo "-----------------------------------------"

read -p "Type y once you have added the key to GitHub: " confirm

if [ "$confirm" != "y" ]; then
    echo "Setup aborted."
    exit 1
fi

echo "-----------------------------------------"
echo "Testing GitHub SSH connection"
echo "-----------------------------------------"

ssh -T git@github.com || true

echo "-----------------------------------------"
echo "Cloning repository"
echo "-----------------------------------------"

git clone "$REPO_URL" "$CLONE_DIR"

cd "$CLONE_DIR"

echo "-----------------------------------------"
echo "Configuring git identity"
echo "-----------------------------------------"

git config user.name "Daniel Youngk"
git config user.email "Daniel.youngk@proton.me"

echo "-----------------------------------------"
echo "Repository ready"
echo "-----------------------------------------"

echo
echo "You can now run:"
echo
echo "cd ~/00_projects/$CLONE_DIR"
echo "git add ."
echo "git commit -m \"message\""
echo "git push origin main"
echo
echo "-----------------------------------------"
