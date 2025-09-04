#!/bin/bash
# Check -----------------------------------------------------------
file="/etc/lxc-de-flag"
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
sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list.d/debian.sources
sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list
apt update && apt install -y openssh-server sudo vim nano wget curl gnupg2 git openssl

# Allow SSH PAM & Password Login -------------------------------------------------------------------
mkdir -p /var/run/sshd && mkdir -p /root/.ssh/
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
echo "ListenAddress 0.0.0.0" >> /etc/ssh/sshd_config

# User ---------------------------------------------------------------------------------------------
touch /run.sh && chmod +x /run.sh && rm /etc/pam.d/sshd && mkdir -p /run/sshd
groupadd -r -g 2000 user &&  useradd -u 2000 -m -r -g user user
echo "user ALL=(ALL)      ALL" >> /etc/sudoers

# Init ---------------------------------------------------------------------------------------------
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

# Init ---------------------------------------------------------------------------------------------
echo "#!/bin/bash"                               > /run.sh
echo 'echo Starting Basic Server ------------'  >> /run.sh
echo 'nohup /usr/sbin/sshd -D &'                >> /run.sh
systemctl enable run && systemctl start run
echo 0 > /etc/lxc-de-flag