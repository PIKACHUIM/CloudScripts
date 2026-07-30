---
layout: home

hero:
  name: "CloudScripts"
  text: "皮卡在线脚本托管平台"
  tagline: 一站式服务器管理脚本，一行命令搞定部署、测评、清理、桌面安装
  actions:
    - theme: brand
      text: 快速开始
      link: /guide/getting-started
    - theme: alt
      text: 查看脚本
      link: /guide/linux-scripts

features:
  - icon: 🚀
    title: 一键执行
    details: 所有脚本托管在 CDN 上，通过 bash 或 irm 一行命令即可远程执行，无需克隆仓库，无需手动下载。
  - icon: 🐧
    title: Linux 全覆盖
    details: 涵盖 VPS 部署、性能测评、系统清理、图形桌面安装、代理面板部署、组网服务等 30+ 脚本。
  - icon: 🪟
    title: Windows 支持
    details: 提供 Docker CE、Nerdctl、Mirantis 容器引擎安装脚本，以及 Windows/Office 激活工具。
  - icon: 🔒
    title: 安全可靠
    details: 敏感信息使用 AES-256-CBC + PBKDF2 加密存储，运行时需密码验证。脚本代码完全开源透明。
  - icon: 📊
    title: 专业测评
    details: 集成融合怪、SuperBench、LemonBench、YABS、UnixBench 等 14 款行业标准测评工具，全面评估服务器性能。
  - icon: 🖥️
    title: 桌面环境
    details: 一行命令在 LXC/Debian 容器中安装 KDE Plasma、GNOME、Xfce、Deepin、MATE 等主流桌面环境。
---

## 平台概览

CloudScripts（皮卡在线脚本托管平台）是一个面向 **VPS 和服务器运维人员** 的实用脚本集合平台。它将常见的服务器管理操作整合为可通过一行命令远程执行的脚本，覆盖 **Linux** 和 **Windows** 两大平台。

### 脚本分类

| 分类 | 平台 | 脚本数量 | 典型用途 |
|------|------|----------|----------|
| 服务器部署 | Linux | 1 个交互式脚本 | 一键部署代理、探针、面板、组网等 |
| 性能测评 | Linux | 14 个独立脚本 | CPU/内存/磁盘/网络全面测试 |
| 系统清理 | Linux | 1 个脚本 | 清理日志、缓存、Docker 无用资源 |
| 桌面环境 | Linux | 8 个脚本 | LXC 容器中安装各类图形桌面 |
| 代理面板 | Linux | 3 个脚本 | 3X-UI (Xray-core) 安装/更新 |
| 容器引擎 | Windows | 3 个脚本 | Docker CE / Nerdctl / Mirantis |
| 系统激活 | Windows | 1 个脚本 | Windows/Office 激活 |

### 为什么选择 CloudScripts

- **零门槛上手**：复制一行命令粘贴到终端即可，无需学习复杂的安装步骤
- **CDN 加速**：脚本和二进制文件通过国内 CDN 分发，解决 GitHub 下载缓慢问题
- **多架构兼容**：自动检测 x86_64 和 ARM64 架构，下载对应二进制文件
- **开源透明**：全部代码在 GitHub 开源，GNU GPL v3 许可证，放心使用
