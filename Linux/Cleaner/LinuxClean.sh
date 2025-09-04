#!/usr/bin/env bash
set -e
echo "== 备份 & 清理 =="
sudo tar czpf /var/backups/apt-$(date +%F).tar.gz /var/cache/apt
> ~/.bash_history
history -c && history -w
sudo apt-get clean
sudo apt-get autoclean
sudo apt-get autoremove -y
sudo journalctl --vacuum-time=7d
rm -rf ~/.cache/thumbnails/* ~/.local/share/Trash/*
sudo rm -rf /var/crash/* /var/tmp/*
docker system prune -af 2>/dev/null || true
echo "Done!"