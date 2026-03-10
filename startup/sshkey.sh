#!/usr/bin/env bash
set -euo pipefail

# This script DOES NOT fully enable GitHub SSH auth by itself,
# because the key you pasted is only a PUBLIC key.
# GitHub SSH auth requires:
#   1) a PRIVATE key on this Pi
#   2) the matching PUBLIC key added to your GitHub account
#
# Your pasted key:
# ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEW442fJ4RcyRxlbhumMknI3DrXQLSZgC01b2Sv6msdb
#
# GitHub's docs are explicit that you need a public/private keypair on the
# local machine, then add the public key to GitHub. A public key alone cannot
# authenticate from the Pi. :contentReference[oaicite:0]{index=0}

GIT_NAME="${1:-Your Name}"
GIT_EMAIL="${2:-you@example.com}"
REMOTE_URL="${3:-git@github.com:USERNAME/REPO.git}"
LOCAL_DIR="${4:-$HOME/repo}"
PUBKEY_FILE="${5:-$HOME/.ssh/github_pi.pub}"
EXPECTED_PRIVKEY="${PUBKEY_FILE%.pub}"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

cat > "$PUBKEY_FILE" <<'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEW442fJ4RcyRxlbhumMknI3DrXQLSZgC01b2Sv6msdb
EOF

chmod 644 "$PUBKEY_FILE"

git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"

echo "=================================================="
echo "Saved public key to:"
echo "  $PUBKEY_FILE"
echo
echo "Configured git identity:"
echo "  $GIT_NAME"
echo "  $GIT_EMAIL"
echo "=================================================="
echo

if [[ ! -f "$EXPECTED_PRIVKEY" ]]; then
  echo "NO MATCHING PRIVATE KEY FOUND:"
  echo "  $EXPECTED_PRIVKEY"
  echo
  echo "This script cannot finish GitHub SSH setup with only the public key."
  echo
  echo "You have two working options:"
  echo
  echo "OPTION 1 - BEST:"
  echo "  Generate a NEW keypair on the Pi and add the new .pub key to GitHub:"
  echo
  echo "    ssh-keygen -t ed25519 -C \"$GIT_EMAIL\""
  echo "    cat ~/.ssh/id_ed25519.pub"
  echo
  echo "  Then add that public key in:"
  echo "    GitHub -> Settings -> SSH and GPG keys -> New SSH key"
  echo
  echo "OPTION 2:"
  echo "  Copy the MATCHING private key for this public key onto the Pi"
  echo "  and place it at:"
  echo "    $EXPECTED_PRIVKEY"
  echo
  echo "After that, rerun this script."
  exit 1
fi

chmod 600 "$EXPECTED_PRIVKEY"

if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
  eval "$(ssh-agent -s)"
fi

ssh-add -D >/dev/null 2>&1 || true
ssh-add "$EXPECTED_PRIVKEY"

SSH_CONFIG="$HOME/.ssh/config"
touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

if ! grep -q "^Host github.com$" "$SSH_CONFIG" 2>/dev/null; then
  cat >> "$SSH_CONFIG" <<EOF

Host github.com
  HostName github.com
  User git
  IdentityFile $EXPECTED_PRIVKEY
  IdentitiesOnly yes
EOF
fi

echo
echo "Testing GitHub SSH..."
set +e
ssh -T git@github.com
SSH_RC=$?
set -e

# GitHub often returns 1 even on success because shell access is not provided. :contentReference[oaicite:1]{index=1}
if [[ "$SSH_RC" -ne 0 && "$SSH_RC" -ne 1 ]]; then
  echo "GitHub SSH test failed."
  exit 1
fi

if [[ -d "$LOCAL_DIR/.git" ]]; then
  git -C "$LOCAL_DIR" remote remove origin >/dev/null 2>&1 || true
  git -C "$LOCAL_DIR" remote add origin "$REMOTE_URL"
else
  git clone "$REMOTE_URL" "$LOCAL_DIR"
fi

echo
echo "Remote now set to:"
git -C "$LOCAL_DIR" remote -v

echo
echo "Done."
echo
echo "Next:"
echo "  cd \"$LOCAL_DIR\""
echo "  git status"
echo "  git add ."
echo "  git commit -m \"message\""
echo "  git push -u origin main"
