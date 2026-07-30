#!/usr/bin/env bash
# ============================================================
#  PIKA SH - Quick System Bench Wrapper
#  Downloads latest qsyb bench from mirror and executes.
# ============================================================
set -e

MIRRORS=(
    "https://benchs.pika.net.cn/qsyb-bench/qsyb.sh"
    "https://gh-vps.pika.net.cn/qsyb-bench/qsyb.sh"
    "https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/assets/qsyb-bench/qsyb.sh"
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
