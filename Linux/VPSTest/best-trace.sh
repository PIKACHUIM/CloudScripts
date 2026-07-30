#!/usr/bin/env bash
# ============================================================
#  PIKA SH - BestTrace Wrapper
#  Downloads besttrace binary from mirror and runs interactively.
# ============================================================
set -e

MIRRORS=(
    "https://benchs.pika.net.cn/best-trace/besttrace4linux.zip"
    "https://gh-vps.pika.net.cn/best-trace/besttrace4linux.zip"
)

TMPD=$(mktemp -d) || exit 1
DOWNLOADED=0
for m in "${MIRRORS[@]}"; do
    if curl -fsSL --connect-timeout 8 --max-time 30 "$m" -o "$TMPD/besttrace.zip" 2>/dev/null; then
        DOWNLOADED=1; break
    fi
done
[ "$DOWNLOADED" = "0" ] && { echo "ERROR: Cannot download besttrace." >&2; rm -rf "$TMPD"; exit 1; }

cd "$TMPD"
unzip -q besttrace.zip
chmod +x besttrace

read -r -p "Enter target IP (default: 8.8.8.8): " target_ip
target_ip="${target_ip:-8.8.8.8}"

echo "Tracing route to $target_ip ..."
./besttrace -q1 "$target_ip"
rm -rf "$TMPD"
