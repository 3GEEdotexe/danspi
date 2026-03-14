cat > ~/bin/git-acp <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

msg="${*:-}"

spinner() {
    local pid=$1
    local spin='-\|/'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\rLoading status... %s" "${spin:$i:1}"
        sleep 0.2
    done
    printf "\rLoading status... done\n"
}

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "ERROR: not inside a git repository"
    exit 1
fi

if [ -z "$msg" ]; then
    echo 'Usage: git acp "commit message"'
    exit 1
fi

{
    git add -A
} &
spinner $!

if git diff --cached --quiet; then
    echo "Nothing to commit."
    exit 0
fi

echo
git status --short
echo
git diff --cached --stat
echo

echo
read -rp "Commit these changes? [y/n]: " confirm

case "$confirm" in
    y|Y|yes|YES)
        echo
        echo "Committing..."
        git commit -m "$msg"

        echo
        echo "Pushing..."
        git push

        echo
        echo "Done."
        ;;
    *)
        echo
        echo "Commit cancelled."
        exit 0
        ;;
esac
EOF
