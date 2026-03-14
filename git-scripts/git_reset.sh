#!/usr/bin/env bash
set -euo pipefail

# git_reset.sh
#
# What it does:
# 1. Fetches the latest origin/main
# 2. Finds every path that differs between this clone and origin/main
# 3. Saves each differing file into an "archive" folder in that file's own directory
#    Example:
#      testing/example.cpp
#    becomes:
#      testing/archive/example_archive_20260314_160501.cpp
# 4. Ensures all archive directories are gitignored
# 5. Resets this clone to a fresh copy of origin/main

REMOTE="origin"
BRANCH="main"
STAMP="$(date +%Y%m%d_%H%M%S)"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "Not inside a git repo."

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

echo "Repo root : $REPO_ROOT"
echo "Remote    : $REMOTE"
echo "Branch    : $BRANCH"
echo "Stamp     : $STAMP"
echo

echo "Fetching latest $REMOTE/$BRANCH ..."
git fetch "$REMOTE" "$BRANCH"

# Make sure all archive directories are ignored everywhere in the repo.
# "archive/" matches any directory named archive at any depth.
touch .gitignore
if ! grep -qxF "archive/" .gitignore; then
    echo "" >> .gitignore
    echo "# Ignore per-folder archive directories" >> .gitignore
    echo "archive/" >> .gitignore
fi

declare -A PATHS=()

add_paths() {
    while IFS= read -r -d '' p; do
        [ -n "$p" ] || continue
        [[ "$p" == */archive/* ]] && continue
        [[ "$p" == archive/* ]] && continue
        PATHS["$p"]=1
    done
}

# Differences in working tree vs index
add_paths < <(git diff --name-only -z)

# Differences staged in index
add_paths < <(git diff --cached --name-only -z)

# Differences in local commits vs origin/main
add_paths < <(git diff --name-only -z "$REMOTE/$BRANCH..HEAD")

# Untracked files
add_paths < <(git ls-files --others --exclude-standard -z)

if [ "${#PATHS[@]}" -eq 0 ]; then
    echo "No differences found."
else
    echo "Archiving differing files..."
fi

for path in "${!PATHS[@]}"; do
    dir="$(dirname "$path")"
    filename="$(basename "$path")"

    if [[ "$filename" == *.* ]]; then
        base="${filename%.*}"
        ext=".${filename##*.}"
    else
        base="$filename"
        ext=""
    fi

    archive_dir="$dir/archive"
    archive_file="$archive_dir/${base}_archive_${STAMP}${ext}"

    mkdir -p "$archive_dir"

    # 1) If the file exists in the working tree now, archive that exact local copy.
    if [ -f "$path" ]; then
        cp -a "$path" "$archive_file"
        echo "  saved: $archive_file"
        continue
    fi

    # 2) If file does not exist in working tree, try the staged/index version.
    #    This covers cases where the file is deleted in working tree but still staged/present in index.
    if git ls-files --error-unmatch "$path" >/dev/null 2>&1; then
        git show ":$path" > "$archive_file"
        echo "  saved from index: $archive_file"
        continue
    fi

    # 3) If not in working tree or index, try HEAD.
    #    This covers files that differ only because local commits changed them.
    if git cat-file -e "HEAD:$path" 2>/dev/null; then
        git show "HEAD:$path" > "$archive_file"
        echo "  saved from HEAD: $archive_file"
        continue
    fi

    echo "  skipped: $path"
done

echo
echo "Resetting clone to fresh $REMOTE/$BRANCH ..."

git reset --hard
git clean -fd -e archive/ -e '*/archive/'
git checkout -B "$BRANCH" "$REMOTE/$BRANCH"
git reset --hard "$REMOTE/$BRANCH"
git clean -fd -e archive/ -e '*/archive/'

echo
echo "Done."
echo "Archived copies were saved into per-folder archive directories."
echo "All archive directories are gitignored via .gitignore."
echo "This clone now matches $REMOTE/$BRANCH."
