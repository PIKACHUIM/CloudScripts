# Windows 脚本

Windows 脚本提供容器引擎安装和系统激活两大功能。

> 💡 **在 Git Bash / MSYS2 中运行 Menu.sh 将自动显示 PowerShell 命令**，无需手动记忆。

---

## 容器引擎安装

### Docker CE 引擎

安装 Docker Community Edition（社区版），支持 Hyper-V 和 Native 两种运行时模式。

```powershell
# 以管理员身份运行 PowerShell
irm https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/WinNT/Docker/Winx86-dockerce.ps1 | iex
```

#### Hyper-V 运行时（默认）

- ✅ 支持 Linux 和 Windows 容器
- ⚠️ 需要在 BIOS 中开启 VT-D 和 VT-X
- ⚠️ 需要在「启用或关闭 Windows 功能」中启用 Hyper-V

#### 切换到 Native 运行时

```powershell
& $Env:ProgramFiles\Docker\Docker\DockerCli.exe -SwitchDaemon .
```

- ✅ 无需 VT 虚拟化
- ✅ 性能损失小
- ⚠️ 仅支持 Windows 原生容器

---

### Nerdctl 引擎

安装 Nerdctl + Containerd 容器运行时。

::: danger 注意
安装完成后会自动重启系统，请提前保存未保存的文件！
:::

```powershell
irm https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/WinNT/Docker/Winx86-nerdctls.ps1 | iex
```

#### 安装后优化

##### 1. 兼容 Docker 命令

复制 nerdctl.exe 为 docker.exe，即可直接使用 `docker` 命令：

```powershell
copy "C:\Program Files\nerdctl\nerdctl.exe" "C:\Program Files\nerdctl\docker.exe"
```

##### 2. 迁移数据目录

默认使用 `C:\ProgramData\containerd\` 作为容器目录，可能占用 C 盘空间。

编辑 `C:\Program Files\containerd\config.toml`：

```toml
root = "D:\\Nerd\\root"          # 修改此处
state = "D:\\Nerd\\state"        # 修改此处

[plugins."io.containerd.internal.v1.opt"]
  path = "D:\\Nerd\\root\\opt"   # 修改此处
```

然后停止服务、清理并迁移数据：

```powershell
# 停止并清理旧容器
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)
docker rmi $(docker images -q)
net stop containerd
tskill containerd

# 迁移数据
mkdir "D:\Nerd"
xcopy "C:\ProgramData\containerd\" "D:\Nerd\" /E /H /C /I /Y

# 重启服务
net start containerd
```

---

### Mirantis 容器运行时

安装 Mirantis Container Runtime，安装后自动重启。

```powershell
irm https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/WinNT/Docker/Winx86-mirantis.ps1 | iex
```

---

## 系统激活

### MAS (Microsoft Activation Scripts)

全合一 Windows/Office 激活脚本（v3.10），来自 [massgrave.dev](https://massgrave.dev/) 项目。

```powershell
# 以管理员身份运行
irm https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/WinNT/Active/MAS_AIO.cmd | iex
```

支持功能：

| 功能 | 说明 |
|------|------|
| HWID 激活 | Windows 10/11 永久数字许可证激活 |
| Ohook 激活 | Office 永久激活 |
| KMS38 激活 | Windows 激活至 2038 年 |
| Online KMS | 在线 KMS 激活 Windows/Office |
| 激活状态检查 | 查看当前系统激活状态 |
| 故障排除 | 修复常见激活问题 |

---

## 前置条件汇总

| 脚本 | 操作系统要求 | 其他要求 |
|------|-------------|----------|
| Docker CE | Windows 10 Pro/Enterprise 或 Windows Server 2016+ | Hyper-V 模式需 VT-x/AMD-V |
| Nerdctl | Windows 10 / Windows Server 2016+ | 无需虚拟化 |
| Mirantis | Windows 10 / Windows Server 2016+ | - |
| MAS 激活 | Windows 10/11 / Office 2016+ | 管理员权限 |

::: warning 安全提醒
- 所有 Windows 脚本都需要**以管理员身份运行 PowerShell**
- 安装容器引擎前建议创建系统还原点
- MAS 激活脚本来自开源社区，使用时请遵守软件许可协议
:::
