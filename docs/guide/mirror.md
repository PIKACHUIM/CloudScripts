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
| `/var/cache/pika-sh/modules/` | 已下载的模块，超过 24 小时会在下次启动时清理 |

清除缓存以强制重新探测：

```bash
rm -f /var/cache/pika-sh/site.conf /var/cache/pika-sh/mirror.conf
```

## 自建镜像

1. Fork 本仓库。
2. 启用 GitHub Pages 或部署到 EdgeOne Pages。
3. 确保站点根目录存在 `.pika-healthz`（内容需包含 `PIKA_SH_OK`），或 `pika-healthz.txt`。
4. 保持目录结构与仓库一致（`Menu.sh`、`Linux/`、`WinNT/` 位于站点根目录）。
5. 使用时通过 `--mirror=https://你的域名` 指定。

> 仓库自带 `scripts/build-site.mjs`，会把 VitePress 站点、`Menu.sh`、`Linux/`、`WinNT/` 和探针文件一起输出到 `_site/`，GitHub Actions 与 EdgeOne Pages 都调用同一个脚本，自建镜像可以直接复用。
