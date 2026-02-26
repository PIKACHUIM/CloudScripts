#!/bin/bash
# ============================================================
# Vault.sh - 生成 Setup.sh 所需的加密值
# 使用方法: bash Vault.sh
# 运行后会自动将加密值写入同目录的 Setup.sh
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SETUP_FILE="${SCRIPT_DIR}/Setup.sh"

read -rsp "请输入加密密码: " PASS; echo
read -rsp "请再次确认密码: " PASS2; echo
if [ "$PASS" != "$PASS2" ]; then
    echo "两次密码不一致，退出"
    exit 1
fi

_enc() { echo -n "$1" | openssl enc -aes-256-cbc -pbkdf2 -pass pass:"${PASS}" -a -A; }

echo ""
read -rp "PROXY_AUTH (代理认证): " V_PROXY_AUTH
read -rp "PROXY_HOST (代理主机): " V_PROXY_HOST
read -rp "PROXY_PORT (代理端口): " V_PROXY_PORT
read -rp "NZ_SERVER  (哪吒服务): " V_NZ_SERVER
read -rsp "NZ_SECRET (哪吒密钥): " V_NZ_SECRET; echo
read -rp "ET_CONFIG  (ET服务器): " V_ET_CONFIG
read -rp "FRP_API    (FRPs API): " V_FRP_API
read -rp "FRP_RPC    (FRPs RPC): " V_FRP_RPC
read -rp  "BT_USER   (宝塔用户): " V_BT_USER
read -rsp "BT_PSA    (宝塔密码): " V_BT_PSA; echo


echo "正在生成加密值..."

ENC_PROXY_AUTH=$(_enc "$V_PROXY_AUTH")
ENC_PROXY_HOST=$(_enc "$V_PROXY_HOST")
ENC_PROXY_PORT=$(_enc "$V_PROXY_PORT")
ENC_NZ_SERVER=$(_enc "$V_NZ_SERVER")
ENC_NZ_SECRET=$(_enc "$V_NZ_SECRET")
ENC_ET_CONFIG=$(_enc "$V_ET_CONFIG")
ENC_FRP_API=$(_enc "$V_FRP_API")
ENC_FRP_RPC=$(_enc "$V_FRP_RPC")
ENC_BT_USER=$(_enc "$V_BT_USER")
ENC_BT_PSA=$(_enc "$V_BT_PSA")


echo "加密值生成完成："
echo ""
echo "ENC_PROXY_AUTH=${ENC_PROXY_AUTH}"
echo "ENC_PROXY_HOST=${ENC_PROXY_HOST}"
echo "ENC_PROXY_PORT=${ENC_PROXY_PORT}"
echo "ENC_NZ_SERVER=${ENC_NZ_SERVER}"
echo "ENC_NZ_SECRET=${ENC_NZ_SECRET}"
echo "ENC_ET_CONFIG=${ENC_ET_CONFIG}"
echo "ENC_FRP_API=${ENC_FRP_API}"
echo "ENC_FRP_RPC=${ENC_FRP_RPC}"
echo "ENC_BT_PSA=${ENC_BT_PSA}"
echo "ENC_BT_USER=${ENC_BT_USER}"
