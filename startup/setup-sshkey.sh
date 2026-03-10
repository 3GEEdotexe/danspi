#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./setup-sshkey.sh "Your Name" "you@example.com" "git@github.com:USERNAME/REPO.git" "/path/to/local/folder"
#
# Example:
#   ./setup-sshkey.sh "Daniel Youngk" "you@example.com" "git@github.com:danielyoungk/myrepo.git" "$HOME/00_projects/startup/myrepo"

GIT_NAME="${1:-Your Name}"
GIT_EMAIL="${2:-you@example.com}"
REMOTE_URL="${3:-git@github.com:USERNAME/REPO.git}"
LOCAL_DIR="${4:-$HOME/repo}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY_TXT="$SCRIPT_DIR/sshkey.txt"

echo "=================================================="
echo "GitHub SSH setup"
echo "=================================================="
echo "Using key file: $KEY_TXT"
echo "Repo URL:       $REMOTE_URL"
echo "Local folder:   $LOCAL_DIR"
echo

if [[ ! -f "$KEY_TXT" ]]; then
  echo "ERROR: sshkey.txt not found in:"
  echo "  $SCRIPT_DIR"
  exit 1
fi

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"

# Detect whether sshkey.txt is a private key or public key
if grep -q "BEGIN OPENSSH PRIVATE KEY" "$KEY_TXT"; then
  echo "Detected PRIVATE key in sshkey.txt"
  cp "$KEY_TXT" "$HOME/.ssh/id_ed25519"
  chmod 600 "$HOME/.ssh/id_ed25519"

  # Generate .pub if missing
  ssh-keygen -y -f "$HOME/.ssh/id_ed25519" > "$HOME/.ssh/id_ed25519.pub"
  chmod 644 "$HOME/.ssh/id_ed25519.pub"

elif grep -q "^ssh-ed25519 " "$KEY_TXT"; then
  echo "Detected PUBLIC key in sshkey.txt"
  cp "$KEY_TXT" "$HOME/.ssh/id_ed25519.pub"
  chmod 644 "$HOME/.ssh/id_ed25519.pub"

  echo
  echo "ERROR: sshkey.txt contains only a PUBLIC key."
  echo "GitHub SSH auth from this Pi requires the MATCHING PRIVATE key on this machine."
  echo "A public key alone cannot authenticate Git operations over SSH." 
  echo
  echo "What to do instead:"
  echo "1. Put the PRIVATE key into sshkey.txt and rerun this script"
  echo "   OR"
  echo "2. Generate a new key on the Pi:"
  echo "      ssh-keygen -t ed25519 -C \"$GIT_EMAIL\""
  echo "      cat ~/.ssh/id_ed25519.pub"
  echo "   Then add that .pub key to GitHub:"
  echo "      GitHub -> Settings -> SSH and GPG keys -> New SSH key"
  exit 1
else
  echo "ERROR: sshkey.txt is not recognized as an OpenSSH private key or ssh-ed25519 public key."
  exit 1
fi

# Start ssh-agent if needed
if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
  eval "$(ssh-agent -s)"
fi

ssh-add -D >/dev/null 2>&1 || true
ssh-add "$HOME/.ssh/id_ed25519"

# Write SSH config
SSH_CONFIG="$HOME/.ssh/config"
touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

if ! grep -q "^Host github.com$" "$SSH_CONFIG" 2>/dev/null; then
  cat >> "$SSH_CONFIG" <<EOF

Host github.com
  HostName github.com
  User git
  IdentityFile $HOME/.ssh/id_ed25519
  IdentitiesOnly yes
EOF
fi

echo
echo "Testing GitHub SSH..."
set +e
ssh -T git@github.com
SSH_RC=$?
set -e

# GitHub often returns exit code 1 even when auth succeeds because it does not provide shell access.
if [[ "$SSH_RC" -ne 0 && "$SSH_RC" -ne 1 ]]; then
  echo
  echo "GitHub SSH test did not look successful."
  echo "Make sure the PUBLIC key is added to your GitHub account."
  echo "Public key file:"
  echo "  $HOME/.ssh/id_ed25519.pub"
  exit 1
fi

echo
if [[ -d "$LOCAL_DIR/.git" ]]; then
  echo "Existing repo found. Setting origin to SSH remote..."
  git -C "$LOCAL_DIR" remote remove origin >/dev/null 2>&1 || true
  git -C "$LOCAL_DIR" remote add origin "$REMOTE_URL"
else
  echo "Cloning repo..."
  git clone "$REMOTE_URL" "$LOCAL_DIR"
fi

echo
echo "Verifying remote..."
git -C "$LOCAL_DIR" remote -v

echo
echo "=================================================="
echo "Done."
echo
echo "Next:"
echo "  cd \"$LOCAL_DIR\""
echo "  git status"
echo "  git add ."
echo "  git commit -m \"your message\""
echo "  git push -u origin main"
echo "=================================================="
