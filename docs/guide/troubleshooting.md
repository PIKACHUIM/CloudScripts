# Troubleshooting

常见问题及解决方案。

## 下载通道全部不可用

**症状**：启动时提示"所有代理通道不可用"

**解决**：
1. 检查网络连通性：`curl -I https://benchs.pika.net.cn/.pika-healthz`
2. 清除缓存重试：`rm /var/cache/pika-sh/mirror.conf`
3. 使用 VPN/代理临时解决
4. 强制指定可用通道：`bash Menu.sh --mirror=https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main`

## 依赖安装失败

**症状**：apt/yum install 报错

**解决**：
1. 手动更新包索引：`sudo apt update` 或 `sudo dnf makecache`
2. 检查磁盘空间：`df -h`
3. 确认发行版支持：Debian 9+/Ubuntu 18.04+/CentOS 7+/AlmaLinux/Rocky/Fedora/Alpine/Arch
4. 查看详细错误日志

## 桌面安装重复/失败

**症状**：提示"已经安装过桌面"

**解决**：
1. 清除安装状态标记：`rm /etc/lxc-de-flag`
2. 重新运行桌面安装脚本
3. 如果安装中断，可能需要手动安装依赖

**症状**：curl|bash 执行后立即退出

**解决**：
> 此问题已在 v1.0 修复。scripts 现在支持本地文件和远程执行两种模式。
> 如果使用旧版本，请更新到最新版。

## 内核换完无法引导

**症状**：安装 XanMod/Liquorix 内核后系统无法启动

**解决**：
1. VPS 面板切换到 Emergency/Rescue 模式
2. 挂载磁盘，chroot 后卸载新内核
3. 确认 CPU 支持的 x86-64 级别：
   ```bash
   grep -q 'avx512f' /proc/cpuinfo && echo "v4" || \
   grep -q 'avx2' /proc/cpuinfo && echo "v3" || \
   grep -q 'sse4_2' /proc/cpuinfo && echo "v2" || echo "v1"
   ```

## RustDesk 服务无法启动

**症状**：systemctl status rustdesk 显示 syntax error

**解决**：
> 此问题已在 v1.0 修复。旧版本 systemd unit 文件中使用了 `;` 分隔多命令，
> systemd 的 ExecStart 不支持此语法。新版本使用每行一个 `ExecStart` 指令。
> 如果使用旧版本，请更新到最新版并重新安装服务。

## nohup 服务在容器重启后消失

**症状**：容器重启后 nohup 管理的服务不再运行

**解决**：切换到 PM2 管理：
```bash
bash Menu.sh --backend=pm2
# 重新安装需要的服务
```

## 其他问题

如上述方法无法解决，请在 GitHub Issues 中提交：
1. 操作系统和版本：`cat /etc/os-release`
2. 内核版本：`uname -r`
3. 错误信息截图/日志
4. 使用的具体命令
