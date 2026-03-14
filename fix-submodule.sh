#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo "Git submodule repair / verify / push"
echo "========================================"

# Make sure we're in a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "ERROR: This is not inside a git repository."
    exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

echo "Repo root: $REPO_ROOT"
echo

CURRENT_BRANCH="$(git branch --show-current)"
if [ -z "$CURRENT_BRANCH" ]; then
    echo "ERROR: Could not determine current branch."
    exit 1
fi

echo "Current branch: $CURRENT_BRANCH"
echo

echo "---- Checking for .gitmodules ----"
if [ ! -f .gitmodules ]; then
    echo "ERROR: .gitmodules does not exist."
    echo "This repo currently does not have committed submodule metadata."
    echo
    echo "If you thought you added submodules, they may not have been added as true submodules."
    exit 1
fi

cat .gitmodules
echo

echo "---- Registered submodules ----"
git config --file .gitmodules --get-regexp '^submodule\..*\.path$' || true
echo

echo "---- Current submodule status ----"
git submodule status || true
echo

echo "---- Gitlink entries (mode 160000) ----"
GITLINKS="$(git ls-files --stage | awk '$1 == "160000" {print}')"
if [ -z "$GITLINKS" ]; then
    echo "ERROR: No gitlink entries found."
    echo "That means the submodules are not currently tracked as real submodules in the parent repo index."
    exit 1
fi
echo "$GITLINKS"
echo

echo "---- Staging .gitmodules and all submodule paths from .gitmodules ----"
git add .gitmodules

mapfile -t SUBMODULE_PATHS < <(git config --file .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}')

if [ "${#SUBMODULE_PATHS[@]}" -eq 0 ]; then
    echo "ERROR: No submodule paths found in .gitmodules."
    exit 1
fi

for p in "${SUBMODULE_PATHS[@]}"; do
    echo "Staging: $p"
    git add "$p"
done
echo

echo "---- Git status after staging ----"
git status --short
echo

if git diff --cached --quiet; then
    echo "No staged changes to commit."
    echo "That usually means the submodule metadata and gitlinks are already committed on this branch."
else
    COMMIT_MSG="Add/update submodule metadata"
    echo "Creating commit: $COMMIT_MSG"
    git commit -m "$COMMIT_MSG"
    echo
fi

echo "---- Pushing branch to origin ----"
git push origin "$CURRENT_BRANCH"
echo

echo "========================================"
echo "DONE"
echo "========================================"
echo
echo "Now on the other machine, run:"
echo
echo "  git fetch origin"
echo "  git checkout $CURRENT_BRANCH"
echo "  git pull"
echo "  git submodule sync --recursive"
echo "  git submodule update --init --recursive"
echo
