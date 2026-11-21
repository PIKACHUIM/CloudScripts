#!/usr/bin/env bash
# ============================================================
#  PIKA SH - Proxy / VPN Module
#  Menu + handlers for proxy, VPN, and tunneling services.
# ============================================================
set -e

ProxyMENU=(
    "xui|proxy.xui|proxy.xui.desc|do_proxy_xui"
    "clash|proxy.clash|proxy.clash.desc|do_proxy_clash"
    "hysteria2|proxy.hysteria2|proxy.hysteria2.desc|do_proxy_hysteria2"
    "ssrust|proxy.ssrust|proxy.ssrust.desc|do_proxy_ssrust"
    "trojango|proxy.trojango|proxy.trojango.desc|do_proxy_trojango"
    "warp|proxy.warp|proxy.warp.desc|do_proxy_warp"
    "wireguard|proxy.wireguard|proxy.wireguard.desc|do_proxy_wireguard"
    "wgeasy|proxy.wgeasy|proxy.wgeasy.desc|do_proxy_wgeasy"
    "zerotier|proxy.zerotier|proxy.zerotier.desc|do_proxy_zerotier"
    "tailscale|proxy.tailscale|proxy.tailscale.desc|do_proxy_tailscale"
)

do_proxy_xui() {
    ui_confirm_install "3X-UI" "$(t 'proxy.xui.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') 3X-UI..."
    # Remove existing installations to avoid conflicts
    rm -rf /usr/local/x-ui 2>/dev/null || true
    # Repo copy is patched to honour PIKA_GH_PREFIX for GitHub downloads.
    PIKA_GH_PREFIX="$(pika_gh_prefix)"
    export PIKA_GH_PREFIX
    if ! pika_run_remote --errexit "Linux/Tunnels/3x-ui/install.sh"; then
        pika_err "$(t 'common.error'): 3X-UI"
        unset PIKA_GH_PREFIX
        return 0
    fi
    unset PIKA_GH_PREFIX
    pika_info "$(t 'common.done') - 3X-UI"
}

do_proxy_clash() {
    ui_confirm_install "Clash for Linux" "$(t 'proxy.clash.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_run_remote --errexit "https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/Tunnels/clash/install.sh"
    pika_info "$(t 'common.done') - Clash"
}

do_proxy_hysteria2() {
    ui_confirm_install "Hysteria2" "$(t 'proxy.hysteria2.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_run_remote --errexit "https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/Tunnels/hysteria2/install.sh"
    pika_info "$(t 'common.done') - Hysteria2"
}

do_proxy_ssrust() {
    ui_confirm_install "Shadowsocks-rust" "$(t 'proxy.ssrust.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_run_remote --errexit "https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/Tunnels/ss-rust/install.sh"
    pika_info "$(t 'common.done') - Shadowsocks-rust"
}

do_proxy_trojango() {
    ui_confirm_install "Trojan-Go" "$(t 'proxy.trojango.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_run_remote --errexit "https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/Tunnels/trojan-go/install.sh"
    pika_info "$(t 'common.done') - Trojan-Go"
}

do_proxy_warp() {
    ui_confirm_install "Cloudflare WARP" "$(t 'proxy.warp.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_run_remote --errexit "https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/Tunnels/warp/install.sh"
    pika_info "$(t 'common.done') - WARP"
}

do_proxy_wireguard() {
    pkg_install wireguard-tools
    pika_info "WireGuard installed. Configure with: wg-quick up <config>"
}

do_proxy_wgeasy() {
    command -v docker >/dev/null 2>&1 || { pika_err "Docker 未安装，请先执行 部署安装 > 安装 Docker"; return 1; }
    ui_confirm_install "wg-easy" "$(t 'proxy.wgeasy.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    local port wgport pass
    read -r -p "$(t 'proxy.wgeasy.port') [51821]: " port; port="${port:-51821}"
    read -r -p "$(t 'proxy.wgeasy.wgport') [51820]: " wgport; wgport="${wgport:-51820}"
    read -r -sp "$(t 'proxy.wgeasy.pass'): " pass; echo ""
    [ -z "$pass" ] && { pika_err "$(t 'proxy.wgeasy.nopass')"; return; }

    pika_info "$(t 'state.installing') wg-easy..."
    docker stop wg-easy 2>/dev/null || true; docker rm wg-easy 2>/dev/null || true
    pika_docker_pull "ghcr.io/wg-easy/wg-easy" >/dev/null 2>&1 || true
    local pass_hash; pass_hash=$(docker run --rm ghcr.io/wg-easy/wg-easy wgpw "$pass" 2>/dev/null || echo "$pass")
    docker run -d \
        --name=wg-easy \
        -e WG_HOST="$(curl -s --connect-timeout 3 --max-time 6 ifconfig.me 2>/dev/null || curl -s --connect-timeout 3 --max-time 6 ip.sb 2>/dev/null || echo 'YOUR_SERVER_IP')" \
        -e PASSWORD_HASH="$pass_hash" \
        -e WG_PORT="$wgport" \
        -p "$port:51821" \
        -p "$wgport:51820/udp" \
        -v /etc/wireguard:/etc/wireguard \
        --restart=unless-stopped \
        --cap-add=NET_ADMIN --cap-add=SYS_MODULE \
        --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
        --sysctl="net.ipv4.ip_forward=1" \
        wg-easy/wg-easy 2>/dev/null || \
        docker run -d --name=wg-easy \
            -e WG_HOST="$(curl -s --connect-timeout 3 --max-time 6 ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')" \
            -e PASSWORD="$pass" \
            -p "$port:51821" -p "$wgport:51820/udp" \
            -v /etc/wireguard:/etc/wireguard \
            --cap-add=NET_ADMIN --cap-add=SYS_MODULE \
            --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
            wg-easy/wg-easy

    pika_info "$(t 'common.done')"
    echo "  $(t 'proxy.wgeasy.panel'): http://SERVER_IP:$port"
    echo "  $(t 'proxy.wgeasy.password'): $pass"
}

do_proxy_zerotier() {
    ui_confirm_install "ZeroTier" "$(t 'proxy.zerotier.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') ZeroTier..."
    pika_run_remote --errexit "https://install.zerotier.com"
    pika_info "$(t 'common.done') - ZeroTier"
}

do_proxy_tailscale() {
    ui_confirm_install "Tailscale" "$(t 'proxy.tailscale.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') Tailscale..."
    pika_run_remote --errexit "https://tailscale.com/install.sh"
    pika_info "$(t 'common.done') - Tailscale"
}
