#!/usr/bin/env bash
# ============================================================
#  PIKA SH - Software Install Module
#  One-click install for popular self-hosted tools
# ============================================================
set -e

SoftwareMENU=(
    "lucky|software.lucky|software.lucky.desc|do_soft_lucky"
    "mcsmanager|software.mcsmanager|software.mcsmanager.desc|do_soft_mcsmanager"
    "alist|software.alist|software.alist.desc|do_soft_alist"
    "sunpanel|software.sunpanel|software.sunpanel.desc|do_soft_sunpanel"
    "uptimekuma|software.uptimekuma|software.uptimekuma.desc|do_soft_uptimekuma"
)

# ============================================================
#  Lucky — 端口转发/DDNS/反代/证书管理
#  https://github.com/gdy666/lucky
# ============================================================
do_soft_lucky() {
    ui_confirm_install "Lucky (端口转发/DDNS/反代)" "$(t 'software.lucky.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') Lucky..."
    curl -sSL https://raw.githubusercontent.com/gdy666/lucky-files/main/golucky.sh 2>/dev/null | bash -e 2>&1 | tail -5
    pika_info "$(t 'common.done') - Lucky → http://\$(hostname -I | awk '{print \$1}'):16601 (admin:666/666)"
}

# ============================================================
#  MCSManager — Minecraft/游戏服务器管理面板
#  https://github.com/MCSManager/MCSManager
# ============================================================
do_soft_mcsmanager() {
    ui_confirm_install "MCSManager (游戏服务器面板)" "$(t 'software.mcsmanager.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') MCSManager..."
    curl -sSL https://script.mcsmanager.com/setup.sh 2>/dev/null | bash -e 2>&1 | tail -5
    pika_info "$(t 'common.done') - MCSManager → http://\$(hostname -I | awk '{print \$1}'):23333"
}

# ============================================================
#  Alist — 网盘聚合/文件管理
#  https://github.com/alist-org/alist
# ============================================================
do_soft_alist() {
    ui_confirm_install "Alist (网盘文件管理)" "$(t 'software.alist.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') Alist..."
    curl -fsSL https://alist.nn.ci/install.sh 2>/dev/null | bash -e 2>&1 | tail -5
    local pass; pass=$(/opt/alist/alist admin random 2>/dev/null || /opt/alist/alist admin 2>/dev/null | grep password | head -1)
    pika_info "$(t 'common.done') - Alist → http://\$(hostname -I | awk '{print \$1}'):5244"
    [ -n "$pass" ] && echo "  $pass"
}

# ============================================================
#  Sun-Panel — 服务器/NAS导航面板
#  https://github.com/hslr-s/sun-panel
# ============================================================
do_soft_sunpanel() {
    ui_confirm_install "Sun-Panel (导航首页)" "$(t 'software.sunpanel.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') Sun-Panel..."
    bash <(curl -fsSL https://ghproxy.net/https://raw.githubusercontent.com/hslr-s/sun-panel/main/script/linux_install.sh) 2>&1 | tail -5
    pika_info "$(t 'common.done') - Sun-Panel → http://\$(hostname -I | awk '{print \$1}'):3002"
}

# ============================================================
#  Uptime Kuma — 服务器在线监控
#  https://github.com/louislam/uptime-kuma
# ============================================================
do_soft_uptimekuma() {
    ui_confirm_install "Uptime Kuma (服务器监控)" "$(t 'software.uptimekuma.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') Uptime Kuma..."
    # Install via PM2 (no docker required)
    pkg_install curl wget git
    command -v node >/dev/null 2>&1 || curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs
    command -v pm2 >/dev/null 2>&1 || npm install -g pm2

    local dir="/opt/uptime-kuma"
    if [ -d "$dir" ]; then
        cd "$dir" && git pull
    else
        git clone https://github.com/louislam/uptime-kuma.git "$dir"
        cd "$dir"
        npm ci --production
    fi
    pm2 start server/server.js --name uptime-kuma -- --port=3001
    pm2 save
    pika_info "$(t 'common.done') - Uptime Kuma → http://\$(hostname -I | awk '{print \$1}'):3001"
}
