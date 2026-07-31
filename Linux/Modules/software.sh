#!/usr/bin/env bash
# ============================================================
#  PIKA SH - Software Install Module
#  53 popular self-hosted tools — one-click install
# ============================================================
set -e

SoftwareMENU=(
# === 网络与服务 ===
    "lucky|software.lucky|software.lucky.desc|do_soft_lucky"
    "npm|software.npm|software.npm.desc|do_soft_npm"
    "ddnsgo|software.ddnsgo|software.ddnsgo.desc|do_soft_ddnsgo"
# === AI 对话前端 ===
    "lobechat|software.lobechat|software.lobechat.desc|do_soft_lobechat"
    "openwebui|software.openwebui|software.openwebui.desc|do_soft_openwebui"
# === 面板与管理 ===
    "portainer|software.portainer|software.portainer.desc|do_soft_portainer"
    "dockge|software.dockge|software.dockge.desc|do_soft_dockge"
    "glance|software.glance|software.glance.desc|do_soft_glance"
    "homarr|software.homarr|software.homarr.desc|do_soft_homarr"
    "sunpanel|software.sunpanel|software.sunpanel.desc|do_soft_sunpanel"
    "homepage|software.homepage|software.homepage.desc|do_soft_homepage"
# === 博客与 CMS ===
    "halo|software.halo|software.halo.desc|do_soft_halo"
    "typecho|software.typecho|software.typecho.desc|do_soft_typecho"
# === 影音媒体 ===
    "jellyfin|software.jellyfin|software.jellyfin.desc|do_soft_jellyfin"
    "navidrome|software.navidrome|software.navidrome.desc|do_soft_navidrome"
    "immich|software.immich|software.immich.desc|do_soft_immich"
    "openlist|software.openlist|software.openlist.desc|do_soft_openlist"
# === 下载工具 ===
    "qbit|software.qbit|software.qbit.desc|do_soft_qbit"
    "aria2pro|software.aria2pro|software.aria2pro.desc|do_soft_aria2pro"
    "transmission|software.transmission|software.transmission.desc|do_soft_transmission"
# === 密码与安全 ===
    "vaultwarden|software.vaultwarden|software.vaultwarden.desc|do_soft_vaultwarden"
    "casdoor|software.casdoor|software.casdoor.desc|do_soft_casdoor"
    "privatebin|software.privatebin|software.privatebin.desc|do_soft_privatebin"
    "cloudflareddns|software.cloudflareddns|software.cloudflareddns.desc|do_soft_cloudflareddns"
# === 内网穿透与组网 ===
    "nps|software.nps|software.nps.desc|do_soft_nps"
# === 存储与同步 ===
    "nextcloud|software.nextcloud|software.nextcloud.desc|do_soft_nextcloud"
    "syncthing|software.syncthing|software.syncthing.desc|do_soft_syncthing"
    "filebrowser|software.filebrowser|software.filebrowser.desc|do_soft_filebrowser"
# === 搜索引擎 ===
    "searxng|software.searxng|software.searxng.desc|do_soft_searxng"
# === AI 与 API ===
    "oneapi|software.oneapi|software.oneapi.desc|do_soft_oneapi"
    "newapi|software.newapi|software.newapi.desc|do_soft_newapi"
    "cliproxyapi|software.cliproxyapi|software.cliproxyapi.desc|do_soft_cliproxyapi"
    "sub2api|software.sub2api|software.sub2api.desc|do_soft_sub2api"
# === 开发与自动化 ===
    "gitea|software.gitea|software.gitea.desc|do_soft_gitea"
    "n8n|software.n8n|software.n8n.desc|do_soft_n8n"
    "nodered|software.nodered|software.nodered.desc|do_soft_nodered"
    "it_tools|software.it_tools|software.it_tools.desc|do_soft_it_tools"
    "stirlingpdf|software.stirlingpdf|software.stirlingpdf.desc|do_soft_stirlingpdf"
# === 生产力 ===
    "siyuan|software.siyuan|software.siyuan.desc|do_soft_siyuan"
    "memos|software.memos|software.memos.desc|do_soft_memos"
    "trilium|software.trilium|software.trilium.desc|do_soft_trilium"
    "excalidraw|software.excalidraw|software.excalidraw.desc|do_soft_excalidraw"
    "vikunja|software.vikunja|software.vikunja.desc|do_soft_vikunja"
    "homebox|software.homebox|software.homebox.desc|do_soft_homebox"
# === 阅读与信息 ===
    "miniflux|software.miniflux|software.miniflux.desc|do_soft_miniflux"
    "wallabag|software.wallabag|software.wallabag.desc|do_soft_wallabag"
    "changedetection|software.changedetection|software.changedetection.desc|do_soft_changedetection"
# === 消息推送 ===
    "bark|software.bark|software.bark.desc|do_soft_bark"
# === 监控 ===
    "uptimekuma|software.uptimekuma|software.uptimekuma.desc|do_soft_uptimekuma"
    "speedtest|software.speedtest|software.speedtest.desc|do_soft_speedtest"
    "mcsmanager|software.mcsmanager|software.mcsmanager.desc|do_soft_mcsmanager"
)
    "speedtest|software.speedtest|software.speedtest.desc|do_soft_speedtest"
    "mcsmanager|software.mcsmanager|software.mcsmanager.desc|do_soft_mcsmanager"
)

