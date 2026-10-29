#!/usr/bin/env bash
# Runs the contrast half of the palette check locally, the same way CI runs it on a PR.
#
#   ./.github/workflows/contrast-check.sh                    # every palette in the repo
#   ./.github/workflows/contrast-check.sh "My Palette"/*.json # just yours
#   ./.github/workflows/contrast-check.sh --all               # print every pair, not only offenders
#
# The jq program and the thresholds are read out of palette-check.yml, so this
# cannot report something different from CI.
set -euo pipefail

show_all=false
files=()
for arg in "$@"; do
  case "$arg" in
    --all) show_all=true ;;
    -h | --help)
      sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) files+=("$arg") ;;
  esac
done

repo_root=$(git rev-parse --show-toplevel)
workflow="$repo_root/.github/workflows/palette-check.yml"

program=$(sed -n "/<<'CONTRAST_JQ'/,/^ *CONTRAST_JQ$/p" "$workflow" | sed '1d;$d')
floor=$(sed -n 's/^ *contrast_floor=//p' "$workflow")
warn=$(sed -n 's/^ *contrast_warn=//p' "$workflow")

if [ -z "$program" ] || [ -z "$floor" ] || [ -z "$warn" ]; then
  echo "error: could not read the contrast program or thresholds from $workflow" >&2
  exit 2
fi

if [ ${#files[@]} -eq 0 ]; then
  mapfile -t files < <(find "$repo_root" -mindepth 2 -maxdepth 2 -name '*.json' -not -path '*/.*' | sort)
fi

failures=0
warnings=0
checked=0

for file in "${files[@]}"; do
  while IFS=$'\t' read -r ratio mode fg_key bg_key fg bg; do
    [ -z "$ratio" ] && continue
    checked=$((checked + 1))
    shown=$(LC_ALL=C awk -v r="$ratio" 'BEGIN { printf "%5.2f", r }')
    label=""
    if awk -v r="$ratio" -v f="$floor" 'BEGIN { exit !(r < f) }'; then
      label="FAIL"
      failures=$((failures + 1))
    elif awk -v r="$ratio" -v w="$warn" 'BEGIN { exit !(r < w) }'; then
      label="WARN"
      warnings=$((warnings + 1))
    elif [ "$show_all" = true ]; then
      label="ok  "
    fi
    [ -z "$label" ] && continue
    printf '%s %s:1  %-40s %-5s %s on %s (%s on %s)\n' \
      "$label" "$shown" "${file#"$repo_root"/}" "$mode" "$fg_key" "$bg_key" "$fg" "$bg"
  done < <(jq -r "$program" "$file")
done

printf '\n%d pairs checked in %d file(s): %d below %s:1, %d between %s:1 and %s:1\n' \
  "$checked" "${#files[@]}" "$failures" "$floor" "$warnings" "$floor" "$warn"

[ "$failures" -eq 0 ]
