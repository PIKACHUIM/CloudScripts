<p align="center">
  <img src="https://img.shields.io/badge/Platform-Linux%20%7C%20Windows-blue?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/License-GPL%20%7C%20MIT-green?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/Shell-Bash%20%7C%20PowerShell-orange?style=flat-square" alt="Shell">
  <a href="https://github.com/PIKACHUIM/CloudScripts/actions/workflows/shellcheck.yml"><img src="https://github.com/PIKACHUIM/CloudScripts/actions/workflows/shellcheck.yml/badge.svg" alt="ShellCheck"></a>
</p>

<h1 align="center">⚡ 皮卡在线脚本托管平台</h1>
<p align="center"><strong>Pika Online Script Hosting Platform</strong></p>

<p align="center">
  一键部署 · 性能测评 · 网络诊断 · 桌面环境 · 容器引擎 · 🇨🇳 大陆加速 · 🌐 多语言
</p>

<p align="center">
  <a href="https://github.com/PIKACHUIM/CloudScripts"><b>📦 项目地址</b></a> &nbsp;|&nbsp;
  <a href="https://github.524228.xyz/PIKACHUIM/CloudScripts"><b>🚀 国内加速</b></a>
</p>

---

### 架构

```
Menu.sh (引导器 ~230行)
├── Lib/00-core.sh    日志/配置/系统检测
├── Lib/10-net.sh     多级镜像探测/统一下载
├── Lib/20-pkg.sh     6种包管理器抽象
├── Lib/30-svc.sh     PM2/systemd/nohup 统一托管
├── Lib/40-ui.sh      菜单渲染/CJK对齐
├── Lib/50-i18n.sh    多语言自动切换
├── I18n/zh_CN.sh     中文语言包 (兜底)
├── I18n/en_US.sh     英文语言包
├── Modules/deploy.sh     部署安装模块
├── Modules/maintain.sh   系统维护模块
├── Modules/desktop.sh    桌面安装模块
├── Modules/bench.sh      性能测评模块
├── Modules/proxy.sh      代理组网模块
└── Modules/system.sh     系统工具模块
```

## 🚀 快速开始

一行命令启动总菜单，自动识别系统并展示对应功能：

```bash
bash <(curl -s https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Menu.sh)
```

> 🌐 **国内加速**（镜像地址，下载更快）：
> ```bash
> bash <(curl -s https://github.524228.xyz/https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Menu.sh)
> ```

### 菜单一览

| 类别 | 说明 |
|:-----|:-----|
| 🖥️ **1. 部署安装** | 换源/面板(宝塔/1Panel/NetPanel)/探针/Docker+Podman/组网/Node+PM2 |
| 🔧 **2. 系统维护** | 清理/BBR加速/BBRPlus/Swap管理/Fail2ban/UFW防火墙/DD重装/内核管理 |
| 🎨 **3. 桌面安装** | Debian LXC 容器桌面：Xfce4/GNOME3/Plasma/MATE/Deepin/Lingmo/Hyprland/Niri (共8种) |
| 📊 **4. 性能测评** | 融合怪/IP质量/LemonBench/YABS/UnixBench/SuperBench/SuperSpeed/BestTrace 等 13 项 |
| 🌐 **5. 代理组网** | 3X-UI/Clash/Hysteria2/SS-rust/Trojan-Go/WARP/WireGuard/wg-easy |
| 🛠️ **6. 系统工具** | SSH加固/时区校时/系统信息/自更新/快捷命令/卸载回滚 |

> 中国大陆用户可直接使用，脚本内置**多级镜像自动探测**，无需手动指定加速通道。

### 新增特性 (v1.0)

- 🌐 **大陆网络加速**：多级镜像通道自动探测，抗 DNS 污染校验，24h 缓存
- 🌍 **中英双语**：按系统语言自动切换，支持 `--lang=en_US` 手动指定
- 🔧 **统一服务托管**：PM2 优先 > systemd 次选 > nohup 降级，提供统一的启停/日志/卸载接口
- 📦 **按需加载**：主入口轻量化 (~230行)，业务模块按需下载缓存
- 🛡️ **安全加固**：随机口令、sysctl 幂等写入、危险操作二次确认
- 🔄 **脚本自更新**：支持快捷命令 `p` 一键启动

### 命令行参数

```bash
bash Menu.sh [分类] [项目] [选项]

选项:
  --lang=zh_CN|en_US     切换语言
  --mirror=URL            强制指定镜像通道
  --backend=pm2|systemd   强制指定服务后端
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
| 换大陆镜像源 | Debian/Ubuntu USTC 源自动切换 |
| 系统初始化 | 更新系统、安装 curl/wget/nano/git/htop/vim 等常用工具 |
| Docker + 1ms 镜像 | Docker CE + 国内镜像加速 |
| Podman + 镜像 | Podman + registries 镜像加速 |
| 宝塔面板 | 自动安装并配置用户名、密码、面板端口 |
| 1Panel | 现代化开源面板一键安装 |
| FRP Panel | 内网穿透面板 (PM2) |
| NetPanel | 轻量服务器管理面板 |
| 哪吒探针 | Agent 自动注册 |
| Node.js + PM2 | NVM + npmmirror 源 |
| EasyTier | P2P 组网 |
| RustDesk/ZeroTier/Tailscale | 中转与组网 |

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
curl -s https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/Desktop/LXC-Debian-Server.sh | bash -e

# 3. 图形栈
curl -s https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/Desktop/LXC-Debian-Graphy.sh | bash -e

# 4. 选择桌面（示例：Deepin）
curl -s https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/Desktop/LXC-Debian-Deepin.sh | bash -e
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
│
├── Linux/
│   ├── VPSSets/                # VPS 服务器部署
│   │   ├── Setup.sh            #   交互式一键部署
│   │   └── Vault.sh            #   AES-256 凭据生成器
│   ├── Desktop/                # Debian LXC 桌面环境（8种）
│   ├── VPSTest/                # 性能测评（13款工具）
│   ├── Cleaner/                # 系统清理
│   └── Tunnels/3x-ui/          # 3X-UI 代理面板
│
└── WinNT/
    ├── Docker/                  # Docker CE / Mirantis / nerdctl
    └── Active/                  # Windows/Office 激活 (MAS)
```

---

## 🔗 地址说明

| 类型 | 地址 |
|:-----|:-----|
| 📦 GitHub | <https://github.com/PIKACHUIM/CloudScripts> |
| 🚀 国内加速 | <https://github.524228.xyz/PIKACHUIM/CloudScripts> |
| 📥 直连 Raw | `https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main` |
| ⚡ 加速 Raw | `https://github.524228.xyz/https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main` |

> Menu.sh 启动时会自动测速，优先使用直连，超时则自动切换到加速地址。

---

## 📄 许可证

本项目同时包含 [GNU GPL](LICENSE) 和 [MIT](LICENSE-MIT) 许可的组件，详见各子目录。
