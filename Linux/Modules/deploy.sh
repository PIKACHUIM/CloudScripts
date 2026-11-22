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
    "panel_netpanel|deploy.panel.netpanel|deploy.panel.netpanel.desc|do_netpanel"
    "node|deploy.node|deploy.node.desc|do_node"
)

# ---- Handlers ----
do_mirror() {
    pika_info "$(t 'state.installing') $(t 'deploy.mirror')"
    case "$PIKA_DISTRO" in
        debian|ubuntu|devuan|kali|deepin|uos|alpine|rocky|almalinux|centos|fedora)
            if pika_pkg_mirror_cn; then
                pika_info "$(t 'common.done') - $(t 'deploy.mirror')"
            else
                pika_warn "$(t 'deploy.mirror.failed')"
            fi
            ;;
        rhel)
            pika_warn "$(t 'deploy.mirror.failed')"
            ;;
        *)
            pika_warn "$(t 'pkg.nosupport')"
            ;;
    esac
}

do_docker() {
    ui_confirm_install "Docker" "$(t 'deploy.docker.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') Docker..."
    pika_install_docker || return 1
    pika_info "$(t 'common.done') - Docker $(docker --version 2>/dev/null | sed 's/^Docker version //;s/,.*//')"
}

do_podman() {
    ui_confirm_install "Podman" "$(t 'deploy.podman.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pkg_install podman
    pika_info "$(t 'common.done') - Podman"
}

do_1panel() {
    ui_confirm_install "1Panel" "$(t 'deploy.panel.1panel.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') 1Panel..."
    pika_run_remote --errexit "https://resource.fit2cloud.com/1panel/package/quick_start.sh"
}

do_btpanel() {
    ui_confirm_install "$(t 'deploy.panel.bt')" "$(t 'deploy.panel.bt.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') BT Panel..."
    pika_run_remote --errexit "https://download.bt.cn/install/install_panel.sh"
}

do_nezha() {
    ui_confirm_install "Nezha Monitor" "$(t 'deploy.panel.nezha.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_run_remote --errexit "https://raw.githubusercontent.com/nezhahq/nezha/master/script/install.sh"
}

do_node() {
    ui_confirm_install "Node.js + PM2" "$(t 'deploy.node.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    ensure_node_pm2
    pika_info "$(t 'common.done') - Node.js $(node --version 2>/dev/null || echo '?') + PM2 $(pm2 -v 2>/dev/null || echo '?')"
}

do_netpanel() {
    ui_confirm_install "NetPanel" "$(t 'deploy.panel.netpanel.desc')" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_info "$(t 'state.installing') NetPanel..."
    pkg_install curl wget
    pika_run_remote --errexit "https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/Tunnels/netpanel/install.sh"
}
