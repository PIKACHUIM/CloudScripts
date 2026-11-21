<p align="center">
  <img src="https://img.shields.io/badge/Platform-Linux%20%7C%20Windows-blue?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/License-GPL%20%7C%20MIT-green?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/Shell-Bash%20%7C%20PowerShell-orange?style=flat-square" alt="Shell">
  <a href="https://github.com/PIKACHUIM/CloudScripts/actions/workflows/shellcheck.yml"><img src="https://github.com/PIKACHUIM/CloudScripts/actions/workflows/shellcheck.yml/badge.svg" alt="ShellCheck"></a>
  <a href="https://github.com/PIKACHUIM/CloudScripts/actions/workflows/pages-deploy.yml"><img src="https://github.com/PIKACHUIM/CloudScripts/actions/workflows/pages-deploy.yml/badge.svg" alt="Pages"></a>
</p>

<h1 align="center">⚡ 皮卡在线脚本托管平台</h1>
<p align="center"><strong>Pika Online Script Hosting Platform</strong></p>

<p align="center">
  一键部署 · 性能测评 · 网络诊断 · 桌面环境 · 容器引擎 · 🇨🇳 大陆加速 · 🌐 多语言 · 📖 文档站点
</p>

<p align="center">
  <a href="https://github.com/PIKACHUIM/CloudScripts"><b>📦 项目地址</b></a> &nbsp;|&nbsp;
  <a href="https://pikash.pika.net.cn"><b>📖 文档站点（国内）</b></a> &nbsp;|&nbsp;
  <a href="https://pikash.opkg.cn"><b>📖 文档站点（海外）</b></a>
</p>

---


## 🚀 快速开始

一行命令启动总菜单，自动识别系统并展示对应功能：

```bash
# 国内服务器（EdgeOne 线路）
bash <(curl -fsSL https://pikash.pika.net.cn/Menu.sh)

# 海外服务器（GitHub Pages 线路）
bash <(curl -fsSL https://pikash.opkg.cn/Menu.sh)
```

> 🌐 两个域名内容完全一致，脚本启动时会自动探测可用线路；也可用 `--mirror=URL` 强制指定。
> 每个请求都带连接与总时长上限，线路不可达时几秒内切换，不会卡死。

### 菜单一览

| 类别 | 说明 |
|:-----|:-----|
| 🖥️ **1. 部署安装** | 换源/面板(宝塔/1Panel/NetPanel)/探针/Docker+Podman/EasyTier/FRPS/RustDesk/Node+PM2 |
| 🔧 **2. 系统维护** | 清理/BBR加速/BBRPlus/Swap管理/Fail2ban/UFW防火墙/DD重装/内核管理 |
| 🎨 **3. 桌面安装** | Debian LXC 容器桌面：Xfce4/GNOME3/Plasma/MATE/Deepin/Lingmo/Hyprland/Niri (共8种) |
| 📊 **4. 性能测评** | 融合怪/IP质量/LemonBench/YABS/UnixBench/SuperBench/SuperSpeed/BestTrace 等 13 项 |
| 📥 **5. 软件安装** | Lucky/LobeChat/Halo/SiYuan/DDNS-GO/NPS/Bark 等 53 款热门自托管工具 |
| 🌐 **6. 代理组网** | 3X-UI/Clash/Hysteria2/SS-rust/Trojan-Go/WARP/WireGuard/wg-easy/ZeroTier/Tailscale |
| 🛡️ **7. 反向代理** | Caddy / Nginx 二选一：一键安装、站点增删、手动或 ACME 证书 |
| 🛠️ **8. 系统工具** | SSH加固/时区校时/修改主机名/系统信息/**国内网络加速**/自更新/快捷命令/卸载回滚 |

> 国内与海外各有一条独立线路，脚本启动时自动选择可用的那条；安装组件时直连 GitHub 失败会自动切换加速通道，无需手动配置。

### 新增特性 (v1.0)

