# Linux 脚本

Linux 脚本是 CloudScripts 的核心部分，覆盖服务器部署、性能测评、系统清理、桌面安装、代理面板等场景。

---

## 服务器部署脚本

### Setup.sh - 交互式一键部署

这是一套交互式的一体化服务器部署方案，敏感信息使用 **AES-256-CBC + PBKDF2** 加密存储，运行时需输入部署密码。

```bash
bash <(curl -sSL https://gh-bat.pika.net.cn/Linux/VPSSets/Setup.sh)
```

**包含的可选模块：**

| 模块 | 说明 |
|------|------|
| 系统初始化 | 更新系统、安装 curl / wget / nano / git / htop 等常用工具 |
| ProxyChains4 | 配置 SOCKS5 代理链，用于后续下载加速 |
| Node.js (LTS) | 通过 NVM 安装 Node.js LTS 版本，配置 npmmirror 源并安装 PM2 |
| 宝塔面板 | 自动安装宝塔面板并配置用户名、密码和端口 |
| 哪吒探针 | 安装哪吒监控 Agent 并自动注册到服务端 |
| 3X-UI 面板 | 安装 3X-UI 面板，自动生成自签名 TLS 证书 |
| EasyTier | 从 GitHub 获取最新版本，部署 EasyTier 组网服务（PM2 托管） |
| FRP Panel | 安装 frp-panel 客户端/服务端节点（PM2 托管） |
| 端口限速 | 使用 tc + IFB 对指定端口进行双向流量限速 |

### Vault.sh - 加密工具

配套加密工具，用于生成 `Setup.sh` 所需的 AES-256-CBC 加密值。交互式输入各项敏感信息后输出加密后的 BASE64 字符串。

---

## 性能测评脚本

::: tip 14 款专业测评工具
涵盖 CPU、内存、磁盘 I/O、网络带宽、回程路由、IP 质量等全方位测试。
:::

### 综合测评

| 脚本 | 简介 | 使用命令 |
|------|------|----------|
| **融合怪 ECSScript** | 功能最全的一体化测评脚本 | `bash <(wget -qO- https://gh-bat.pika.net.cn/Linux/VPSTest/ecss-bench.sh)` |
| **SuperBench** | 老鬼出品的综合测试脚本 | `bash <(wget -qO- https://gh-bat.pika.net.cn/Linux/VPSTest/superbench.sh)` |
| **Bench.sh** | 秋水逸冰经典 Bench 脚本 | `bash <(wget -qO- https://gh-bat.pika.net.cn/Linux/VPSTest/qsyb-bench.sh)` |
| **LemonBench** | 针对 Linux 服务器的专业测试工具 | `bash <(wget -qO- https://gh-bat.pika.net.cn/Linux/VPSTest/lemonbench.sh)` |
| **YABS** | 跨平台基准测试 | `bash <(wget -qO- https://gh-bat.pika.net.cn/Linux/VPSTest/yabs-bench.sh)` |
| **UnixBench** | 类 Unix 系统经典性能基准测试 | `bash <(wget -qO- https://gh-bat.pika.net.cn/Linux/VPSTest/unix-bench.sh)` |

### 网络测速

| 脚本 | 简介 | 使用命令 |
|------|------|----------|
| **SuperSpeed** | 全国三大运营商 Speedtest 节点全面测速 | `bash <(wget -qO- https://gh-bat.pika.net.cn/Linux/VPSTest/superspeed.sh)` |
| **Speedtest-CLI** | Sivel 作品，经典测速工具 Python 版 | `bash <(wget -qO- https://gh-bat.pika.net.cn/Linux/VPSTest/speed-test.py)` |

### 路由追踪

