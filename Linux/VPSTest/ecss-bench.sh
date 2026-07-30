#!/usr/bin/env bash
# ============================================================
#  PIKA SH - Fusion Monster (融合怪) Benchmark Wrapper
#  Downloads the latest ecs.sh from mirror and executes it.
#  Original: SpiritLHLS/ecs
# ============================================================
set -e

MIRRORS=(
    "https://benchs.pika.net.cn/ecss-bench/ecs.sh"
    "https://gh-vps.pika.net.cn/ecss-bench/ecs.sh"
    "https://github.524228.xyz/https://raw.githubusercontent.com/spiritLHLS/ecs/main/ecs.sh"
    "https://raw.githubusercontent.com/spiritLHLS/ecs/main/ecs.sh"
)

TMPF=$(mktemp) || { echo "ERROR: Cannot create temp file" >&2; exit 1; }
for m in "${MIRRORS[@]}"; do
    if curl -fsSL --connect-timeout 8 --max-time 30 "$m" -o "$TMPF" 2>/dev/null; then
        chmod +x "$TMPF"
        bash "$TMPF" "$@"
        rm -f "$TMPF"
        exit 0
    fi
done
echo "ERROR: All mirror sources are unavailable." >&2
rm -f "$TMPF"
exit 1
