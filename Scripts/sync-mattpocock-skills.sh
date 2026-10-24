#!/usr/bin/env bash
# Vendor Matt Pocock's promoted skills (engineering + productivity buckets,
# the same set his Claude Code plugin ships) into .claude/skills/.
#
# Usage: Scripts/sync-mattpocock-skills.sh [git-ref]   (default: main)
#
# Overwrites each vendored skill folder. Skills removed upstream are left in
# place; delete them by hand. See docs/agents/skills.md.
set -euo pipefail

ref="${1:-main}"
root="$(git rev-parse --show-toplevel)"
dest="$root/.claude/skills"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

git clone --quiet --filter=blob:none https://github.com/mattpocock/skills.git "$tmp/skills"
git -C "$tmp/skills" checkout --quiet "$ref"
sha="$(git -C "$tmp/skills" rev-parse HEAD)"

mkdir -p "$dest"
for bucket in engineering productivity; do
  for dir in "$tmp/skills/skills/$bucket"/*/; do
    dir="${dir%/}"
    name="$(basename "$dir")"
    rm -rf "${dest:?}/$name"
    cp -R "$dir" "$dest/$name"
  done
done

echo "Synced mattpocock/skills@$sha into .claude/skills/"
echo "Next: set the pinned commit in docs/agents/skills.md, then review 'git diff --stat .claude/skills'."
