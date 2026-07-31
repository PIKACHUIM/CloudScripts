#!/usr/bin/env bash
# ============================================================
#  PIKA SH - Software Install Module
#  One-click install for popular self-hosted tools
# ============================================================
set -e

SoftwareMENU=(
    "lucky|software.lucky|software.lucky.desc|do_soft_lucky"
    "mcsmanager|software.mcsmanager|software.mcsmanager.desc|do_soft_mcsmanager"
    "openlist|software.openlist|software.openlist.desc|do_soft_openlist"
    "sunpanel|software.sunpanel|software.sunpanel.desc|do_soft_sunpanel"
    "uptimekuma|software.uptimekuma|software.uptimekuma.desc|do_soft_uptimekuma"
    "dockge|software.dockge|software.dockge.desc|do_soft_dockge"
    "npm|software.npm|software.npm.desc|do_soft_npm"
    "gitea|software.gitea|software.gitea.desc|do_soft_gitea"
    "navidrome|software.navidrome|software.navidrome.desc|do_soft_navidrome"
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
#  OpenList — 网盘聚合/文件管理 (AList 社区驱动分支)
#  https://github.com/OpenListTeam/OpenList
# ============================================================
do_soft_openlist() {
    ui_confirm_install "OpenList (网盘文件管理)" "$(t 'software.openlist.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') OpenList..."
    curl -fsSL https://raw.githubusercontent.com/OpenListTeam/OpenList/main/script/install.sh 2>/dev/null | bash -e 2>&1 | tail -5
    local pass; pass=$(/opt/openlist/openlist admin random 2>/dev/null || /opt/openlist/openlist admin 2>/dev/null | grep password | head -1)
    pika_info "$(t 'common.done') - OpenList → http://\$(hostname -I | awk '{print \$1}'):5244"
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

# ============================================================
#  Dockge — Docker Compose 管理面板
#  https://github.com/louislam/dockge
# ============================================================
do_soft_dockge() {
    ui_confirm_install "Dockge (Docker Compose 管理)" "$(t 'software.dockge.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') Dockge..."
    mkdir -p /opt/dockge && cd /opt/dockge
    curl -fsSL https://raw.githubusercontent.com/louislam/dockge/master/compose.yaml -o docker-compose.yml
    docker compose up -d 2>&1 | tail -3
    pika_info "$(t 'common.done') - Dockge → http://\$(hostname -I | awk '{print \$1}'):5001"
}

# ============================================================
#  Nginx Proxy Manager — 反向代理/SSL 管理面板
#  https://github.com/NginxProxyManager/nginx-proxy-manager
# ============================================================
do_soft_npm() {
    ui_confirm_install "Nginx Proxy Manager (反向代理)" "$(t 'software.npm.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') Nginx Proxy Manager..."
    if ! command -v docker >/dev/null 2>&1; then
        pika_info "Docker not found, installing..."
        curl -fsSL https://get.docker.com | bash -e
    fi
    mkdir -p /opt/npm && cd /opt/npm
    curl -fsSL https://raw.githubusercontent.com/NginxProxyManager/nginx-proxy-manager/develop/docker-compose.yml -o docker-compose.yml
    docker compose up -d 2>&1 | tail -3
    pika_info "$(t 'common.done') - NPM → http://\$(hostname -I | awk '{print \$1}'):81 (admin@example.com/changeme)"
}

# ============================================================
#  Gitea — 轻量级自托管 Git 服务
#  https://github.com/go-gitea/gitea
# ============================================================
do_soft_gitea() {
    ui_confirm_install "Gitea (自托管 Git)" "$(t 'software.gitea.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') Gitea..."
    if ! command -v docker >/dev/null 2>&1; then
        pika_info "Docker not found, installing..."
        curl -fsSL https://get.docker.com | bash -e
    fi
    mkdir -p /opt/gitea && cd /opt/gitea
    docker run -d --name=gitea --restart=always -p 3000:3000 -p 2222:22 \
        -v /opt/gitea/data:/data -v /etc/timezone:/etc/timezone:ro -v /etc/localtime:/etc/localtime:ro \
        gitea/gitea:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - Gitea → http://\$(hostname -I | awk '{print \$1}'):3000"
}

# ============================================================
#  Navidrome — 音乐流媒体服务器
#  https://github.com/navidrome/navidrome
# ============================================================
do_soft_navidrome() {
    ui_confirm_install "Navidrome (音乐流媒体)" "$(t 'software.navidrome.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') Navidrome..."
    if ! command -v docker >/dev/null 2>&1; then
        pika_info "Docker not found, installing..."
        curl -fsSL https://get.docker.com | bash -e
    fi
    mkdir -p /opt/navidrome/data /opt/navidrome/music
    docker run -d --name=navidrome --restart=always \
        -p 4533:4533 \
        -v /opt/navidrome/data:/data \
        -v /opt/navidrome/music:/music:ro \
        -e ND_LOGLEVEL=info \
        deluan/navidrome:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - Navidrome → http://\$(hostname -I | awk '{print \$1}'):4533"
}