- 🌐 **双线路自动选优**：国内 EdgeOne / 海外 GitHub Pages 互为备份，并发探测、24h 缓存，请求全程带超时
- 🇨🇳 **国内网络加速**：GitHub 下载直连优先、失败自动走加速前缀；软件源 / Docker / npm / pip 一键切换国内镜像
- 🌍 **中英双语**：默认中文，支持 `--lang=en_US` 手动切换
- 🔧 **统一服务托管**：PM2 优先 > systemd 次选 > nohup 降级，提供统一的启停/日志/卸载接口
- 📦 **按需加载**：主入口轻量化 (~230行)，业务模块按需下载缓存
- 🛡️ **安全加固**：随机口令、sysctl 幂等写入、危险操作二次确认
- 📊 **系统信息卡片**：类似 neofetch 的硬件信息展示（CPU/GPU/内存/磁盘/IP）
- 🖥️ **修改主机名**：RFC 952/1123 校验，自动更新 /etc/hosts 和 cloud-init
- 🔄 **脚本自更新**：支持快捷命令 `p` 一键启动

### 国内加速

主菜单 → **8. 系统工具 → 5. 国内网络加速**，集中管理以下四项（全部可逆，改动前自动备份）：

| 项目 | 行为 |
|:-----|:-----|
| GitHub 下载 | 直连优先；失败后并发探测 `ghfast.top` / `gh-proxy.com` / `ghproxy.net` / `github.524228.xyz`，选中结果缓存 24h |
| 系统软件源 | Debian/Ubuntu（含 deb822）、Alpine、Rocky/AlmaLinux/CentOS/Fedora 切换到清华 TUNA，原文件备份为 `*.pika.bak.<时间戳>` |
| Docker | 官方脚本 + 阿里云源兜底安装，写入 `registry-mirrors`；`ghcr.io` 等镜像拉取失败自动改用 daocloud 镜像 |
| npm / pip | `registry.npmmirror.com`、清华 PyPI；Node.js 走 npmmirror 下载 |

组件安装脚本（Lucky、OpenList、Aria2 Pro、NPS、1Panel、宝塔、哪吒、3x-ui、Caddy 二进制、acme.sh 等）全部通过统一入口下载，自带超时与加速回退；如需完全直连，使用 `bash Menu.sh --no-accel`。

### 命令行参数

```bash
bash Menu.sh [分类] [项目] [选项]

选项:
  --lang=zh_CN|en_US     切换语言
  --mirror=URL            强制指定镜像通道
  --backend=pm2|systemd   强制指定服务后端
  --no-accel              关闭 GitHub 加速（全部直连）
  --yes, -y               跳过所有确认提示
  --help, -h              显示帮助

示例:
  bash Menu.sh 1 1        直达"部署安装 > 换源"
  bash Menu.sh 3          进入"桌面环境"菜单
  bash Menu.sh --lang=en_US
```

---

## 📦 功能详解

### 🖥️ 一键部署

<details>
<summary>📋 包含模块（点击展开）</summary>

| 模块 | 说明 |
|:-----|:-----|
| 换大陆镜像源 | Debian/Ubuntu/Alpine/Rocky/Alma 自动切换清华源（原文件备份） |
| 系统初始化 | 更新系统、安装 curl/wget/nano/git/htop/vim 等常用工具 |
| Docker + 镜像加速 | Docker CE（官方脚本/Aliyun 兜底）+ registry-mirrors |
| Podman + 镜像 | Podman + registries 镜像加速 |
| 宝塔面板 | 自动安装并配置用户名、密码、面板端口 |
| 1Panel | 现代化开源面板一键安装 |
| NetPanel | 轻量服务器管理面板 |
| 哪吒探针 | Agent 自动注册 |
| Node.js + PM2 | NVM + npmmirror 源 |
| EasyTier | P2P 组网工具 |
| FRPS | FRP 内网穿透服务端 |
| RustDesk | 远程桌面中继服务 |

</details>

---

### 🔧 日常维护

