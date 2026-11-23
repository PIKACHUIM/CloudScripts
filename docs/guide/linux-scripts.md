# Linux 脚本

Linux 脚本是 CloudScripts 的核心部分，覆盖服务器部署、性能测评、系统清理、桌面安装、代理面板、组网中转等场景。

> 💡 **推荐使用总菜单**：`bash <(curl -s https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Menu.sh)` 一键进入，无需记忆命令。

**关于启动速度**：菜单本身不发网络请求。本地脚本文件齐全时不会去探测下载线路，系统信息只采集一次、菜单重绘直接复用；子菜单模块首次进入时下载，10 分钟内再次进入直接用缓存（`PIKA_MOD_TTL=0` 可强制每次回源）。用 `bash <(curl ...)` 方式运行时本地没有文件，启动阶段的几个库和首次进入子菜单的模块才需要下载。

---

## 服务器部署脚本

### Setup.sh - 交互式一键部署

这是一套交互式的一体化服务器部署方案，敏感信息使用 **AES-256-CBC + PBKDF2** 加密存储，运行时需输入部署密码。

```bash
bash <(curl -sSL https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/VPSSets/Setup.sh)
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
| RustDesk 中转 | 部署 RustDesk 中继服务器（hbbs + hbbr），默认端口 21116-21117 |
| ZeroTier | 安装 ZeroTier 组网工具，默认端口 1048 UDP |
| Tailscale | 安装 Tailscale 组网，默认端口 1049，支持出口节点/子网路由模式 |
| 端口限速 | 使用 tc + IFB 对指定端口进行双向流量限速（支持端口范围、自定义速率） |

### Vault.sh - 加密工具

配套加密工具，用于生成 `Setup.sh` 所需的 AES-256-CBC 加密值。交互式输入各项敏感信息后输出加密后的 BASE64 字符串。

---

## 性能测评脚本

::: tip 14 款专业测评工具
涵盖 CPU、内存、磁盘 I/O、网络带宽、回程路由、IP 质量等全方位测试。
:::

### 综合测评

| 脚本 | 简介 | Menu 编号 |
|------|------|:---------:|
| **融合怪 ECSScript** | 功能最全的一体化测评脚本 | 20 |
| **IP 质量体检** | 多数据库风险评分 + 流媒体 + 邮局连通性 | 21 |
| **LemonBench** | 针对 Linux 服务器的专业测试工具 | 22 |
| **YABS** | iperf3 + Geekbench + fio 跨平台基准测试 | 23 |
| **UnixBench** | 类 Unix 系统经典性能基准测试 | 24 |
| **Bench.sh** | 秋水逸冰经典 Bench 脚本 | 25 |
| **SuperBench** | 老鬼出品的综合测试脚本 | 26 |

### 网络测速

| 脚本 | 简介 | Menu 编号 |
|------|------|:---------:|
| **SuperSpeed** | 全国三大运营商 Speedtest 节点全面测速 | 27 |
| **Speedtest-CLI** | Sivel 作品，经典测速工具 Python 版 | - |

### 路由追踪

| 脚本 | 简介 | Menu 编号 |
|------|------|:---------:|
| **BackTrace** | 三网回程路由测试，自动检测架构下载对应二进制 | 30 |
| **SuperTrace** | 老鬼出品，三网回程路由到 12 个国内核心节点 | 31 |
| **BestTrace** | IPIP.net 出品，交互式输入目标 IP 进行回程路由测试 | 32 |
| **mPing** | 一键 Ping 10 个国内节点 + 三网路由跟踪 | 33 |

### 其他工具

| 脚本 | 简介 | Menu 编号 |
|------|------|:---------:|
| **PrettyPing** | 美化版 ping 命令，带彩色图示 | 34 |

> 直接执行示例：`bash <(wget -qO- https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/VPSTest/ecss-bench.sh)`

---

## 系统清理

一键清理 Linux 系统垃圾：

```bash
curl -sSL https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/Cleaner/LinuxClean.sh | bash
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

| 脚本 | 说明 | Menu 编号 |
|------|------|:---------:|
| **Server 基础环境** | 换 APT 源(中科大镜像)、安装 SSH/sudo/vim/git 等基础工具、配置用户和 systemd | 10 |
| **X11 图形栈** | 安装 Xorg/Xvfb/pulseaudio/XRDP/x11vnc/NoMachine 远程桌面，配置 VNC 和 NX 协议 | 11 |

### 桌面环境选择

| 桌面 | 特点 | Menu 编号 |
|------|------|:---------:|
| **Deepin / GXDE** | 中文友好、易用美观 | 12 |
| **KDE Plasma** | 高度可定制、功能全面 | 13 |
| **KDE Lingmo** | KDE 国风变体、界面现代 | 14 |
| **Xfce** | 资源占用低、稳定流畅 | 15 |
| **GNOME 3** | 简洁现代、工作流导向 | 16 |
| **MATE** | 传统菜单与窗口风格、稳定耐用 | 17 |

> 直接执行示例：`curl -sSL https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/Desktop/LXC-Debian-Deepin.sh | bash -e`

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

3X-UI 是 Xray-core 的 Web 管理面板，支持多协议、多用户管理。Menu 编号 `3`。

```bash
bash <(curl -sSL https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/Tunnels/3x-ui/x-ui.sh)
```

也可以通过 Docker Compose 部署（使用 host 网络模式）：

```bash
# 下载 docker-compose.yml 后启动
docker compose up -d
```

---

## 反向代理（Caddy / Nginx）

