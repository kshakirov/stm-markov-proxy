#!/usr/bin/env bash
set -euo pipefail

# Manual local check: bash scripts/check-proxy.sh
# 100 requests/s for 10 seconds: nominally 1000 requests.
vegeta_bin="${VEGETA_BIN:-vegeta}"
target_url="${TARGET_URL:-http://127.0.0.1:8000/}"

command -v "$vegeta_bin" >/dev/null 2>&1 || {
  echo "Vegeta not found; set VEGETA_BIN to its executable path." >&2
  exit 1
}

result_dir="$(mktemp -d "${TMPDIR:-/tmp}/proxy-check.XXXXXX")"
echo "Target: $target_url"
echo "Results: $result_dir"

printf 'GET %s\n' "$target_url" |
  "$vegeta_bin" attack \
    -rate=1000/s \
    -duration=10s \
    -workers=5 \
    -max-workers=5 \
    -timeout=5s \
    -keepalive=false \
    -http2=false \
    -output="$result_dir/results.bin"

"$vegeta_bin" report "$result_dir/results.bin"
"$vegeta_bin" report -type=json \
  -output="$result_dir/report.json" "$result_dir/results.bin"
