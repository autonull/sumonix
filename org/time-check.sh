#!/bin/sh
# Compare org/extract.nix's dates with org/time-oracle.jq over every page of a scratch directory.
#   sh org/time-check.sh PAGES.json SRC_DIR [JOBS]
# PAGES.json is the output of extract.nix (or org/pages.json); SRC_DIR holds <repo>/<path> for the pinned commits.
# Prints the number of pages that differ, and the first few.
set -eu
pages=$1; src=$2; jobs=${3:-4}; here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
jq -S -c '.[] | {repo, path, time, named}' "$pages" > "$out/want.jsonl"
lines=$(wc -l < "$out/want.jsonl")
split -l $(( (lines + jobs - 1) / jobs )) "$out/want.jsonl" "$out/part."
for part in "$out"/part.*; do
  (
    while IFS= read -r want; do
      repo=$(printf '%s' "$want" | jq -r .repo)
      path=$(printf '%s' "$want" | jq -r .path)
      got=$(jq -S -n -c --rawfile text "$src/$repo/$path" --arg path "$path" -f "$here/time-oracle.jq" 2>&1 || true)
      mine=$(printf '%s' "$want" | jq -S -c '{time, named}')
      [ "$got" = "$mine" ] || echo "DIFFERENT $repo $path"
    done < "$part"
  ) > "$part.diff" &
done
wait
cat "$out"/part.*.diff > "$out/diff.txt"
echo "pages checked: $(wc -l < "$out/want.jsonl" | tr -d ' ')   pages that differ: $(wc -l < "$out/diff.txt" | tr -d ' ')"
head -20 "$out/diff.txt"