# ─── Shared helpers ──────────────────────────────────────────
_soft_ensure_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        pika_info "Docker not found, installing..."
        curl -fsSL https://get.docker.com | bash -e
    fi
}

_soft_docker_run() {
    local name="$1" image="$2" port="$3" shift 3
    docker rm -f "$name" 2>/dev/null || true
    docker run -d --name="$name" --restart=always -p "$port" "$@" "$image"
}

# ─── 网络与服务 ──────────────────────────────────────────────
do_soft_lucky() {
    ui_confirm_install "Lucky" "$(t 'software.lucky.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') Lucky..."
    curl -sSL https://raw.githubusercontent.com/gdy666/lucky-files/main/golucky.sh 2>/dev/null | bash -e 2>&1 | tail -5
    pika_info "$(t 'common.done') - 端口:16601 (admin:666/666)"
}

do_soft_npm() {
    ui_confirm_install "Nginx Proxy Manager" "$(t 'software.npm.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/npm/data /opt/npm/letsencrypt
    docker rm -f npm 2>/dev/null || true
    docker run -d --name=npm --restart=always \
        -p 80:80 -p 443:443 -p 81:81 \
        -v /opt/npm/data:/data -v /opt/npm/letsencrypt:/etc/letsencrypt \
        jc21/nginx-proxy-manager:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:81 (admin@example.com/changeme)"
}

# ─── AI 对话前端 ─────────────────────────────────────────────
do_soft_lobechat() {
    ui_confirm_install "LobeChat" "$(t 'software.lobechat.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    docker rm -f lobechat 2>/dev/null || true
    docker run -d --name=lobechat --restart=always \
        -p 3210:3210 -e OPENAI_API_KEY=sk-your-key \
        -e OPENAI_PROXY_URL=https://api.openai.com/v1 \
        lobehub/lobe-chat:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:3210"
}

do_soft_openwebui() {
    ui_confirm_install "Open WebUI" "$(t 'software.openwebui.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/openwebui
    docker rm -f open-webui 2>/dev/null || true
    docker run -d --name=open-webui --restart=always \
        -p 3000:8080 -v /opt/openwebui:/app/backend/data \
        ghcr.io/open-webui/open-webui:main 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:3000"
}

do_soft_ddnsgo() {
    ui_confirm_install "DDNS-GO" "$(t 'software.ddnsgo.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/ddns-go
    docker rm -f ddns-go 2>/dev/null || true
    docker run -d --name=ddns-go --restart=always \
        -p 9876:9876 -v /opt/ddns-go:/root \
        jeessy/ddns-go:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:9876"
}