主菜单「7. 反向代理」不会先让你选引擎：脚本按「正在运行的进程 → 上次选择 → 已安装的那个」自动判断，直接进入站点管理；只有两个都装了又没有运行时才让你选。也可以直接进入：

```bash
bash Menu.sh reverseproxy
```

进入菜单本身**不会安装、启动或停止任何服务**，只有选择“安装”或改动站点时才写配置并重载。两个后端都会监听 80/443，**同一时间只能运行一个**；切换在「9. 引擎设置 → 切换引擎」里完成，站点配置不会自动迁移。

Caddy 与 Nginx 共用同一套编号：

| 编号 | 功能 |
|---|---|
| 1 | 站点列表（域名、上游、TLS、启用状态、端口） |
| 2 | 新增站点（域名 + 上游 + 证书方式） |
| 3 | 编辑站点（域名 / 上游 / TLS / 端口，直接回车保留原值） |
| 4 | 删除站点 |
| 5 | 启用 / 停用（配置保留，只是不再渲染与重载） |
| 6 | 连通性测试（从本机按域名回环，输出上游与站点的 HTTP 状态码） |
| 7 | 证书管理（列表含到期时间、上传、ACME、续期、删除） |
| 8 | 服务管理（状态 / 启停 / 重载 / 开机自启 / 日志） |
| 9 | 引擎设置（状态、切换引擎、配置校验、卸载） |

### Caddy 管理

安装与升级：自动识别 `amd64 / arm64 / armv7 / 386` 架构，从官方 Release 下载（走镜像加速），注册为托管服务（PM2 > systemd > nohup 自适应），支持开机自启与一键升级。

站点与证书：

- 站点以片段形式保存在 `/etc/caddy/pika/sites/*.caddy`，主 Caddyfile 仅保留全局配置与 `import`
- 新增站点：域名（多个用逗号分隔）、上游（支持多个做负载均衡）、证书模式、附加 Caddyfile 指令
- 证书模式：自动 HTTPS（需 80/443 公网可达）、手动证书、`tls internal` 自签名、纯 HTTP
- 证书管理：上传（文件路径或直接粘贴 PEM，配对校验 + SAN 解析）、acme.sh 交互申请、续期、列表与删除
- 每次变更前备份到 `/etc/caddy/pika/backups/`，`caddy validate` 失败自动回滚

### Nginx 管理

安装：使用发行版软件包（Debian/Ubuntu/RHEL/Alpine 等），自动确保 `nginx.conf` 引入 `/etc/nginx/conf.d/*.conf`；非 systemd 环境通过托管服务以 `daemon off` 方式运行。

站点与证书：

- 所有站点统一生成到 `/etc/nginx/conf.d/pika.conf`，元数据保存在 `/etc/pika-sh/nginx/meta/`
- 生成内容包含 `upstream` 负载均衡、WebSocket 头、ACME Webroot 目录与 HTTP→HTTPS 跳转
- 证书模式：自动 HTTPS（acme.sh HTTP-01 Webroot，需 80 端口）、手动证书、openssl 自签名、纯 HTTP
- 证书管理：上传（文件路径或直接粘贴 PEM，配对校验 + SAN 解析）、acme.sh 交互申请（独立/Webroot/TLS-ALPN/DNS 手动）、续期、删除
- 每次变更前备份到 `/etc/pika-sh/nginx/backups/`，`nginx -t` 失败自动回滚

> 证书「上传」有三种输入方式，提示里会直接写明：**直接回车用编辑器粘贴（推荐）**、直接粘贴 PEM、输入文件路径。私钥是多行文本，部分终端会把整段粘贴当成一行送进来，所以私钥请走编辑器：回车后脚本用 `$EDITOR`/`nano`/`vim` 打开目标文件，粘贴完整内容保存退出即可，脚本会自动校验 `-----BEGIN`/`-----END` 块、清掉 CRLF 与多余空行。直接粘贴仍可用，以 `-----BEGIN` 开头、粘完按一次回车；多段连续的 `BEGIN CERTIFICATE` 会一起保存，证书链不会丢。导入前会做配对校验（证书与私钥是否匹配）并从 SAN 取域名，没有 SAN 时回退到 CN。
>
> 证书「续期」只对 acme.sh 签发的证书生效：脚本会调用 `acme.sh --renew --force`，再把新证书装回本工具的证书目录并重载服务；手动上传的证书没有可续期的上游，会提示重新上传。DNS 手动模式仍会带上 `--yes-I-know-dns-manual-mode-enough-go-ahead-please` 开关。
>
> 服务「开机自启」按托管方式落地：systemd 用 `systemctl enable/disable`，容器 nohup 用 `/run.sh` 里的一行启动命令；PM2 托管时自启由 `pm2 startup` + `pm2 save` 统一管理，菜单会直接说明而不做单项开关。

> DNS 手动模式无需 80 端口，适合端口受限的机器；但无法自动续期，需在到期前重新申请。Caddy 自动证书存放在 `/etc/caddy/pika/certs/`，Nginx 证书存放在 `/etc/pika-sh/nginx/certs/`；删除前会检查是否被站点引用。

---

## 组网与中转服务

Setup.sh 菜单中集成了以下组网/中转工具：

| 服务 | 默认端口 | 说明 |
|------|----------|------|
| **EasyTier** | 配置自定义 | 去中心化 P2P 组网，PM2 托管 |
| **RustDesk 中转** | 21116 (TCP/UDP) / 21117 (TCP) | 远程桌面中继服务器（hbbs + hbbr） |
| **ZeroTier** | 1048 (UDP) | 虚拟局域网组网 |
| **Tailscale** | 1049 | WireGuard 组网，支持出口节点/子网路由 |
