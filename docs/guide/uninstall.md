# Uninstall & Rollback

卸载 PIKA SH 及其管理的组件。

## 完整卸载

通过菜单卸载（推荐）：
```bash
bash Menu.sh 7 7  # System Tools > Uninstall
```

或手动执行：
```bash
# 停止所有 PIKA 管理的服务
systemctl stop aria2 2>/dev/null || true
systemctl disable aria2 2>/dev/null || true
pm2 kill 2>/dev/null || true

# 清理配置和缓存
rm -rf /etc/pika-sh
rm -rf /var/cache/pika-sh
rm -rf /run/pika-sh

# 清理标志文件
rm -f /etc/lxc-de-flag

# 清理快捷命令
rm -f /usr/local/bin/pika-menu
rm -f /usr/local/bin/p

# 清理 sysctl 配置
rm -f /etc/sysctl.d/99-pika-*.conf
sysctl --system

# 清理 systemd 服务文件
rm -f /etc/systemd/system/*.service
systemctl daemon-reload
```

## 部分卸载

### 仅卸载某个服务

```bash
# 卸载 RustDesk
systemctl stop rustdesk
systemctl disable rustdesk
rm /etc/systemd/system/rustdesk.service
systemctl daemon-reload

# 卸载 wg-easy
docker stop wg-easy
docker rm wg-easy
```

### 仅清除桌面安装状态

```bash
rm /etc/lxc-de-flag
```

### 仅卸载内核

```bash
# 列出已安装的内核
dpkg -l | grep linux-image

# 卸载特定内核（不要卸载当前运行的内核！）
apt remove --purge linux-image-X.X.X-xanmod1
update-grub
```

## 回滚

### 回滚内核

重启时在 GRUB 菜单中选择 "Advanced options" → 选择旧内核启动。

### 回滚系统变更

```bash
# 移除 BBR 配置
rm /etc/sysctl.d/99-pika-bbr.conf
sysctl --system

# 移除 Swap
swapoff /swapfile
rm /swapfile
sed -i '/\/swapfile/d' /etc/fstab
```

## 注意事项

- 卸载不会移除已安装的系统包（如 Docker、Node.js）
- 卸载不会删除用户数据
- 桌面安装的包需要手动清理
- 建议卸载前备份重要配置