# ─── 面板与管理 ──────────────────────────────────────────────
do_soft_portainer() {
    ui_confirm_install "Portainer" "$(t 'software.portainer.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    docker rm -f portainer 2>/dev/null || true
    docker run -d --name=portainer --restart=always \
        -p 8000:8000 -p 9443:9443 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v /opt/portainer:/data \
        portainer/portainer-ce:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - https://localhost:9443"
}

do_soft_dockge() {
    ui_confirm_install "Dockge" "$(t 'software.dockge.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/dockge/data /opt/dockge/stacks
    docker rm -f dockge 2>/dev/null || true
    docker run -d --name=dockge --restart=always \
        -p 5001:5001 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v /opt/dockge/data:/app/data -v /opt/dockge/stacks:/opt/stacks \
        -e DOCKGE_STACKS_DIR=/opt/stacks \
        louislam/dockge:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:5001"
}

do_soft_homarr() {
    ui_confirm_install "Homarr" "$(t 'software.homarr.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/homarr
    docker rm -f homarr 2>/dev/null || true
    docker run -d --name=homarr --restart=always \
        -p 7575:7575 -v /opt/homarr:/app/data \
        ghcr.io/homarr-labs/homarr:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:7575"
}

do_soft_sunpanel() {
    ui_confirm_install "Sun-Panel" "$(t 'software.sunpanel.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') Sun-Panel..."
    bash <(curl -fsSL https://raw.githubusercontent.com/hslr-s/sun-panel/main/script/linux_install.sh) 2>&1 | tail -5
    pika_info "$(t 'common.done') - http://localhost:3002"
}

do_soft_homepage() {
    ui_confirm_install "Homepage" "$(t 'software.homepage.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/homepage/config
    docker rm -f homepage 2>/dev/null || true
    docker run -d --name=homepage --restart=always \
        -p 3000:3000 -v /opt/homepage/config:/app/config \
        -v /var/run/docker.sock:/var/run/docker.sock \
        ghcr.io/gethomepage/homepage:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:3000"
}

do_soft_glance() {
    ui_confirm_install "Glance" "$(t 'software.glance.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/glance
    docker rm -f glance 2>/dev/null || true
    docker run -d --name=glance --restart=always \
        -p 8080:8080 -v /opt/glance/glance.yml:/app/glance.yml \
        glanceapp/glance:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:8080"
}

# ─── 博客与 CMS ──────────────────────────────────────────────
do_soft_halo() {
    ui_confirm_install "Halo Blog" "$(t 'software.halo.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/halo
    docker rm -f halo 2>/dev/null || true
    docker run -d --name=halo --restart=always \
        -p 8090:8090 -v /opt/halo:/root/.halo2 \
        halohub/halo:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:8090"
}

do_soft_typecho() {
    ui_confirm_install "Typecho" "$(t 'software.typecho.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/typecho
    docker rm -f typecho 2>/dev/null || true
    docker run -d --name=typecho --restart=always \
        -p 8087:80 -v /opt/typecho:/app \
        joyqi/typecho:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:8087"
}

# ─── 影音媒体 ────────────────────────────────────────────────
do_soft_jellyfin() {
    ui_confirm_install "Jellyfin" "$(t 'software.jellyfin.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/jellyfin/config /opt/jellyfin/cache /opt/jellyfin/media
    docker rm -f jellyfin 2>/dev/null || true
    docker run -d --name=jellyfin --restart=always \
        -p 8096:8096 \
        -v /opt/jellyfin/config:/config -v /opt/jellyfin/cache:/cache \
        -v /opt/jellyfin/media:/media \
        jellyfin/jellyfin:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:8096"
}

do_soft_navidrome() {
    ui_confirm_install "Navidrome" "$(t 'software.navidrome.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/navidrome/data /opt/navidrome/music
    docker rm -f navidrome 2>/dev/null || true
    docker run -d --name=navidrome --restart=always \
        -p 4533:4533 -v /opt/navidrome/data:/data \
        -v /opt/navidrome/music:/music:ro \
        deluan/navidrome:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:4533"
}

do_soft_immich() {
    ui_confirm_install "Immich (照片管理)" "$(t 'software.immich.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/immich && cd /opt/immich
    curl -fsSL https://raw.githubusercontent.com/immich-app/immich/main/docker/docker-compose.yml -o docker-compose.yml
    curl -fsSL https://raw.githubusercontent.com/immich-app/immich/main/docker/.env -o .env
    docker compose up -d 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:2283"
}

do_soft_openlist() {
    ui_confirm_install "OpenList" "$(t 'software.openlist.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') OpenList..."
    curl -fsSL https://raw.githubusercontent.com/OpenListTeam/OpenList/main/script/install.sh 2>/dev/null | bash -e 2>&1 | tail -5
    pika_info "$(t 'common.done') - http://localhost:5244"
}

# ─── 下载工具 ────────────────────────────────────────────────
do_soft_qbit() {
    ui_confirm_install "qBittorrent" "$(t 'software.qbit.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pkg_install qbittorrent-nox 2>/dev/null || {
        _soft_ensure_docker
        mkdir -p /opt/qbit/config /opt/qbit/downloads
        docker rm -f qbittorrent 2>/dev/null || true
        docker run -d --name=qbittorrent --restart=always \
            -p 8080:8080 -v /opt/qbit/config:/config -v /opt/qbit/downloads:/downloads \
            linuxserver/qbittorrent:latest
    }
    pika_info "$(t 'common.done') - http://localhost:8080 (admin/adminadmin)"
}

