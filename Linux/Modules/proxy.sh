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

_run_proxy_installer() {
    local name="$1" url="$2"; shift 2
    ui_confirm_install "$name" "$(t "proxy.${3:-}.desc")" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') $name..."
    local proxy_url; proxy_url=$(gh_url "$url")
    curl -fsSL "$proxy_url" | bash -e "$@"
    pika_info "$(t 'common.done') - $name"
}

do_proxy_xui() {
    ui_confirm_install "3X-UI" "$(t 'proxy.xui.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') 3X-UI..."
    # Remove existing installations to avoid conflicts
    rm -rf /usr/local/x-ui 2>/dev/null || true
    local url=$(gh_url "https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh")
    curl -fsSL "$url" | bash -e
    pika_info "$(t 'common.done') - 3X-UI"
}

do_proxy_clash() {
    local url=$(gh_url "https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/Tunnels/clash/install.sh")
    curl -fsSL "$url" | bash -e
}

do_proxy_hysteria2() {
    local url=$(gh_url "https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/Tunnels/hysteria2/install.sh")
    curl -fsSL "$url" | bash -e
}

do_proxy_ssrust() {
    local url=$(gh_url "https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/Tunnels/ss-rust/install.sh")
    curl -fsSL "$url" | bash -e
}

do_proxy_trojango() {
    local url=$(gh_url "https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/Tunnels/trojan-go/install.sh")
    curl -fsSL "$url" | bash -e
}

do_proxy_warp() {
    local url=$(gh_url "https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/Tunnels/warp/install.sh")
    curl -fsSL "$url" | bash -e
}

do_proxy_wireguard() {
    pkg_install wireguard-tools
    pika_info "WireGuard installed. Configure with: wg-quick up <config>"
}

do_proxy_wgeasy() {
    ui_confirm_install "wg-easy" "$(t 'proxy.wgeasy.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    local port wgport pass
    read -r -p "$(t 'proxy.wgeasy.port') [51821]: " port; port="${port:-51821}"
    read -r -p "$(t 'proxy.wgeasy.wgport') [51820]: " wgport; wgport="${wgport:-51820}"
    read -r -sp "$(t 'proxy.wgeasy.pass'): " pass; echo ""
    [ -z "$pass" ] && { pika_err "$(t 'proxy.wgeasy.nopass')"; return; }

    pika_info "$(t 'state.installing') wg-easy..."
    docker stop wg-easy 2>/dev/null || true; docker rm wg-easy 2>/dev/null || true
    local pass_hash; pass_hash=$(docker run --rm ghcr.io/wg-easy/wg-easy wgpw "$pass" 2>/dev/null || echo "$pass")
    docker run -d \
        --name=wg-easy \
        -e WG_HOST="$(curl -s ifconfig.me 2>/dev/null || curl -s ip.sb 2>/dev/null || echo 'YOUR_SERVER_IP')" \
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
            -e WG_HOST="$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')" \
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
    curl -fsSL https://install.zerotier.com | bash -e
    pika_info "$(t 'common.done') - ZeroTier"
}

do_proxy_tailscale() {
    ui_confirm_install "Tailscale" "$(t 'proxy.tailscale.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | bash -e
    pika_info "$(t 'common.done') - Tailscale"
}
