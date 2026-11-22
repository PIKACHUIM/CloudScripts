---
layout: home

hero:
  name: PIKA SH
  text: 皮卡在线脚本托管平台
  tagline: 一行命令搞定部署、测评、维护与反向代理，国内 / 海外双线路自动选优
  image:
    src: /logo.svg
    alt: PIKA SH
  actions:
    - theme: brand
      text: 快速开始
      link: /guide/getting-started
    - theme: alt
      text: 脚本清单
      link: /guide/linux-scripts
    - theme: alt
      text: GitHub
      link: https://github.com/PIKACHUIM/CloudScripts

features:
  - icon: 🚀
    title: 一行即用
    details: 无需克隆仓库，curl 一行拉起总菜单，按编号执行即可。所有脚本同时可通过 URL 单独调用。
  - icon: 🌏
    title: 双线路自动选优
    details: pikash.pika.net.cn（国内 EdgeOne）与 pikash.opkg.cn（海外）互为备份，启动时并发探测、就近取用，结果缓存 24 小时。
  - icon: ⏱️
    title: 全程超时保护
    details: 每个请求都带连接与总时长上限，线路不可达时几秒内切换，不会出现脚本卡死不动的情况。
  - icon: 🐧
    title: Linux 全覆盖
    details: 部署、维护、桌面环境、性能测评、代理组网、反向代理六大类，覆盖 Debian/Ubuntu/RHEL/Alpine 等主流发行版。
  - icon: 🛡️
    title: 反向代理二选一
    details: Caddy 与 Nginx 任选其一，一键安装、站点增删、手动或 ACME 证书管理，切换后端时自动停用另一个。
  - icon: 🔒
    title: 开源透明
    details: 全部代码在 GitHub 开源，GNU GPL v3 + MIT 双许可，脚本内容可直接审阅，敏感信息加密存储。
---

## 一行安装

::: code-group

```bash [国内线路]
bash <(curl -fsSL https://pikash.pika.net.cn/Menu.sh)
```

```bash [海外线路]
bash <(curl -fsSL https://pikash.opkg.cn/Menu.sh)
```

:::

两个域名提供完全相同的目录结构，任选其一即可。如果所在网络无法访问某个域名，加 `--mirror` 手动指定另一个：

```bash
bash <(curl -fsSL https://pikash.pika.net.cn/Menu.sh) --mirror=https://pikash.opkg.cn
```

启动时脚本会并发探测两条线路，取最先响应的一个，并把结果写入 `/var/cache/pika-sh/site.conf`（有效期 24 小时）。线路全部不可达时会给出明确提示，而不是一直等待。详见[镜像通道](/guide/mirror)。

## 双线路一览

| 域名 | 托管平台 | 推荐场景 |
|:-----|:---------|:---------|
| `pikash.pika.net.cn` | 腾讯 EdgeOne Pages | 中国大陆服务器，直连速度快 |
| `pikash.opkg.cn` | GitHub Pages | 海外服务器、GitHub Actions 等环境 |
| `raw.githubusercontent.com` | GitHub 源站 | 前两者均不可用时的兜底 |

> 国内与海外服务器互相访问对方线路时经常超时，脚本因此不会固定使用某一个域名，而是每次启动时实测。

## 功能分类

| 分类 | 主要内容 |
|:-----|:---------|
| 🖥️ 部署安装 | 换源、面板、探针、Docker/Podman、内网穿透 |
| 🔧 系统维护 | 内核与 BBR、Swap、防火墙、清理、重装、监控 |
| 🎨 桌面环境 | Debian LXC 容器内的 8 种图形桌面 |
| 📊 性能测评 | 融合怪、YABS、UnixBench、IP 质量、路由追踪等 |
| 📦 软件安装 | 网络穿透、面板监控、建站媒体、存储协作、账号安全、AI 开发、阅读工具 |
| 🌐 代理组网 | 3X-UI、Clash、Hysteria2、WireGuard、Tailscale 等 |
| 🛡️ 反向代理 | Caddy / Nginx 二选一，站点与证书统一管理 |
| 🛠️ 系统工具 | SSH 加固、时区、主机名、自更新、卸载回滚 |

## 文档入口

- [快速开始](/guide/getting-started) — 安装方式、前置要求、常见用法
- [Linux 脚本](/guide/linux-scripts) — 每个脚本的用途与调用方式
- [Windows 脚本](/guide/windows-scripts) — Docker、Nerdctl、激活工具
- [镜像通道](/guide/mirror) — 双线路探测、缓存与自建镜像
- [故障排除](/guide/troubleshooting) — 下载失败、服务异常等问题排查
