#!/usr/bin/env bash
. /g/Codes/PikaProjects/CloudScripts/Linux/Lib/00-core.sh
. /g/Codes/PikaProjects/CloudScripts/Linux/Lib/40-ui.sh

echo "width of '部署安装'  : $(_ui_str_width '部署安装')  (expected 8)"
echo "width of 'Hello'    : $(_ui_str_width 'Hello')  (expected 5)"
echo "width of '部署'      : $(_ui_str_width '部署')  (expected 4)"
echo "width of '面板、容器、工具一键部署' : $(_ui_str_width '面板、容器、工具一键部署')  (expected 26)"
echo "width of '内核、BBR、防火墙、清理' : $(_ui_str_width '内核、BBR、防火墙、清理')  (expected 19)"
