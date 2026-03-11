#!/usr/bin/env bash
set -e

CLONE_DIR="danspi"
EMAIL="Daniel.youngk@proton.me"

echo "-----------------------------------------"
echo "Preparing SSH configuration"
echo "-----------------------------------------"

mkdir -p ~/.ssh
chmod 700 ~/.ssh

if [ ! -f ~/.ssh/id_ed25519 ]; then
    echo "Generating SSH key..."
    ssh-keygen -t ed25519 -C "$EMAIL" -f ~/.ssh/id_ed25519 -N ""
fi

chmod 600 ~/.ssh/id_ed25519

echo
echo "Starting ssh-agent"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

echo
echo "Writing SSH config"

cat > ~/.ssh/config <<EOF
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
EOF

chmod 600 ~/.ssh/config

echo
echo "-----------------------------------------"
echo "Public key (must exist in GitHub)"
echo "-----------------------------------------"
cat ~/.ssh/id_ed25519.pub
echo
echo "If this key is NOT in GitHub:"
echo "https://github.com/settings/keys"
echo

read -p "Type y once the key exists in GitHub: " confirm

echo
echo "Testing GitHub connection..."
ssh -T git@github.com || true

echo
echo "-----------------------------------------"
echo "Configuring git identity"
echo "-----------------------------------------"

cd ~/00_projects/$CLONE_DIR

git config user.name "Daniel Youngk"
git config user.email "$EMAIL"

echo
echo "-----------------------------------------"
echo "Setup complete"
echo
echo "Test with:"
echo
echo "cd ~/00_projects/$CLONE_DIR"
echo "git add ."
echo "git commit -m \"test\""
echo "git push origin main"
echo
echo "-----------------------------------------"
