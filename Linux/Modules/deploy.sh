#!/usr/bin/env bash
# ============================================================
#  PIKA SH - Deploy Module
#  Menu + handlers for deployment and installation.
#  Requires: core libs (00-core, 10-net, 20-pkg, 30-svc, 40-ui, 50-i18n)
# ============================================================
set -e

# ---- Menu data ----
DeployMENU=(
    "mirror|deploy.mirror|deploy.mirror.desc|do_mirror"
    "docker|deploy.docker|deploy.docker.desc|do_docker"
    "podman|deploy.podman|deploy.podman.desc|do_podman"
    "panel_1panel|deploy.panel.1panel|deploy.panel.1panel.desc|do_1panel"
    "panel_bt|deploy.panel.bt|deploy.panel.bt.desc|do_btpanel"
    "panel_nezha|deploy.panel.nezha|deploy.panel.nezha.desc|do_nezha"
    "node|deploy.node|deploy.node.desc|do_node"
)

# ---- Handlers ----
do_mirror() {
    pika_info "$(t 'state.installing') $(t 'deploy.mirror')"
    case "$PIKA_DISTRO" in
        debian|ubuntu)
            local distro_ver="$PIKA_DISTRO_VER"
            if command -v python3 >/dev/null 2>&1; then
                curl -fsSL "https://gh-bat.pika.net.cn/Linux/VPSSets/Setup.sh" | bash -e -s mirror
            else
                # Ubuntu 24.04+ uses deb822 format
                if [ "$PIKA_DISTRO" = "ubuntu" ] && [ "${distro_ver%%.*}" -ge 24 ] 2>/dev/null; then
                    sed -i 's|http://.*archive.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null || true
                else
                    sed -i 's|http://.*debian.org|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list 2>/dev/null || true
                    sed -i 's|http://.*archive.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list 2>/dev/null || true
                fi
            fi
            pkg_update_once
            pika_info "$(t 'common.done') - $(t 'deploy.mirror')"
            ;;
        centos|rhel|fedora|rocky|almalinux)
            curl -fsSL "https://gh-bat.pika.net.cn/Linux/VPSSets/Setup.sh" | bash -e -s mirror
            ;;
        *)
            pika_warn "$(t 'pkg.nosupport')"
            ;;
    esac
}

do_docker() {
    ui_confirm_install "Docker" "$(t 'deploy.docker.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') Docker..."
    curl -fsSL https://get.docker.com | bash -e
    # Add China registry mirror
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << 'EOF'
{
  "registry-mirrors": ["https://docker.1ms.run", "https://docker.xuanyuan.me"]
}
EOF
    systemctl restart docker 2>/dev/null || service docker restart 2>/dev/null || true
    pika_info "$(t 'common.done') - Docker"
}

do_podman() {
    ui_confirm_install "Podman" "$(t 'deploy.podman.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pkg_install podman
    pika_info "$(t 'common.done') - Podman"
}

do_1panel() {
    ui_confirm_install "1Panel" "$(t 'deploy.panel.1panel.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') 1Panel..."
    curl -fsSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o /tmp/1panel.sh
    bash /tmp/1panel.sh
    rm -f /tmp/1panel.sh
}

do_btpanel() {
    ui_confirm_install "$(t 'deploy.panel.bt')" "$(t 'deploy.panel.bt.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') BT Panel..."
    local bt_url=$(gh_url "https://download.bt.cn/install/install_panel.sh")
    if [ -n "$bt_url" ]; then
        curl -fsSL "$bt_url" | bash -e
    else
        curl -fsSL https://download.bt.cn/install/install_panel.sh | bash -e
    fi
}

do_nezha() {
    ui_confirm_install "Nezha Monitor" "$(t 'deploy.panel.nezha.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    local install_url=$(gh_url "https://raw.githubusercontent.com/nezhahq/nezha/master/script/install.sh")
    curl -fsSL "$install_url" | bash -e
}

do_node() {
    ui_confirm_install "Node.js + PM2" "$(t 'deploy.node.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    ensure_node_pm2
    pika_info "$(t 'common.done') - Node.js $(node --version 2>/dev/null || echo '?') + PM2 $(pm2 -v 2>/dev/null || echo '?')"
}
