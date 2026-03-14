#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo "Add Git submodule to current repository"
echo "========================================"
echo

fail() {
    echo
    echo "ERROR: $1"
    exit 1
}

warn() {
    echo
    echo "WARNING: $1"
}

confirm() {
    local prompt="${1:-Proceed? [y/N]: }"
    read -r -p "$prompt" reply
    case "${reply:-}" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

# Make sure we're in a git repo
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "Current directory is not inside a Git repository."

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

CURRENT_BRANCH="$(git branch --show-current)"

echo "Repo root: $REPO_ROOT"
echo "Current branch: ${CURRENT_BRANCH:-DETACHED_HEAD}"
echo

read -r -p "Enter submodule URL: " SUB_URL
[ -n "${SUB_URL:-}" ] || fail "Submodule URL cannot be empty."

read -r -p "Enter submodule path/name inside this repo: " SUB_PATH
[ -n "${SUB_PATH:-}" ] || fail "Submodule path cannot be empty."

read -r -p "Track a specific branch in the submodule? [leave blank for default]: " SUB_BRANCH

echo
echo "Requested submodule:"
echo "  URL : $SUB_URL"
echo "  Path: $SUB_PATH"
if [ -n "${SUB_BRANCH:-}" ]; then
    echo "  Branch: $SUB_BRANCH"
else
    echo "  Branch: default"
fi
echo

# Preflight: make sure the remote is reachable before touching the repo
echo "Checking access to remote..."
if ! git ls-remote "$SUB_URL" >/dev/null 2>&1; then
    fail "Cannot access submodule remote. Fix authentication/URL first, then rerun."
fi
echo "Remote is reachable."
echo

# If path exists, offer controlled cleanup
if [ -e "$SUB_PATH" ]; then
    warn "Path '$SUB_PATH' already exists."
    if confirm "Remove existing path and continue? [y/N]: "; then
        rm -rf "$SUB_PATH"
        echo "Removed existing path."
    else
        fail "Choose a new path or remove the existing directory first."
    fi
fi

# Clean partial submodule metadata from a previous failed attempt
cleanup_partial_submodule() {
    local path="$1"

    echo "Checking for leftover partial submodule state..."

    # Remove matching section from .gitmodules if present
    if [ -f .gitmodules ]; then
        local matches
        matches="$(git config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null | awk -v p="$path" '$2==p {print $1}' || true)"
        if [ -n "$matches" ]; then
            while read -r key; do
                [ -n "$key" ] || continue
                name="${key#submodule.}"
                name="${name%.path}"
                echo "Removing stale .gitmodules entry for '$name'..."
                git config -f .gitmodules --remove-section "submodule.$name" >/dev/null 2>&1 || true
            done <<< "$matches"
            if [ ! -s .gitmodules ]; then
                rm -f .gitmodules
            fi
        fi
    fi

    # Remove matching section from .git/config if present
    local cfg_matches
    cfg_matches="$(git config --get-regexp '^submodule\..*\.path$' 2>/dev/null | awk -v p="$path" '$2==p {print $1}' || true)"
    if [ -n "$cfg_matches" ]; then
        while read -r key; do
            [ -n "$key" ] || continue
            name="${key#submodule.}"
            name="${name%.path}"
            echo "Removing stale .git/config entry for '$name'..."
            git config --remove-section "submodule.$name" >/dev/null 2>&1 || true
        done <<< "$cfg_matches"
    fi

    # Remove stale git modules cache by path basename and full path if present
    rm -rf ".git/modules/$path" ".git/modules/$(basename "$path")" 2>/dev/null || true

    # Remove stale index entry if any
    git rm --cached -f -- "$path" >/dev/null 2>&1 || true

    # Remove stale working tree path if recreated by failed add
    rm -rf -- "$path" 2>/dev/null || true
}

cleanup_partial_submodule "$SUB_PATH"

echo
echo "About to run:"
if [ -n "${SUB_BRANCH:-}" ]; then
    echo "  git submodule add -b \"$SUB_BRANCH\" \"$SUB_URL\" \"$SUB_PATH\""
else
    echo "  git submodule add \"$SUB_URL\" \"$SUB_PATH\""
fi
echo

confirm "Proceed? [y/N]: " || { echo "Cancelled."; exit 0; }

echo
echo "Adding submodule..."

add_submodule() {
    if [ -n "${SUB_BRANCH:-}" ]; then
        git submodule add -b "$SUB_BRANCH" "$SUB_URL" "$SUB_PATH"
    else
        git submodule add "$SUB_URL" "$SUB_PATH"
    fi
}

# First attempt
if ! add_submodule; then
    warn "First submodule add attempt failed."
    echo "Trying cleanup and one retry..."
    cleanup_partial_submodule "$SUB_PATH"

    # Reconfirm remote access in case auth was the issue
    git ls-remote "$SUB_URL" >/dev/null 2>&1 || fail "Remote still not accessible after retry precheck."

    add_submodule || fail "Submodule add failed again after cleanup retry."
fi

echo
echo "Verifying result..."

[ -f .gitmodules ] || fail ".gitmodules was not created."

# Check that path is recorded in .gitmodules
git config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null | awk '{print $2}' | grep -Fx "$SUB_PATH" >/dev/null \
    || fail "Submodule path was not recorded in .gitmodules."

# Check that parent repo index has a gitlink entry
git ls-files --stage "$SUB_PATH" | awk '$1 == "160000" {found=1} END {exit(found?0:1)}' \
    || fail "Submodule path is not stored as a gitlink (mode 160000)."

echo
echo "Current .gitmodules:"
cat .gitmodules
echo

echo "Submodule status:"
git submodule status || true
echo

echo "Gitlink entry:"
git ls-files --stage "$SUB_PATH"
echo

echo "Staging .gitmodules and submodule entry..."
git add .gitmodules "$SUB_PATH"

echo
echo "Git status:"
git status --short
echo

if confirm "Create commit now? [y/N]: "; then
    DEFAULT_MSG="Add submodule $SUB_PATH"
    read -r -p "Commit message [${DEFAULT_MSG}]: " COMMIT_MSG
    COMMIT_MSG="${COMMIT_MSG:-$DEFAULT_MSG}"
    git commit -m "$COMMIT_MSG"
else
    echo "Skipping commit."
fi

echo
if confirm "Push current branch to origin now? [y/N]: "; then
    [ -n "${CURRENT_BRANCH:-}" ] || fail "Cannot push automatically from detached HEAD."
    git push origin "$CURRENT_BRANCH"
else
    echo "Skipping push."
fi

echo
echo "Done."
echo
echo "On another machine, after pulling the parent repo, initialize submodules with:"
echo "  git submodule sync --recursive"
echo "  git submodule update --init --recursive"
echo
echo "If a future add fails partway through, rerunning this script will try to clean:"
echo "  - leftover working tree path"
echo "  - stale .gitmodules entry"
echo "  - stale .git/config submodule entry"
echo "  - stale .git/modules cache"
