#!/bin/bash
# LXC-Debian-Server.sh - 基础服务环境安装
# 此脚本安装 SSH、Docker、用户管理等基础服务
# 安装完成后可继续安装:
#   - DockerClouds 管理平台: curl .../LXC-Debian-DockerClouds.sh | bash -e
#   - X11 图形环境:          curl .../LXC-Debian-Graphy.sh | bash -e

# Check -----------------------------------------------------------
file="/etc/lxc-de-flag"
set -e
if [[ ! -f "$file" ]] || [[ ! -s "$file" ]]; then
    echo "检查通过，开始安装服务环境....."
else
    read -r content < "$file"      # 去掉前后空白，只读第一行
    case "$content" in
        0) echo "已经安装过环境，禁止重复安装" && exit ;;
        9) echo "已经安装过X11，禁止重复安装" && exit ;;
        *) echo "已经安装过桌面，禁止重复安装" && exit ;;
    esac
fi


# Set UP APT Sources -------------------------------------------------------------------------------
sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list.d/debian.sources \
|| sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list
apt update && apt install -y openssh-server sudo vim nano wget curl gnupg2 git openssl

# Allow SSH PAM & Password Login -------------------------------------------------------------------
mkdir -p /var/run/sshd && mkdir -p /root/.ssh/
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
echo "ListenAddress 0.0.0.0" >> /etc/ssh/sshd_config

# User ---------------------------------------------------------------------------------------------
touch /run.sh && chmod +x /run.sh
groupadd -r -g 2000 user &&  useradd -u 2000 -m -r -g user user
echo "user ALL=(ALL)      ALL" >> /etc/sudoers

# Docker CE 安装 (DockerClouds 平台依赖) -----------------------------------------------------------
echo "安装 Docker CE (DockerClouds 运行时依赖)....."
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update && DEBIAN_FRONTEND=noninteractive apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin || \
echo "Docker CE 安装失败（可能在不支持 Docker 的 LXC 环境），跳过"

# 允许非 root 用户使用 Docker
usermod -aG docker user 2>/dev/null || true

# Init Systemd Service -----------------------------------------------------------------------------
cat > /etc/systemd/system/run.service <<'EOF'
[Unit]
Description=Pikachu Docker Run Script

[Service]
Type=forking
WorkingDirectory=/
ExecStart=/bin/bash /run.sh
SuccessExitStatus=0
Restart=no
RestartSec=1
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

[Install]
WantedBy=multi-user.target
EOF

# Init Script --------------------------------------------------------------------------------------
echo "#!/bin/bash"                               > /run.sh
echo 'echo Starting Basic Server ------------'  >> /run.sh
echo 'nohup /usr/sbin/sshd -D &'                >> /run.sh
systemctl enable run && systemctl start run
echo 0 > /etc/lxc-de-flag

echo "============================================"
echo "  基础服务环境安装完成"
echo "  DockerClouds 安装: curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-DockerClouds.sh | bash -e"
echo "============================================"