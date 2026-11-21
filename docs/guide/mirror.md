# 镜像通道

PIKA SH 的脚本同时部署在**国内**和**海外**两个域名上，内容完全一致。脚本每次启动都会自动挑选当前网络下可用的那一个，因此国内服务器不会被海外线路拖住，海外服务器也不会卡在国内线路上。

## 双线路

| 域名 | 托管平台 | 推荐场景 |
|:-----|:---------|:---------|
| `https://pikash.pika.net.cn` | 腾讯 EdgeOne Pages | 中国大陆服务器 |
| `https://pikash.opkg.cn` | GitHub Pages | 海外服务器、CI 环境 |
| `https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main` | GitHub 源站 | 前两者都不可用时的兜底 |

## 启动时的选择过程

1. 若使用 `--mirror=URL` 或设置了 `PIKA_MIRROR` 环境变量，直接采用，不再探测。
2. 读取 `/var/cache/pika-sh/site.conf`，若缓存不超过 24 小时且探针仍通过，直接复用。
3. 否则**并发**探测两个域名，取最先响应的一个，并写入缓存。
4. 两者都不通时回退到 GitHub 源站；全部失败会打印明确错误并退出，不会无限等待。

探针请求同时校验 HTTP 状态码与响应中的 `PIKA_SH_OK` 特征串，避免 DNS 污染返回的伪页面被误判为可用。部分静态托管会忽略 `.pika-healthz` 这类点开头的文件，因此站点同时提供 `pika-healthz.txt` 作为备用探针路径。

## 超时策略

所有自有域名的请求都带上限，因此最坏情况是「几秒后切换」而不是「一直卡住」：

| 操作 | 连接超时 | 总时长上限 |
|:-----|:---------|:-----------|
| 探针 | 2s | 4s |
| 库 / 模块 / 语言包 | 2–3s | 10–20s |
| 大文件（测评工具等） | 5s | 60s |

相对路径下载失败后，会依次再试**另一个域名**和 GitHub 源站，所以单条线路故障不会让整个菜单报错。

## GitHub 加速（国内 VPS）

脚本自身走双线路，但安装组件时仍要访问 GitHub（Release 二进制、`raw.githubusercontent.com` 上的安装脚本）。这些请求采用「**直连优先 + 加速兜底**」：

1. 先直连 GitHub，连接超时 5s；本身就快的机器不会产生额外开销。
2. 直连失败才并发探测加速前缀，取最先通过健康检查的一个，结果缓存 24 小时。

内置加速前缀（按顺序探测，全部为前缀式，即 `加速前缀 + 原始 GitHub URL`）：

| 加速前缀 | 说明 |
|:---------|:-----|
| `https://ghfast.top/` | 常用 GitHub 代理 |
| `https://gh-proxy.com/` | 常用 GitHub 代理 |
| `https://ghproxy.net/` | 备用代理 |
| `https://github.524228.xyz/` | 项目自有代理 |

被加速的下载包括：

- 各组件的一键安装脚本（Lucky、Sun-Panel、OpenList、Aria2 Pro、NPS、FileBrowser、1Panel、宝塔、哪吒、3x-ui 等）
- Caddy 二进制 Release、`get.acme.sh`
- XanMod / Liquorix 内核脚本、BBRPlus 脚本
- `pika_fetch` 调用的任意 GitHub 地址，失败后会自动逐个前缀重试

加速只作用于 GitHub 域名，不会改写其他站点；可用 `bash Menu.sh --no-accel` 完全关闭。

## 组件源加速

除 GitHub 之外，另外三处也做了国内适配（在「主菜单 → 8. 系统工具 → 5. 国内网络加速」中可一键配置）：

| 项目 | 默认行为 | 说明 |
|:-----|:---------|:-----|
| 系统软件源 | 菜单手动切换 | Debian/Ubuntu（含 deb822）、Alpine、Rocky/AlmaLinux/CentOS/Fedora 切到清华 TUNA，原文件备份为 `*.pika.bak.<时间戳>` |
| Docker 安装 | 官方脚本 + 阿里云源兜底 | 失败再退回发行版软件包；安装后自动写入 `registry-mirrors` |
| 容器镜像 | 自动 | `ghcr.io` / `quay.io` / `gcr.io` / `registry.k8s.io` 拉取失败时改用 daocloud 镜像并重新打 tag |
| npm / pip | `registry.npmmirror.com` / 清华 PyPI | Node.js 走 npmmirror 镜像下载 |

## 手动指定通道

```bash
# 强制使用国内线路
bash Menu.sh --mirror=https://pikash.pika.net.cn

# 强制使用海外线路
bash Menu.sh --mirror=https://pikash.opkg.cn
```

## 缓存文件

| 文件 | 作用 |
|:-----|:-----|
| `/var/cache/pika-sh/site.conf` | 启动时选中的站点（第一行 URL，第二行时间戳） |
| `/var/cache/pika-sh/mirror.conf` | 库内部使用的镜像通道缓存 |
| `/var/cache/pika-sh/gh-proxy.conf` | 选中的 GitHub 加速前缀（第一行前缀，第二行时间戳） |
| `/var/cache/pika-sh/modules/` | 已下载的模块，超过 24 小时会在下次启动时清理 |

清除缓存以强制重新探测：

```bash
rm -f /var/cache/pika-sh/site.conf /var/cache/pika-sh/mirror.conf /var/cache/pika-sh/gh-proxy.conf
```

## 自建镜像

1. Fork 本仓库。
2. 启用 GitHub Pages 或部署到 EdgeOne Pages。
3. 确保站点根目录存在 `.pika-healthz`（内容需包含 `PIKA_SH_OK`），或 `pika-healthz.txt`。
4. 保持目录结构与仓库一致（`Menu.sh`、`Linux/`、`WinNT/` 位于站点根目录）。
5. 使用时通过 `--mirror=https://你的域名` 指定。

> 仓库自带 `scripts/build-site.mjs`，会把 VitePress 站点、`Menu.sh`、`Linux/`、`WinNT/` 和探针文件一起输出到 `_site/`，GitHub Actions 与 EdgeOne Pages 都调用同一个脚本，自建镜像可以直接复用。