| 分类 | 功能 | 说明 |
|:-----|:-----|:-----|
| 系统优化 | 垃圾清理 | apt缓存/journal/Docker/bash历史 |
| | Swap 管理 | 添加/删除/Zram 虚拟内存 |
| | BBR 加速 | 原生BBR / BBR3+FQ / BBR+Cake |
| | BBRPlus/BBR2/BBR3 | ylx2016 多版本一键 |
| | TCP 优化 | FastOpen/缓冲/backlog |
| 安全防护 | UFW 防火墙 | 一键配置/端口管理 |
| | Fail2ban | SSH 防暴力破解 24h封禁 |
| | BlockAreaBot | 一键屏蔽指定国家/地区 IP |
| 系统管理 | 端口限速 | tc+IFB 双向限速 |
| | 升级内核 | XanMod/Liquorix/Backports/HWE |
| | DD 系统重装 | bin456789 一键重装 Debian/Ubuntu/Win |
| 常用工具 | ACME 证书 | Let's Encrypt 免费SSL签发/续期 |
| | Aria2 下载器 | 离线下载+RPC (端口6800) |
| | 服务器监控 | Netdata/Cockpit/Glances |

---

### 🌐 代理配置

| 功能 | 说明 |
|:-----|:-----|
| 3X-UI 面板 | Xray-core 多协议 Web 面板 |
| Clash for Linux | 基于 Clash 的代理客户端 |
| Hysteria2 (HY2) | 高速 UDP 代理协议 |
| Shadowsocks-rust | 经典 SS (Rust 高性能版) |
| Trojan-Go | Trojan 协议 Go 实现 |
| Cloudflare WARP | WARP CLI + WGCF 部署管理 |
| WireGuard | 原生安装 + 自动生成密钥 |
| wg-easy | Docker Web 面板管理 WireGuard |

---

### 🛡️ 反向代理（Caddy / Nginx）

`bash Menu.sh reverseproxy` 可直接进入（也可从主菜单选择「7. 反向代理」）。两个后端都会占用 80/443，因此**同时只能运行一个**：进入另一个后端时会提示停止并停用当前后端。

| 功能 | Caddy | Nginx |
|:-----|:------|:------|
| 一键安装/升级 | 官方 Release 二进制，自动识别架构，走镜像加速 | 发行版软件包安装，自动接管 conf.d |
| 反向代理管理 | 站点片段 + `import`，多域名/多上游/附加指令 | 统一生成 `pika.conf` server 块，多域名/多上游/附加 location 指令 |
| 证书模式 | 自动 ACME / 手动证书 / 自签名 / 纯 HTTP | acme.sh 自动签发（Webroot）/ 手动证书 / 自签名 / 纯 HTTP |
| 证书上传 | 公私钥配对校验、SAN 解析、一键绑定 | 同左 |
| ACME 申请 | HTTP-01 独立/Webroot、TLS-ALPN-01、DNS 手动 TXT | 同左（Webroot 可在 Nginx 运行时签发） |
| 服务与配置 | 启停/重启/热重载/日志/`caddy validate` | 启停/重启/热重载/日志/`nginx -t` |

> Caddy 配置位于 `/etc/caddy/pika/`；Nginx 站点元数据位于 `/etc/pika-sh/nginx/meta/`，生成文件为 `/etc/nginx/conf.d/pika.conf`。所有变更前自动备份，校验失败自动回滚。

---

### 🎨 桌面环境安装 (Debian LXC)

> ⚠️ **安装顺序**：先装 Server 基础环境 → X11 图形栈 → 再选装桌面

| 编号 | 桌面环境 | 特点 |
|:----:|:---------|:-----|
| 10 | **Server 基础环境** | 🔧 换 USTC 源、SSH、sudo/vim/git 等基础工具 |
| 11 | **X11 图形栈** | 🖼️ Xserver + NoMachine 远程桌面 |
| 12 | **Deepin / GXDE** | 🎯 中文友好、美观的 Deepin 风格 |
| 13 | **KDE Plasma** | ✨ 高度可定制、功能全面的现代桌面 |
| 14 | **KDE Lingmo** | 🏮 KDE 国风变体 |
| 15 | **Xfce 轻量** | 🪶 资源占用低、稳定流畅 |
| 16 | **GNOME 3** | 🧩 简洁现代、工作流导向 |
| 17 | **MATE 经典** | 🏛️ 传统菜单风格、稳定耐用 |

