#!/usr/bin/env bash
# ============================================================
#  PIKA SH - IP Quality Check Wrapper
#  Downloads latest IP quality script from mirror and executes.
# ============================================================
set -e

MIRRORS=(
    "https://benchs.pika.net.cn/ip-quality/ipcheck.sh"
    "https://gh-vps.pika.net.cn/ip-quality/ipcheck.sh"
    "https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/assets/ip-quality/ipcheck.sh"
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
