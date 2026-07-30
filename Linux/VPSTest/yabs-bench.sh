#!/usr/bin/env bash
# ============================================================
#  PIKA SH - YABS Benchmark Wrapper
#  Downloads latest yabs.sh from mirror and executes.
#  Original: masonr/yet-another-bench-script (MIT)
# ============================================================
set -e

MIRRORS=(
    "https://benchs.pika.net.cn/yabs-bench/yabs.sh"
    "https://gh-vps.pika.net.cn/yabs-bench/yabs.sh"
    "https://github.524228.xyz/https://raw.githubusercontent.com/masonr/yet-another-bench-script/master/yabs.sh"
    "https://raw.githubusercontent.com/masonr/yet-another-bench-script/master/yabs.sh"
)

TMPF=$(mktemp) || exit 1
for m in "${MIRRORS[@]}"; do
    if curl -fsSL --connect-timeout 8 --max-time 30 "$m" -o "$TMPF" 2>/dev/null; then
        chmod +x "$TMPF"
        bash "$TMPF" "$@"
        rm -f "$TMPF"
        exit 0
    fi
done
echo "ERROR: All mirror sources are unavailable." >&2; rm -f "$TMPF"; exit 1