<details>
<summary>📝 手动安装命令（点击展开）</summary>

```bash
# 1. 换源（Debian）
sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list.d/debian.sources
sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list
apt update && apt upgrade

# 2. 基础环境
curl -s https://pikash.pika.net.cn/Linux/Desktop/LXC-Debian-Server.sh | bash -e

# 3. 图形栈
curl -s https://pikash.pika.net.cn/Linux/Desktop/LXC-Debian-Graphy.sh | bash -e

# 4. 选择桌面（示例：Deepin）
curl -s https://pikash.pika.net.cn/Linux/Desktop/LXC-Debian-Deepin.sh | bash -e
```

</details>

> 安装状态通过 `/etc/lxc-de-flag` 追踪，防止重复安装。

---

### 📊 性能测评

| 编号 | 工具 | 简介 | 作者 |
|:----:|:-----|:-----|:-----|
| 20 | **融合怪 综合测评** | CPU/内存/磁盘/网络/流媒体全面检测 | spiritLHLS |
| 21 | **IP 质量体检** | 多数据库风险评分 + 流媒体 + 邮局连通性 | - |
| 22 | **LemonBench** | CPU/内存/磁盘/网络 基准测试 | iLemonrain |
| 23 | **YABS** | iperf3 + Geekbench + fio 跨平台测试 | Mason Rowe |
| 24 | **UnixBench** | 类Unix系统综合性能跑分 | Teddysun |
| 25 | **Bench.sh** | 系统信息 + IO + 网速基准 | 秋水逸冰 |
| 26 | **SuperBench** | 系统信息 + IO + 全国测速 | Oldking |
| 27 | **SuperSpeed** | 全国三网 Speedtest 全面测速 | - |

---

### 🌐 网络诊断

| 编号 | 工具 | 简介 | 作者 |
|:----:|:-----|:-----|:-----|
| 30 | **BackTrace** | 三网回程路由自动测试 | - |
| 31 | **SuperTrace** | 北上广三大运营商路由追踪 | Oldking |
| 32 | **BestTrace** | IPIP.net 交互式路由追踪 | IPIP.net |
| 33 | **mPing** | 全国多地域 Ping 测试 | xiaoz.me |
| 34 | **PrettyPing** | 彩色图形化 Ping 输出 | Denilson Figueiredo |

---

## 🪟 Windows 脚本

> Windows 脚本需在 **PowerShell（管理员）** 中运行。
> 在 Git Bash / MSYS2 中运行 Menu.sh 将自动显示对应的 PowerShell 命令。

### Docker / 容器引擎

| 工具 | 特点 | 命令 |
|:-----|:-----|:-----|
| **Docker CE** | Hyper-V / Native 双运行时可选 | `irm https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/WinNT/Docker/Winx86-dockerce.ps1 \| iex` |
| **Mirantis 容器运行时** | Docker CE 替代方案 | `irm https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/WinNT/Docker/Winx86-mirantis.ps1 \| iex` |
| **containerd + nerdctl** | 轻量容器方案（无需 Docker daemon） | `irm https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/WinNT/Docker/Winx86-nerdctls.ps1 \| iex` |

<details>
<summary>⚙️ nerdctl 优化操作（点击展开）</summary>

##### 使用 `docker` 别名

```powershell
copy "C:\Program Files\nerdctl\nerdctl.exe" "C:\Program Files\nerdctl\docker.exe"
```

##### 迁移数据目录

编辑 `C:\Program Files\containerd\config.toml`：

