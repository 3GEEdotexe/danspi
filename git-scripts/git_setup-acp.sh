mkdir -p ~/bin
cat > ~/bin/git-acp <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

msg="${*:-}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "ERROR: not inside a git repository"
    exit 1
fi

if [ -z "$msg" ]; then
    echo 'Usage: git acp "commit message"'
    exit 1
fi

echo
echo "Changes:"
git status --short
echo

git add -A

if git diff --cached --quiet; then
    echo "Nothing to commit."
    exit 0
fi

echo "Committing..."
git commit -m "$msg"

echo
echo "Pushing..."
git push

echo
echo "Done."
EOF

chmod +x ~/bin/git-acp
