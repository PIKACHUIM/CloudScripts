# Service Management

PIKA SH 使用统一的服务托管抽象层，支持 PM2、systemd、nohup 三种后端。

## 后端选择

| 后端 | 适用场景 | 特点 |
|------|----------|------|
| **PM2** (推荐) | Node.js 服务、通用进程管理 | 自动重启、日志管理、集群支持 |
| **systemd** | 传统 Linux 服务 | 系统原生、开机自启、日志整合 |
| **nohup** | 容器/最小化环境 | 零依赖、兼容所有环境 |

## 自动选择规则

1. 显式参数：`--backend=pm2` 或 `--backend=systemd`
2. 持久化配置：`/etc/pika-sh/config` 中的 `service_backend` 键
3. 自动探测：
   - PM2 已安装 → 使用 PM2
   - 有 `/run/systemd/system` → 使用 systemd
   - 容器/最小化环境 → 使用 nohup

## 交互式切换

首次安装服务时会弹出选择，也可手动切换：

```bash
# 在菜单中选择
bash Menu.sh 7  # System Tools
# 选择服务管理...
```

## 统一操作

```bash
# 所有服务使用统一的命令接口
pika-svc start <name>
pika-svc stop <name>
pika-svc restart <name>
pika-svc status <name>
pika-svc logs <name>
pika-svc remove <name>
```

## 容器环境说明

在 Docker/LXC/WSL 等容器环境中，systemd 通常不可用，系统会自动降级到 nohup 模式。