```toml
root = "D:\\Nerd\\root"
state = "D:\\Nerd\\state"

[plugins."io.containerd.internal.v1.opt"]
  path = "D:\\Nerd\\root\\opt"
```

然后迁移数据：

```powershell
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)
docker rmi $(docker images -q)
net stop containerd
tskill containerd

mkdir "D:\Nerd"
xcopy "C:\ProgramData\containerd\" "D:\Nerd\" /E /H /C /I /Y
net start containerd
```

</details>

### 系统激活

```powershell
irm https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/WinNT/Active/MAS_AIO.cmd | iex
```

Microsoft Activation Scripts (MAS) AIO v3.10，支持 Windows 和 Office 全系列激活。

---

## 📁 项目结构

```
CloudScripts/
├── Menu.sh                     # ⭐ 总菜单入口（自动识别系统）
├── README.MD                   # 本文档
├── edgeone.json                # EdgeOne Pages 构建配置
├── .github/workflows/          # CI/CD（ShellCheck / Pages 部署）
├── scripts/
│   └── build-site.mjs          # 统一构建：VitePress + 脚本镜像 → _site/
├── docs/                       # VitePress 文档站点
│
├── Linux/
│   ├── Lib/                    # 核心库（网络/包管理/UI/i18n/服务托管）
│   ├── I18n/                   # 中英文语言包
│   ├── Modules/                # 业务模块（7 大菜单）
│   ├── Desktop/                # Debian LXC 桌面环境（8种）
│   ├── VPSTest/                # 性能测评（13款工具）
│   ├── VPSSets/                # VPS 服务器部署
│   │   ├── Setup.sh            #   交互式一键部署
│   │   └── Vault.sh            #   AES-256 凭据生成器
│   ├── Cleaner/                # 系统清理
│   └── Tunnels/                # 代理面板/内网穿透
│
└── WinNT/
    ├── Docker/                  # Docker CE / Mirantis / nerdctl
    └── Active/                  # Windows/Office 激活 (MAS)
```

---

## 🌐 站点部署

站点与脚本镜像来自同一次构建，GitHub Pages 与 EdgeOne Pages 共用 `scripts/build-site.mjs`：

```bash
npm ci --prefix docs      # 安装 VitePress 依赖
node scripts/build-site.mjs
# 产物：_site/  （VitePress 页面 + Menu.sh + Linux/ + WinNT/ + 探针文件）
```

| 平台 | 触发方式 | 配置 |
|:-----|:---------|:-----|
| GitHub Pages (`pikash.opkg.cn`) | 推送 `main` 自动执行 `.github/workflows/pages-deploy.yml` | `CNAME` |
| EdgeOne Pages (`pikash.pika.net.cn`) | 在 Makers 控制台关联本仓库，推送后自动构建 | `edgeone.json` |

EdgeOne Pages 控制台需设置：安装命令 `npm --prefix docs ci`、构建命令 `node scripts/build-site.mjs`、输出目录 `_site`（`edgeone.json` 已写好，控制台留空即可被覆盖），Node 版本 20。构建完成后在国内线路的自定义域名里绑定 `pikash.pika.net.cn` 即可。

---

## 🔗 地址说明

| 类型 | 地址 |
|:-----|:-----|
| 📦 GitHub | <https://github.com/PIKACHUIM/CloudScripts> |
| 📖 文档站点（国内） | <https://pikash.pika.net.cn> |
| 📖 文档站点（海外） | <https://pikash.opkg.cn> |
| 📥 脚本直连（国内） | `https://pikash.pika.net.cn` |
| 📥 脚本直连（海外） | `https://pikash.opkg.cn` |
| ⚡ 加速 Raw | `https://github.524228.xyz/https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main` |

> Menu.sh 启动时并发探测两条线路，取最先响应的一个并缓存 24 小时；所有请求带超时上限，线路不可达时数秒内切换。

---

## 📄 许可证

本项目同时包含 [GNU GPL](LICENSE) 和 [MIT](LICENSE-MIT) 许可的组件，详见各子目录。
