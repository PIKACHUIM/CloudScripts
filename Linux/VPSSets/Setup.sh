#!/bin/bash
# ============================================================
# 敏感信息已使用 AES-256-CBC + PBKDF2 加密存储（BASE64）
# 运行前需输入正确密码，密码错误将退出
# 如需重新生成加密值，请运行同目录下的 Vault.sh
# ============================================================

# 验证密码
echo -n "请输入部署密码: "
read -s _PASS
echo
_dec() { echo "$1" | openssl enc -aes-256-cbc -pbkdf2 -d -a -pass pass:"${_PASS}" 2>/dev/null; }

# ---- 加密的敏感信息（使用 Vault.sh 生成） ----
ENC_PROXY_AUTH=U2FsdGVkX19nQItQVnIlhqIDn7QBNXcEEVmmzKrw75c=
ENC_PROXY_HOST=U2FsdGVkX18liVs/yQuAVy8jX4CkvyrrezcCIBk+tu56uX5OvFrMpCwSOBo93vaE
ENC_PROXY_PORT=U2FsdGVkX1/wt/E/YrrhMrxpRXJqaGbTJcnTutFoV9Q=
ENC_NZ_SERVER=U2FsdGVkX1++Diwgc0zDxWgmZiXFVce1dJbKPWWk1OlNYMIcijWvBOX20QGNd2y4
ENC_NZ_SECRET=U2FsdGVkX1+DK04DIWFSdtt5eMhdj6sGzxkVYIHpi+Ce6JH66hGsxefEZXd4ZMkQgrRvapMgRBbvIdNE4WbV6g==
ENC_ET_CONFIG=U2FsdGVkX18l+6Zvp8NZnEdwc5PrHNHXCGu+dNozGtoQgfed79x+GrnXS3fVLHMH8dszQsi4goh2lEXVlTMJ+A==
ENC_FRP_API=U2FsdGVkX1/Zs4A6aCNDCZKnJQxAn6uVtRIcDEXQt9rXxJBiZqrAb28SWHoidBux
ENC_FRP_RPC=U2FsdGVkX197mHbNRp8pvPrqhRgtCtHd50+IwctOQFm+Dh8CQHoiQIouYZKYog9y
ENC_BT_PSA=U2FsdGVkX18eTiR3FA15eObj37N1NRvi6XD5Zr6VcCo=
ENC_BT_USER=U2FsdGVkX1+tDXq2/0OGpeOeZxoK9JQRZ9YEpwsy5PI=

# 验证密码（解密ET配置作为校验）
_TEST=$(_dec "$ENC_ET_CONFIG")
if [ -z "$_TEST" ]; then
    echo "密码错误，退出！"
    exit 1
fi

# 解密所有敏感变量
PROXY_AUTH=$(_dec "$ENC_PROXY_AUTH")
PROXY_HOST=$(_dec "$ENC_PROXY_HOST")
PROXY_PORT=$(_dec "$ENC_PROXY_PORT")
NZ_SERVER=$(_dec "$ENC_NZ_SERVER")
NZ_SECRET=$(_dec "$ENC_NZ_SECRET")
ET_CONFIG=$(_dec "$ENC_ET_CONFIG")
FRP_API=$(_dec "$ENC_FRP_API")
FRP_RPC=$(_dec "$ENC_FRP_RPC")
BT_PSA=$(_dec "$ENC_BT_PSA")
BT_USER=$(_dec "$ENC_BT_USER")

GH_URL="https://ghfast.top/https://raw.githubusercontent.com"
GH_WEB="https://ghfast.top/https://github.com"
GH_API="https://ghproxy.vip/https://api.github.com/"

# 设置主机名 ========================================================
echo "请输入新的主机名:"
read HS_DAT
hostnamectl set-hostname ${HS_DAT}
echo "127.0.0.1 ${HS_DAT}" >> /etc/hosts

# 系统初始安装 ======================================================
apt update&& apt upgrade -y && apt install -y curl wget nano sudo vim

# 安装NodeJS24 ======================================================
NJ_URL="${GH_URL}/nvm-sh/nvm/v0.40.3/install.sh"
curl -o- ${NJ_URL} | bash && source ~/.bashrc
\. "$HOME/.nvm/nvm.sh" && nvm install 24 && node -v && npm -v

# 安装附加环境 ======================================================
apt install -y unzip htop git openssl proxychains&&npm install pm2 -g

# 安装代理工具 ======================================================
echo -n "是否使用ProxyChains? (y/n): "
read PROXYS_USAGES
if [ "$PROXYS_USAGES" = "y" ]; then
    IP_ADDR=$(getent hosts ${PROXY_HOST} | awk '{print $1}')
	PC_COMM="proxychains"
	echo socks5 ${IP_ADDR} ${PROXY_PORT} ${PROXY_AUTH}
fi

