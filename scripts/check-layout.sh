#!/usr/bin/env bash
# Keeps agents' context cheap (AGENTS.md, "Keep context small"). Fails when
#  - a source file has more than MAX_CODE lines (default 250),
#  - a Markdown doc has more than MAX_DOC lines (default 200),
#  - a folder with MAP_AT or more source files (default 8) has no map
#    (README.md or doc.go), or its map does not mention one of them.
# Exceptions go in .layout-allow, one path per line with a reason after '#'.
set -euo pipefail
cd "$(dirname "$0")/.."
max_code="${MAX_CODE:-250}" max_doc="${MAX_DOC:-200}" map_at="${MAP_AT:-8}"
code='\.(go|ts|tsx|js|jsx|mjs|vue|svelte|py|rb|rs|java|kt|swift|c|h|cc|cpp|hpp|cs|php|ex|exs|dart|scala|lua|sh|css|scss|sql)$'
gen='(^|/)(vendor|node_modules|dist|build|generated|migrations)/|\.min\.|\.d\.ts$'
tests='_test\.go$|\.(test|spec)\.[a-z]+$|(^|/)tests?/'
allowed() { [ -f .layout-allow ] && grep -qxF "$1" <(sed 's/[[:space:]]*#.*//' .layout-allow); }

status=0
files=$(git ls-files -co --exclude-standard)
while IFS= read -r f; do
  if [ ! -f "$f" ] || [[ $f =~ $gen ]] || allowed "$f"; then continue; fi
  if [[ $f =~ $code ]]; then max=$max_code
  elif [[ $f == *.md ]]; then max=$max_doc
  else continue; fi
  n=$(wc -l < "$f")
  [ "$n" -le "$max" ] || { echo "$f: $n lines (max $max): split it by responsibility"; status=1; }
done <<< "$files"

# Folder maps: the folder's own source files (tests excluded) must be listed.
sources() { grep -E "$code" <<< "$files" | grep -vE "$gen|$tests" || true; }
while IFS= read -r d; do
  srcs=$(sources | awk -v d="$d" -F/ \
    'BEGIN { n = (d == ".") ? 0 : split(d, _, "/") } NF == n + 1 && (d == "." || index($0, d "/") == 1)' || true)
  [ "$(grep -c . <<< "$srcs")" -ge "$map_at" ] || continue
  map=""
  for m in "$d/README.md" "$d/doc.go"; do [ -f "$m" ] && map="$map $m"; done
  [ -n "$map" ] || { echo "$d/: $(grep -c . <<< "$srcs") source files and no README.md map"; status=1; continue; }
  while IFS= read -r s; do
    b=$(basename "$s")
    # shellcheck disable=SC2086 # $map is a list of files
    grep -qF "$b" $map || { echo "${map# }: map misses $b"; status=1; }
  done <<< "$srcs"
done < <(sources | xargs -r -n1 dirname | sort -u)
exit $status
