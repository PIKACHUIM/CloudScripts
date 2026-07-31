#!/usr/bin/env bash
# ============================================================
#  PIKA SH - Desktop Module
#  Menu + handlers for desktop environment installation.
#  Delegates to Linux/Desktop/*.sh scripts.
# ============================================================
set -e

# ---- Flag value table (central registry - prevents conflicts) ----
# Server=0, Graphy=9, Deepin=1, Plasma=2, Lingmo=3, Xfce4=4, Niri=5, GNOME=6, MATE=7, Hyprland=8

DesktopMENU=(
    "server|desktop.server|desktop.server.desc|do_desktop_server"
    "graphy|desktop.graphy|desktop.graphy.desc|do_desktop_graphy"
    "xfce4|desktop.xfce4|desktop.xfce4.desc|do_desktop_xfce4"
    "gnome3|desktop.gnome3|desktop.gnome3.desc|do_desktop_gnome3"
    "plasma|desktop.plasma|desktop.plasma.desc|do_desktop_plasma"
    "mate|desktop.mate|desktop.mate.desc|do_desktop_mate"
    "deepin|desktop.deepin|desktop.deepin.desc|do_desktop_deepin"
    "lingmo|desktop.lingmo|desktop.lingmo.desc|do_desktop_lingmo"
    "hyprland|desktop.hyprland|desktop.hyprland.desc|do_desktop_hyprland"
    "niri|desktop.niri|desktop.niri.desc|do_desktop_niri"
)

PIKA_DESKTOP_CDN="${PIKA_MIRROR_BASE:-https://pikash.opkg.cn}/Linux/Desktop"

# ---- Generic desktop installer: fetch and run remote script ----
_de_install() {
    local name="$1" script="$2" flag="$3" icon="$4"

    ui_confirm_install "$name" "$(t "desktop.${icon:-server}.desc")" || { pika_info "$(t 'ui.cancelled')"; return; }

    pika_info "$(t 'desk.checking')"
    # Download and execute via the dispatch function in commons.sh
    local _tmp_script="/tmp/pika_de_$$.sh"
    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL "${PIKA_DESKTOP_CDN}/${script}" -o "$_tmp_script"; then
            chmod +x "$_tmp_script"
            if bash -e "$_tmp_script"; then
                rm -f "$_tmp_script"
                pika_info "$(t 'common.done') - $name"
            else
                rm -f "$_tmp_script"
                pika_err "$(t 'common.error'): $name"
            fi
        else
            pika_err "$(t 'common.error'): $name (download failed)"
        fi
    else
        if wget -qO "$_tmp_script" "${PIKA_DESKTOP_CDN}/${script}"; then
            chmod +x "$_tmp_script"
            if bash -e "$_tmp_script"; then
                rm -f "$_tmp_script"
                pika_info "$(t 'common.done') - $name"
            else
                rm -f "$_tmp_script"
                pika_err "$(t 'common.error'): $name"
            fi
        else
            pika_err "$(t 'common.error'): $name (download failed)"
        fi
    fi
}

# ---- Handlers ----
do_desktop_server()  { _de_install "Server Base"    "LXC-Debian-Server.sh"  "0" "server"; }
do_desktop_graphy()  { _de_install "X11 Graphics"   "LXC-Debian-Graphy.sh"  "9" "graphy"; }
do_desktop_xfce4()   { _de_install "Xfce4"          "LXC-Debian-Xfce4L.sh"  "4" "xfce4"; }
do_desktop_gnome3()  { _de_install "GNOME 3"        "LXC-Debian-Gnome3.sh"  "6" "gnome3"; }
do_desktop_plasma()  { _de_install "KDE Plasma"     "LXC-Debian-Plasma.sh"  "2" "plasma"; }
do_desktop_mate()    { _de_install "MATE"           "LXC-Debian-MateDE.sh"  "7" "mate"; }
do_desktop_deepin()  { _de_install "Deepin/GXDE"    "LXC-Debian-Deepin.sh"  "1" "deepin"; }
do_desktop_lingmo()  { _de_install "Lingmo"         "LXC-Debian-Lingmo.sh"  "3" "lingmo"; }
do_desktop_hyprland(){ _de_install "Hyprland"       "LXC-Debian-Hyprland.sh" "8" "hyprland"; }
do_desktop_niri()    { _de_install "Niri"           "LXC-Debian-Niri.sh"    "5" "niri"; }