| 脚本 | 简介 | 使用命令 |
|------|------|----------|
| **BackTrace** | 三网回程路由测试，自动检测架构下载对应二进制 | `bash <(wget -qO- https://gh-bat.pika.net.cn/Linux/VPSTest/back-trace.sh)` |
| **SuperTrace** | 老鬼出品，三网回程路由到 12 个国内核心节点 | `bash <(wget -qO- https://gh-bat.pika.net.cn/Linux/VPSTest/supertrace.sh)` |
| **BestTrace** | IPIP.net 出品，交互式输入目标 IP 进行回程路由测试 | `bash <(wget -qO- https://gh-bat.pika.net.cn/Linux/VPSTest/best-trace.sh)` |
| **mPing** | 一键 Ping 10 个国内节点 + 三网路由跟踪 | `bash <(wget -qO- https://gh-bat.pika.net.cn/Linux/VPSTest/mping-test.sh)` |

### 其他工具

| 脚本 | 简介 | 使用命令 |
|------|------|----------|
| **PrettyPing** | 美化版 ping 命令，带彩色图示 | `bash <(wget -qO- https://gh-bat.pika.net.cn/Linux/VPSTest/prettyping.sh)` |
| **IP-Quality** | IP 质量检测：多数据库风险评分、流媒体解锁、邮局连通性 | `bash <(wget -qO- https://gh-bat.pika.net.cn/Linux/VPSTest/ip-quality.sh)` |

---

## 系统清理

一键清理 Linux 系统垃圾：

```bash
apt -y install curl && curl -sSL https://gh-bat.pika.net.cn/Linux/Cleaner/LinuxClean.sh | bash
```

清理内容：
- Bash 历史记录
- APT 缓存
- Journalctl 日志
- 缩略图缓存
- 回收站
- 崩溃文件
- Docker 无用资源（镜像、容器、卷）

---

## 图形化桌面安装

专为 **Debian LXC 容器** 设计的分层桌面安装方案。通过标记文件跟踪安装状态，防止重复安装。

### 安装顺序

桌面安装需要按以下顺序执行（后一层依赖前一层）：

```
Server 基础环境 → X11 图形栈 → 具体桌面环境
```

### 基础层

| 脚本 | 说明 | 命令 |
|------|------|------|
| **Server 基础环境** | 换 APT 源(中科大镜像)、安装 SSH/sudo/vim/git 等基础工具、配置用户和 systemd | `curl -sSL https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Server.sh \| bash -e` |
| **X11 图形栈** | 安装 Xorg/Xvfb/pulseaudio/XRDP/x11vnc/NoMachine 远程桌面，配置 VNC 和 NX 协议 | `curl -sSL https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Graphy.sh \| bash -e` |

### 桌面环境选择

| 桌面 | 特点 | 命令 |
|------|------|------|
| **Deepin / GXDE** | 中文友好、易用美观 | `curl -sSL https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Deepin.sh \| bash -e` |
| **KDE Plasma** | 高度可定制、功能全面 | `curl -sSL https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Plasma.sh \| bash -e` |
| **KDE Lingmo** | KDE 国风变体、界面现代 | `curl -sSL https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Lingmo.sh \| bash -e` |
| **Xfce** | 资源占用低、稳定流畅 | `curl -sSL https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Xfce4L.sh \| bash -e` |
| **GNOME 3** | 简洁现代、工作流导向 | `curl -sSL https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Gnome3.sh \| bash -e` |
| **MATE** | 传统菜单与窗口风格、稳定耐用 | `curl -sSL https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-MateDE.sh \| bash -e` |

::: warning 注意
桌面安装前建议先更换 APT 镜像源以提高下载速度：

```bash
sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list.d/debian.sources
sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list
apt update && apt upgrade
```
:::

---

## 代理面板

### 3X-UI 面板

3X-UI 是 Xray-core 的 Web 管理面板，支持多协议、多用户管理。

```bash
# 安装
bash <(curl -sSL https://gh-bat.pika.net.cn/Linux/Tunnels/3x-ui/install.sh)

# 更新
bash <(curl -sSL https://gh-bat.pika.net.cn/Linux/Tunnels/3x-ui/update.sh)

# 管理
bash <(curl -sSL https://gh-bat.pika.net.cn/Linux/Tunnels/3x-ui/x-ui.sh)
```

也可以通过 Docker Compose 部署（使用 host 网络模式）：

```bash
# 下载 docker-compose.yml 后启动
docker compose up -d
```