# 安装宝塔面板 ======================================================
echo -n "是否安装宝塔面板? (y/n): "
read INSTALL_BAOTA
if [ "$INSTALL_BAOTA" = "y" ]; then
    BT_URL="https://download.bt.cn/install/install_panel.sh"
    wget -O install_panel.sh ${BT_URL}
	echo -e "y\n" | bash install_panel.sh ed8484bec
	echo -e "bt\n26\n" | bash 
	echo -e "bt\n6\n${BT_USER}\n" | bash 
	echo -e "bt\n8\n1888\n" | bash 
	echo "宝塔面板密码: ${BT_PSA}"
	echo -e "bt\n5\n${BT_PSA}\n" | bash 
	rm -f /www/server/panel/data/admin_path.pl
	echo -e "bt\n14\n" | bash 
fi

# 安装哪吒面板 ======================================================
echo -n "是否安装哪吒面板? (y/n): "
read INSTALL_NEZHA
if [ "$INSTALL_NEZHA" = "y" ]; then
    NZ_URL="${GH_URL}/nezhahq/scripts/main/agent/install.sh"
    ${PC_COMM} curl -L ${NZ_URL} -o agent.sh && chmod +x agent.sh 
    env NZ_SERVER=${NZ_SERVER} \
        NZ_TLS=true \
	    NZ_CLIENT_SECRET=${NZ_SECRET} \
	    ${PC_COMM} ./agent.sh
fi

# 安装3XUI面板 ======================================================
echo -n "是否安装3XUI面板? (y/n): "
read INSTALL_3XUI
if [ "$INSTALL_3XUI" = "y" ]; then
	mkdir -p /etc/xui
	# 生成自签名证书
	openssl req -x509 -newkey rsa:2048 \
	            -keyout /etc/xui/key.pem \
				-out /etc/xui/crt.pem \
				-days 365 -nodes -subj "/CN=${HS_DAT}"
    # 下载脚本到tmp目录
    TMP_SCRIPT="/tmp/3x-ui-install.sh"
    ${PC_COMM} curl -Ls "${GH_URL}/mhsanaei/3x-ui/master/install.sh" -o "${TMP_SCRIPT}"
    chmod +x "${TMP_SCRIPT}"
    # 用sed修改脚本内的GitHub链接
    # 将raw.githubusercontent.com替换为GH_URL
    sed -i "s|https://raw.githubusercontent.com|${GH_URL}|g" "${TMP_SCRIPT}"
    # 将github.com替换为GH_WEB
    sed -i "s|https://github.com|${GH_WEB}|g" "${TMP_SCRIPT}"
    # 运行修改后的脚本，自动传入参数
    echo -e "y\n1090\n3\n/etc/xui/crt.pem\n/etc/xui/key.pem\n" | ${PC_COMM} bash "${TMP_SCRIPT}"
fi

# 安装ET服务 ========================================================
echo -n "是否安装ET服务? (y/n): "
read INSTALL_ET
if [ "$INSTALL_ET" = "y" ]; then
    # 自动从GitHub读取最新的tag
    ET_TAG=$(${PC_COMM} curl -s --connect-timeout 10 --max-time 15 "" | grep '"tag_name"' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
	echo "获取到最新的ET版本: ${ET_TAG}"
    ET_URL="${GH_WEB}/EasyTier/EasyTier/releases/download/${ET_TAG}/easytier-linux-x86_64-${ET_TAG}.zip"
    echo "尝试下载ET文件..."
    ${PC_COMM} wget -O easytier-linux-x86_64.zip ${ET_URL}

    # 解压ZIP文件
    if [ -f "easytier-linux-x86_64.zip" ]; then
        unzip -o easytier-linux-x86_64.zip
        # 设置执行权限
        chmod -R +x easytier-linux-x86_64
        # 移动到/bin目录下
        mv easytier-linux-x86_64/* /bin/
        # 清理临时文件
        rm -f easytier-linux-x86_64.zip 
        rm -rf easytier-linux-x86_64
        pm2 start /bin/easytier-core --name easytier -- --config-server ${ET_CONFIG}
        pm2 save
        echo "ET服务安装完成，已安装到/bin/easytier"
    else
        echo "ET安装失败，文件下载不成功"
    fi
fi

# 安装FRPS服务器 ====================================================
echo -n "是否设置FRPS服务器? (y/n): "
read INSTALL_FRPS
if [ "$INSTALL_FRPS" = "y" ]; then
    # 通过GitHub API获取最新frp-panel版本
    FRP_TAG=$(${PC_COMM} curl -s --connect-timeout 10 --max-time 15 "${GH_API}repos/VaalaCat/frp-panel/releases/latest" | grep '"tag_name"' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
    echo "获取到最新的frp-panel版本: ${FRP_TAG}"
    FRP_URL="${GH_WEB}/VaalaCat/frp-panel/releases/download/${FRP_TAG}/frp-panel-linux-amd64"
    echo "尝试下载frp-panel..."
    ${PC_COMM} wget -O /bin/frp-panel ${FRP_URL}
    chmod +x /bin/frp-panel

    echo "请输入服务器名称(NN_FRP):"
    read NN_FRP
    echo "请输入节点UUID(TK_FRP):"
    read TK_FRP
    pm2 start /bin/frp-panel --name frps -- server -s ${TK_FRP} -i ${NN_FRP} \
              --api-url ${FRP_API} \
	          --rpc-url ${FRP_RPC}
	pm2 save
fi