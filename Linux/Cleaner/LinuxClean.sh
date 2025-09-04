#!/usr/bin/env bash
set -e
echo "============= 清理垃圾 ============="
> ~/.bash_history
history -c && history -w
apt-get clean
apt-get autoclean
apt-get autoremove -y
journalctl --vacuum-time=7d
rm -rf ~/.cache/thumbnails/* ~/.local/share/Trash/*
rm -rf /var/crash/* /var/tmp/*
docker system prune -af 2>/dev/null || true
> ~/.bash_history
echo "============= 清理完成 ============="