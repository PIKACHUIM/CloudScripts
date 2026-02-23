GH_URL="https://ghfast.top/https://raw.githubusercontent.com"
GH_WEB="https://ghfast.top/https://github.com"
GH_API="https://ghfast.top/https://api.github.com"
# 设置主机名 ========================================================
echo "请输入新的主机名:"
read HS_DAT
hostnamectl set-hostname ${HS_DAT}
echo "127.0.0.1 ${HS_DAT}" >> /etc/hosts

# 系统初始安装 ======================================================
apt update && apt upgrade -y && apt install -y curl wget nano sudo 

# 安装NodeJS24 ======================================================
NJ_URL="${GH_URL}/nvm-sh/nvm/v0.40.3/install.sh"
curl -o- ${NJ_URL} | bash && source ~/.bashrc
\. "$HOME/.nvm/nvm.sh" && nvm install 24 && node -v && npm -v

# 安装附加环境 ======================================================
apt install -y unzip vim htop git openssl && npm install pm2 -g

# 安装宝塔面板 =====================================================
echo "是否安装宝塔面板? (y/n)"
read INSTALL_BAOTA
if [ "$INSTALL_BAOTA" = "y" ]; then
    BT_URL="https://download.bt.cn/install/install_panel.sh"
    wget -O install_panel.sh ${BT_URL}
	echo "y\n" | bash install_panel.sh ed8484bec
	echo -e "bt\n26\n" | bash 
	echo -e "bt\n6\npika\n" | bash 
	echo -e "bt\n8\n1888\n" | bash 
	BT_PSA=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 8)
	echo "宝塔面板密码: ${BT_PSA}"
	echo -e "bt\n5\n${BT_PSA}\n" | bash 
	rm -f /www/server/panel/data/admin_path.pl
	echo -e "bt\n14\n" | bash 
fi

# 安装哪吒面板 ======================================================
echo "是否安装哪吒面板? (y/n)"
read INSTALL_NEZHA
if [ "$INSTALL_NEZHA" = "y" ]; then
    NZ_URL="${GH_URL}/nezhahq/scripts/main/agent/install.sh"
    curl -L ${NZ_URL} -o agent.sh && chmod +x agent.sh 
    env NZ_SERVER=panels.524228.xyz:443 \
        NZ_TLS=true \
	    NZ_CLIENT_SECRET=gMnSKEtR0B5xkBJUfWMqSMBRSBnkeZ0C \
	    ./agent.sh
fi

# 安装3XUI面板 ======================================================
echo "是否安装3XUI面板? (y/n)"
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
    curl -Ls "${GH_URL}/mhsanaei/3x-ui/master/install.sh" -o "${TMP_SCRIPT}"
    chmod +x "${TMP_SCRIPT}"
    # 用sed修改脚本内的GitHub链接
    # 将raw.githubusercontent.com替换为GH_URL
    sed -i "s|https://raw.githubusercontent.com|${GH_URL}|g" "${TMP_SCRIPT}"
    # 将github.com替换为GH_WEB
    sed -i "s|https://github.com|${GH_WEB}|g" "${TMP_SCRIPT}"
    # 运行修改后的脚本，自动传入参数
    echo -e "y\n1090\n3\n/etc/xui/crt.pem\n/etc/xui/key.pem\n" | bash "${TMP_SCRIPT}"
	
fi

# 安装ET服务 ========================================================
echo "是否安装ET服务? (y/n)"
read INSTALL_ET
if [ "$INSTALL_ET" = "y" ]; then
    # 自动从GitHub读取最新的tag	
	ET_NEW="${GH_API}/repos/EasyTier/EasyTier/releases/latest"
    ET_TAG=$(curl -s ${ET_NEW} | grep '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
    echo "获取到最新的ET版本: ${ET_TAG}"
    ET_URL="${GH_WEB}/EasyTier/EasyTier/releases/download"
    ET_URL="${ET_URL}/${ET_TAG}/easytier-linux-x86_64-v${ET_TAG}.zip"
    wget -O easytier-linux-x86_64.zip ${ET_URL}
    # 解压ZIP文件
    unzip easytier-linux-x86_64.zip
    # 设置执行权限
    chmod -R +x easytier-linux-x86_64
    # 移动到/bin目录下
    mv easytier-linux-x86_64/* /bin/easytier
    # 清理临时文件
    rm -f easytier-linux-x86_64.zip 
	rm -rf easytier-linux-x86_64
	pm2 start /bin/easytier/easytier --name ET
    echo "ET服务安装完成，已安装到/bin/easytier"
fi

# 安装FRPS服务器 ====================================================
echo "是否设置FRPS服务器? (y/n)"
read INSTALL_FRPS
if [ "$INSTALL_FRPS" = "y" ]; then
    echo "请输入服务器名称(NN_FRP):"
    read NN_FRP
    echo "请输入节点UUID(TK_FRP):"
    read TK_FRP
    pm2 start frp-panel server -s ${TK_FRP} -i ${NN_FRP} \
              --api-url https://frphub.pika.net.cn:443 \
	          --rpc-url wss://frphub.pika.net.cn:443
fi

