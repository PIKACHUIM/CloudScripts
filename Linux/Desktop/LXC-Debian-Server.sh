#!/bin/bash

UR="mirrors.tuna.tsinghua.edu.cn"
if [ "$OS_VERSION" = "trixie" ] || [ "$OS_VERSION" = "bookworm" ]; then                           \
        cp /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list.d/debian.sources.bak      \
        && sed -i 's/deb.debian.org/'${UR}'/g' /etc/apt/sources.list.d/debian.sources             \     
        && sed -i "s/main/main contrib non-free/g" /etc/apt/sources.list.d/debian.sources         \
        && sed -i 's/security.debian.org/'${UR}'/g' /etc/apt/sources.list.d/debian.sources        \
    ;else                                                                                         \
        cp /etc/apt/sources.list /etc/apt/sources.list.bak                                        \
        && sed -i 's/deb.debian.org/'${UR}'/g' /etc/apt/sources.list                              \     
        && sed -i 's/security.debian.org/'${UR}'/g' /etc/apt/sources.list                         \
    ;fi
	
apt update && apt install -y openssh-server sudo vim nano 

# Allow SSH PAM & Password Login -------------------------------------------------------------------
mkdir -p /var/run/sshd && mkdir -p /root/.ssh/
echo "PermitRootLogin without-password" >> /etc/ssh/sshd_config
echo "ListenAddress 0.0.0.0" >> /etc/ssh/sshd_config

# User ---------------------------------------------------------------------------------------------
chmod +x /run.sh && rm /etc/pam.d/sshd && mkdir -p /run/sshd
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
echo "#!/bin/bash" > /run.sh