do_soft_aria2pro() {
    ui_confirm_install "Aria2 Pro" "$(t 'software.aria2pro.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') Aria2 Pro..."
    bash <(curl -fsSL https://raw.githubusercontent.com/P3TERX/Aria2-Pro-Core/master/install.sh) 2>&1 | tail -5
    pika_info "$(t 'common.done') - RPC端口:6800"
}

do_soft_transmission() {
    ui_confirm_install "Transmission" "$(t 'software.transmission.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pkg_install transmission-daemon 2>/dev/null || {
        _soft_ensure_docker
        mkdir -p /opt/transmission/config /opt/transmission/downloads /opt/transmission/watch
        docker rm -f transmission 2>/dev/null || true
        docker run -d --name=transmission --restart=always \
            -p 9091:9091 -v /opt/transmission/config:/config \
            -v /opt/transmission/downloads:/downloads -v /opt/transmission/watch:/watch \
            -e USER=admin -e PASS=admin \
            linuxserver/transmission:latest
    }
    pika_info "$(t 'common.done') - http://localhost:9091 (admin/admin)"
}

# ─── 密码与安全 ──────────────────────────────────────────────
do_soft_nps() {
    ui_confirm_install "NPS (内网穿透)" "$(t 'software.nps.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') NPS..."
    bash <(curl -fsSL https://ghproxy.net/https://raw.githubusercontent.com/ehang-io/nps/master/scripts/install.sh) 2>&1 | tail -5
    pika_info "$(t 'common.done') - Web:8080 (admin/123)"
}

do_soft_vaultwarden() {
    ui_confirm_install "Vaultwarden" "$(t 'software.vaultwarden.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/vaultwarden
    docker rm -f vaultwarden 2>/dev/null || true
    docker run -d --name=vaultwarden --restart=always \
        -p 8088:80 -v /opt/vaultwarden:/data \
        vaultwarden/server:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:8088"
}

do_soft_privatebin() {
    ui_confirm_install "PrivateBin" "$(t 'software.privatebin.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    docker rm -f privatebin 2>/dev/null || true
    docker run -d --name=privatebin --restart=always \
        -p 8089:80 privatebin/nginx-fpm-alpine:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:8089"
}

do_soft_cloudflareddns() {
    ui_confirm_install "Cloudflare DDNS" "$(t 'software.cloudflareddns.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') Cloudflare DDNS..."
    curl -fsSL https://raw.githubusercontent.com/wherelse/cloudflareddns/main/cloudflareddns.sh -o /usr/local/bin/cloudflareddns.sh
    chmod +x /usr/local/bin/cloudflareddns.sh
    pika_info "$(t 'common.done') - 编辑 /usr/local/bin/cloudflareddns.sh 填入 API Token 后通过 cron 运行"
}

do_soft_casdoor() {
    ui_confirm_install "Casdoor" "$(t 'software.casdoor.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    docker rm -f casdoor 2>/dev/null || true
    docker run -d --name=casdoor --restart=always \
        -p 8000:8000 -p 7001:7001 \
        casbin/casdoor:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:8000 (admin/123)"
}

# ─── 内网穿透与组网 ──────────────────────────────────────────
do_soft_nps() {
    ui_confirm_install "NPS (内网穿透)" "$(t 'software.nps.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') NPS..."
    bash <(curl -fsSL https://ghproxy.net/https://raw.githubusercontent.com/ehang-io/nps/master/scripts/install.sh) 2>&1 | tail -5
    pika_info "$(t 'common.done') - http://localhost:8080 (admin/123)"
}

# ─── 存储与同步 ──────────────────────────────────────────────
do_soft_nextcloud() {
    ui_confirm_install "NextCloud" "$(t 'software.nextcloud.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') NextCloud..."
    _soft_ensure_docker
    mkdir -p /opt/nextcloud
    docker rm -f nextcloud 2>/dev/null || true
    docker run -d --name=nextcloud --restart=always \
        -p 8081:80 -v /opt/nextcloud:/var/www/html \
        nextcloud:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:8081"
}

do_soft_syncthing() {
    ui_confirm_install "Syncthing" "$(t 'software.syncthing.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pkg_install syncthing 2>/dev/null || {
        _soft_ensure_docker
        mkdir -p /opt/syncthing
        docker rm -f syncthing 2>/dev/null || true
        docker run -d --name=syncthing --restart=always \
            -p 8384:8384 -v /opt/syncthing:/var/syncthing \
            syncthing/syncthing:latest
    }
    pika_info "$(t 'common.done') - http://localhost:8384"
}

do_soft_filebrowser() {
    ui_confirm_install "FileBrowser" "$(t 'software.filebrowser.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') FileBrowser..."
    curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash -e 2>&1 | tail -5
    mkdir -p /opt/filebrowser
    filebrowser -d /opt/filebrowser/database.db -a 0.0.0.0 -p 8082 -r / &
    sleep 2
    pika_info "$(t 'common.done') - http://localhost:8082 (admin/admin)"
}

do_soft_searxng() {
    ui_confirm_install "SearXNG" "$(t 'software.searxng.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/searxng
    docker rm -f searxng 2>/dev/null || true
    docker run -d --name=searxng --restart=always \
        -p 8888:8080 -v /opt/searxng:/etc/searxng \
        searxng/searxng:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:8888"
}

# ─── AI 与 API ──────────────────────────────────────────────
do_soft_oneapi() {
    ui_confirm_install "One-API" "$(t 'software.oneapi.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/oneapi
    docker rm -f one-api 2>/dev/null || true
    docker run -d --name=one-api --restart=always \
        -p 3000:3000 -v /opt/oneapi:/data \
        justsong/one-api:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:3000 (admin:123456)"
}

do_soft_newapi() {
    ui_confirm_install "New-API" "$(t 'software.newapi.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/newapi
    docker rm -f new-api 2>/dev/null || true
    docker run -d --name=new-api --restart=always \
        -p 3000:3000 -v /opt/newapi:/data \
        calciumion/new-api:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:3000"
}

do_soft_cliproxyapi() {
    ui_confirm_install "CLIProxyAPI (CPA)" "$(t 'software.cliproxyapi.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/cpa
    docker rm -f cpa 2>/dev/null || true
    docker run -d --name=cpa --restart=always \
        -p 3000:3000 -v /opt/cpa:/app/data \
        -e CPA_ADMIN_USER=admin -e CPA_ADMIN_PASS=admin123 \
        ghcr.io/router-for-me/cliproxyapi:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:3000 (admin/admin123)"
}

do_soft_sub2api() {
    ui_confirm_install "Sub2API" "$(t 'software.sub2api.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/sub2api
    docker rm -f sub2api 2>/dev/null || true
    docker run -d --name=sub2api --restart=always \
        -p 3000:3000 -v /opt/sub2api:/app/data \
        -e ADMIN_USER=admin -e ADMIN_PASS=admin123 \
        ghcr.io/wei-shaw/sub2api:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:3000 (admin/admin123)"
}

# ─── 开发与自动化 ────────────────────────────────────────────
do_soft_gitea() {
    ui_confirm_install "Gitea" "$(t 'software.gitea.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/gitea
    docker rm -f gitea 2>/dev/null || true
    docker run -d --name=gitea --restart=always \
        -p 3000:3000 -p 2222:22 -v /opt/gitea:/data \
        gitea/gitea:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:3000"
}

do_soft_n8n() {
    ui_confirm_install "n8n" "$(t 'software.n8n.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/n8n
    docker rm -f n8n 2>/dev/null || true
    docker run -d --name=n8n --restart=always \
        -p 5678:5678 -v /opt/n8n:/home/node/.n8n \
        -e N8N_SECURE_COOKIE=false \
        n8nio/n8n:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:5678"
}

do_soft_nodered() {
    ui_confirm_install "Node-RED" "$(t 'software.nodered.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/nodered
    docker rm -f nodered 2>/dev/null || true
    docker run -d --name=nodered --restart=always \
        -p 1880:1880 -v /opt/nodered:/data \
        nodered/node-red:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:1880"
}

do_soft_it_tools() {
    ui_confirm_install "IT-Tools" "$(t 'software.it_tools.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    docker rm -f it-tools 2>/dev/null || true
    docker run -d --name=it-tools --restart=always \
        -p 8082:80 corentinth/it-tools:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:8082"
}

do_soft_stirlingpdf() {
    ui_confirm_install "Stirling-PDF" "$(t 'software.stirlingpdf.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    docker rm -f stirling-pdf 2>/dev/null || true
    docker run -d --name=stirling-pdf --restart=always \
        -p 8083:8080 frooodle/s-pdf:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:8083"
}

# ─── 生产力 ──────────────────────────────────────────────────
do_soft_siyuan() {
    ui_confirm_install "SiYuan 思源笔记" "$(t 'software.siyuan.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/siyuan
    docker rm -f siyuan 2>/dev/null || true
    docker run -d --name=siyuan --restart=always \
        -p 6806:6806 -v /opt/siyuan:/siyuan/workspace \
        -e SIYUAN_ACCESS_AUTH_CODE=admin \
        b3log/siyuan:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:6806 (access code: admin)"
}

do_soft_memos() {
    ui_confirm_install "Memos" "$(t 'software.memos.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/memos
    docker rm -f memos 2>/dev/null || true
    docker run -d --name=memos --restart=always \
        -p 5230:5230 -v /opt/memos:/var/opt/memos \
        neosmemo/memos:stable 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:5230"
}

do_soft_trilium() {
    ui_confirm_install "Trilium Notes" "$(t 'software.trilium.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/trilium
    docker rm -f trilium 2>/dev/null || true
    docker run -d --name=trilium --restart=always \
        -p 8084:8080 -v /opt/trilium:/home/node/trilium-data \
        zadam/trilium:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:8084"
}

do_soft_excalidraw() {
    ui_confirm_install "Excalidraw" "$(t 'software.excalidraw.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    docker rm -f excalidraw 2>/dev/null || true
    docker run -d --name=excalidraw --restart=always \
        -p 8085:80 excalidraw/excalidraw:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:8085"
}

do_soft_homebox() {
    ui_confirm_install "HomeBox" "$(t 'software.homebox.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/homebox
    docker rm -f homebox 2>/dev/null || true
    docker run -d --name=homebox --restart=always \
        -p 7745:7745 -v /opt/homebox:/data \
        ghcr.io/sysadminsmedia/homebox:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:7745"
}

do_soft_vikunja() {
    ui_confirm_install "Vikunja" "$(t 'software.vikunja.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/vikunja/files
    docker rm -f vikunja 2>/dev/null || true
    docker run -d --name=vikunja --restart=always \
        -p 3456:3456 -v /opt/vikunja/files:/app/vikunja/files \
        vikunja/vikunja:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:3456"
}

# ─── 阅读与信息 ──────────────────────────────────────────────
do_soft_miniflux() {
    ui_confirm_install "Miniflux" "$(t 'software.miniflux.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    docker rm -f miniflux 2>/dev/null || true
    docker run -d --name=miniflux --restart=always \
        -p 8088:8080 -e DATABASE_URL="postgres://miniflux:miniflux@localhost/miniflux?sslmode=disable" \
        miniflux/miniflux:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:8088 (需配置 PostgreSQL)"
}

do_soft_wallabag() {
    ui_confirm_install "Wallabag" "$(t 'software.wallabag.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/wallabag/data /opt/wallabag/images
    docker rm -f wallabag 2>/dev/null || true
    docker run -d --name=wallabag --restart=always \
        -p 8866:80 -v /opt/wallabag/data:/var/www/wallabag/data \
        -v /opt/wallabag/images:/var/www/wallabag/web/assets/images \
        -e SYMFONY__ENV__DOMAIN_NAME=http://localhost:8866 \
        wallabag/wallabag:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:8866 (wallabag/wallabag)"
}

do_soft_changedetection() {
    ui_confirm_install "Changedetection" "$(t 'software.changedetection.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/changedetection
    docker rm -f changedetection 2>/dev/null || true
    docker run -d --name=changedetection --restart=always \
        -p 5000:5000 -v /opt/changedetection:/datastore \
        dgtlmoon/changedetection.io:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:5000"
}

# ─── 消息推送 ────────────────────────────────────────────────
do_soft_bark() {
    ui_confirm_install "Bark Server" "$(t 'software.bark.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/bark
    docker rm -f bark 2>/dev/null || true
    docker run -d --name=bark --restart=always \
        -p 8089:8080 -v /opt/bark:/data \
        finb/bark-server:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:8089 (iOS 客户端推送)"
}

# ─── 监控 ────────────────────────────────────────────────────
do_soft_uptimekuma() {
    ui_confirm_install "Uptime Kuma" "$(t 'software.uptimekuma.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/uptime-kuma
    docker rm -f uptime-kuma 2>/dev/null || true
    docker run -d --name=uptime-kuma --restart=always \
        -p 3001:3001 -v /opt/uptime-kuma:/app/data \
        louislam/uptime-kuma:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:3001"
}

do_soft_speedtest() {
    ui_confirm_install "Speedtest-Tracker" "$(t 'software.speedtest.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    _soft_ensure_docker
    mkdir -p /opt/speedtest
    docker rm -f speedtest 2>/dev/null || true
    docker run -d --name=speedtest --restart=always \
        -p 8086:80 -v /opt/speedtest:/config \
        henrywhitaker3/speedtest-tracker:latest 2>&1 | tail -3
    pika_info "$(t 'common.done') - http://localhost:8086"
}

do_soft_mcsmanager() {
    ui_confirm_install "MCSManager" "$(t 'software.mcsmanager.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') MCSManager..."
    curl -sSL https://script.mcsmanager.com/setup.sh 2>/dev/null | bash -e 2>&1 | tail -5
    pika_info "$(t 'common.done') - http://localhost:23333"
}
