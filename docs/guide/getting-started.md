# 快速开始

本指南将帮助你快速上手使用 CloudScripts 脚本平台。

## 基本用法

CloudScripts 的所有脚本都通过 CDN 托管，你需要做的只是**复制命令，粘贴到终端执行**。

### Linux 执行方式

在 Linux 终端中，使用 `bash` 配合 `curl` 或 `wget` 执行脚本：

```bash
# 使用 curl
bash <(curl -sSL https://gh-bat.pika.net.cn/脚本路径)

# 使用 wget
bash <(wget -qO- https://gh-bat.pika.net.cn/脚本路径)
```

### Windows 执行方式

在 **PowerShell（管理员模式）** 中执行：

```powershell
irm https://gh-bat.pika.net.cn/WinNT/脚本路径 | iex
```

## 前置要求

### Linux 环境

- **操作系统**：Debian 9+ / Ubuntu 18.04+ / CentOS 7+ / Rocky Linux / AlmaLinux
- **权限**：建议使用 `root` 用户或具有 `sudo` 权限的用户
- **网络**：能够访问外网（脚本托管在 CDN 上）
- **依赖**：系统需预装 `curl` 或 `wget`（绝大多数发行版默认包含）

### Windows 环境

- **操作系统**：Windows 10 / Windows Server 2016 及以上
- **权限**：以**管理员身份**运行 PowerShell
- **网络**：能够访问外网
- **虚拟化**（Docker 脚本）：如需使用 Hyper-V 模式，需在 BIOS 中启用 VT-D/VT-X 并在 Windows 功能中启用 Hyper-V

## 快速示例

### 示例 1：VPS 到手即测

拿到一台新 VPS 后，运行综合测评脚本：

```bash
# 融合怪综合测评（最全面的一体化测试）
bash <(wget -qO- https://gh-bat.pika.net.cn/Linux/VPSTest/ecss-bench.sh)

# 或者使用秋水逸冰的 Bench.sh（简单快速）
bash <(wget -qO- https://gh-bat.pika.net.cn/Linux/VPSTest/qsyb-bench.sh)
```

### 示例 2：一键部署代理和面板

```bash
# 运行交互式部署脚本，按需选择要安装的模块
bash <(curl -sSL https://gh-bat.pika.net.cn/Linux/VPSSets/Setup.sh)
```

脚本提供以下可选模块（安装时可自由勾选）：

| 模块 | 说明 |
|------|------|
| 系统初始化 | 更新系统、安装常用工具 |
| ProxyChains4 | 配置 SOCKS5 代理链 |
| Node.js (LTS) | 通过 NVM 安装 Node.js + PM2 |
| 宝塔面板 | 自动安装并配置宝塔面板 |
| 哪吒探针 | 安装哪吒监控 Agent |
| 3X-UI 面板 | 安装 Xray-core 管理面板 |
| EasyTier | 部署组网服务 |
| FRP Panel | 安装 frp 内网穿透面板 |
| 端口限速 | 使用 tc + IFB 进行流量控制 |

### 示例 3：LXC 容器安装桌面

```bash
# 1. 先安装基础环境和图形栈
curl -sSL https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Server.sh | bash -e
curl -sSL https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Graphy.sh | bash -e

# 2. 选择一个桌面环境安装（以 Xfce 轻量桌面为例）
curl -sSL https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Xfce4L.sh | bash -e
```

### 示例 4：Windows 安装 Docker

```powershell
# 以管理员身份运行 PowerShell
irm https://gh-bat.pika.net.cn/WinNT/Docker/Winx86-dockerce.ps1 | iex
```

## 注意事项

- ⚠️ 在执行脚本前，建议先阅读对应脚本的说明文档
- ⚠️ `Setup.sh` 部署脚本的敏感信息已加密，运行时需要输入部署密码
- ⚠️ 部分脚本（如 Windows Docker 安装）执行后会自动重启系统，请提前保存工作
- ⚠️ 桌面环境安装脚本专为 LXC 容器设计，物理机上使用可能需要调整

## 下一步

- 查看 [Linux 脚本详细说明](/guide/linux-scripts)
- 查看 [Windows 脚本详细说明](/guide/windows-scripts)
- 了解 [安全机制说明](/guide/security)
