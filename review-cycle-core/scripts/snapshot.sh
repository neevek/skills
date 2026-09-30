#!/bin/sh
# Capture the working tree (tracked and untracked, honoring .gitignore) as a
# git tree object and write review patches, without touching the index,
# worktree, or refs. Run it from inside the repository under review.
#
# Usage: snapshot.sh OUT_DIR BASE [PREV_TREE] [-- PATHSPEC...]
#   OUT_DIR    where patches go; outside the worktree, or git-ignored
#   BASE       commit-ish the subject is reviewed against
#   PREV_TREE  tree printed by an earlier run; also writes the exact delta
#   PATHSPEC   limits the patches, relative to the current directory; the
#              tree ID always covers the whole worktree
# Prints tree=, subject=, and (with PREV_TREE) delta= lines.
set -eu

[ $# -ge 2 ] || { echo "usage: $0 OUT_DIR BASE [PREV_TREE] [-- PATHSPEC...]" >&2; exit 2; }
made=
[ -d "$1" ] || made=1
mkdir -p "$1"
out=$(cd "$1" && pwd -P)
base=$2
shift 2
prev=
if [ $# -gt 0 ] && [ "$1" != "--" ]; then prev=$1; shift; fi
if [ $# -gt 0 ] && [ "$1" = "--" ]; then shift; fi

# Patches captured into the next snapshot would change its tree ID on every run.
top=$(cd "$(git rev-parse --show-toplevel)" && pwd -P)
case "$out/" in
  "$top/.git/"*) ;;
  "$top/"*) git check-ignore -q "$out" || {
    [ -z "$made" ] || rmdir "$out" 2>/dev/null || :
    echo "OUT_DIR must be outside the worktree or git-ignored: $out" >&2
    exit 2
  } ;;
esac

idx=$(mktemp)
trap 'rm -f "$idx"' EXIT
# Seeding from the real index keeps `add -A` incremental; without one, git builds a fresh index.
cp "$(git rev-parse --git-path index)" "$idx" 2>/dev/null || rm -f "$idx"
GIT_INDEX_FILE=$idx git add -A
tree=$(GIT_INDEX_FILE=$idx git write-tree)
short=$(git rev-parse --short "$tree")

patch() {
  git diff --no-ext-diff --no-textconv --no-color --src-prefix=a/ --dst-prefix=b/ --binary "$@"
}
patch "$base" "$tree" -- "$@" > "$out/subject-$short.patch"
echo "tree=$tree"
echo "subject=$out/subject-$short.patch"
if [ -n "$prev" ]; then
  delta="$out/delta-$(git rev-parse --short "$prev")-$short.patch"
  patch "$prev" "$tree" -- "$@" > "$delta"
  echo "delta=$delta"
fi
