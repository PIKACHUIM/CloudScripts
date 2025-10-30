# 皮卡在线脚本托管平台

## Linux脚本

### 服务器测评脚本

| 脚本            | 简介                                                         | 使用命令                                                     |
| --------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| BackTrace       | 三网回程路由测试                                             | `bash <(wget -qO- gh-bat.pika.net.cn/Linux/VPSTest/back-trace.sh)` |
| ECSScript       | 融合怪测评脚本                                               | `bash <(wget -qO- gh-bat.pika.net.cn/Linux/VPSTest/ecss-bench.sh)` |
| UnixBench.sh    | 一个类unix系统下的性能测试工具                               | `bash <(wget -qO- gh-bat.pika.net.cn/Linux/VPSTest/unix-bench.sh)` |
| Bench.sh        | 秋水逸冰大佬的写的Bench.sh脚本                               | `bash <(wget -qO- gh-bat.pika.net.cn/Linux/VPSTest/qsyb-bench.sh)` |
| SuperSpeed      | 使用全国各地三大运营的 speedtest 测速节点进行全面测速        | `bash <(wget -qO- gh-bat.pika.net.cn/Linux/VPSTest/superspeed.sh)` |
| SuperBench.sh   | 老鬼大佬的SuperBench测试脚本                                 | `bash <(wget -qO- gh-bat.pika.net.cn/Linux/VPSTest/superbench.sh)` |
| SuperTrace.sh   | 老鬼大佬的SuperTrace测试脚本                                 | `bash <(wget -qO- gh-bat.pika.net.cn/Linux/VPSTest/supertrace.sh)` |
| LemonBench.sh   | 一款针对Linux服务器设计的服务器性能测试工具                  | `bash <(wget -qO- gh-bat.pika.net.cn/Linux/VPSTest/lemonbench.sh)` |
| yabs.sh         | 一款跨平台的处理基准测试程序                                 | `bash <(wget -qO- gh-bat.pika.net.cn/Linux/VPSTest/yabs-bench.sh)` |
| besttrace4linux | 回程路由测试，[http://-IPIP.net](https://link.zhihu.com/?target=http%3A//-IPIP.net)出品 | `bash <(wget -qO- gh-bat.pika.net.cn/Linux/VPSTest/best-trace.sh)` |
| Speedtest-Cli   | 国外大佬Sivel作品                                            | `bash <(wget -qO- gh-bat.pika.net.cn/Linux/VPSTest/speed-test.py)` |
| PrettyPing.sh   | 基本用途相当于 ping 命令 附带了更美观精细地彩色图示          | `bash <(wget -qO- gh-bat.pika.net.cn/Linux/VPSTest/prettyping.sh)` |
| mPing.sh        | 方便测试回程Ping值 目前支持众多区域和各大运营商              | `bash <(wget -qO- gh-bat.pika.net.cn/Linux/VPSTest/mping-test.sh)` |
| IP-Quality.sh   | IP质量检测，整合多数据库风险评分与流媒体/邮件连通性检测      | `bash <(wget -qO- gh-bat.pika.net.cn/Linux/VPSTest/ip-quality.sh)` |

### 清理Linux 垃圾

```shell
apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Cleaner/LinuxClean.sh | bash
```

### 安装图形化桌面

- #### Debian 桌面安装

  1. 更换APT软件镜像源：

  ```shell
  sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list.d/debian.sources
  sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list
  apt update && apt upgrade
  ```
  
  2. 按下表选择对应命令：

  
  | 桌面/环境 | 简介 | 使用命令 |
  | --------- | ---- | -------- |
  | Server 基础环境 | 初始化系统与常用依赖，准备图形/桌面安装 | `apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Server.sh \| bash -e` |
  | X11 图形栈 | 安装 X11 与基础图形组件，为桌面打底 | `apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Graphy.sh \| bash -e` |
  | Deepin/GXDE 桌面 | 中文友好、易用美观的 Deepin 风格桌面（GXDE） | `apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Deepin.sh \| bash -e` |
  | KDE Plasma 桌面 | 高度可定制、功能全面的现代桌面 | `apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Plasma.sh \| bash -e` |
  | KDE Lingmo 桌面 | KDE 的国风变体，界面现代、整合优化 | `apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Lingmo.sh \| bash -e` |
  | Xfce 轻量桌面 | 资源占用低、稳定流畅，适合轻量环境 | `apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Xfce4L.sh \| bash -e` |
  | GNOME 3 桌面 | 简洁现代、工作流导向的桌面体验 | `apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Gnome3.sh \| bash -e` |
  | MATE 经典桌面 | 传统菜单与窗口风格，稳定耐用 | `apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-MateDE.sh \| bash -e` |
  
    

## WinNT脚本

### 1. Docker CE引擎

```PowerShell
irm https://gh-bat.pika.net.cn/WinNT/Docker/Winx86-dockerce.ps1 | iex
```

- #### 默认HyperV Runtime

  - 需要在BIOS中打开VT-D和VT-X
  - 需要在[启用或关闭Windows功能]里面启用Hyper-V

- #### 切换Native Runtime

  - 优点：无需VT虚拟化，性能损失小
  - 缺点：只支持Windows原生容器


```PowerShell
& $Env:ProgramFiles\Docker\Docker\DockerCli.exe -SwitchDaemon .
```

### Nerdctl 引擎

*命令完成后会自动重启，请提前保存好未保存的文件！！！*

```PowerShell
irm https://gh-bat.pika.net.cn/WinNT/Docker/Winx86-nerdctls.ps1 | iex
```

- #### 优化操作

##### 1. 修改名称

优化后可以直接使用`docker`命令进行管理

```PowerShell
copy "C:\Program Files\nerdctl\nerdctl.exe" "C:\Program Files\nerdctl\docker.exe"
```

##### 2.修改路径

默认会使用`C:\ProgramData\containerd\`作为容器目录，会占用C盘空间
编辑`C:\Program Files\containerd\config.toml`

```toml
root = "D:\\Nerd\\root" # <-----------修改此处
state = "D:\\Nerd\\state" # <-----------修改此处
......

  [plugins."io.containerd.internal.v1.opt"]
    path = "D:\\Nerd\\root\\opt" # <-----------修改此处
```

然后删除所有镜像和容器关闭容器服务：

```PowerShell
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)
docker rmi $(docker images -q)
net stop containerd
tskill containerd
```

迁移文件数据：

```PowerShell
mkdir "D:\Nerd"
# move "C:\ProgramData\containerd\*" "D:\Nerd\" # <---建议不要移动而是复制
xcopy "C:\ProgramData\containerd\" "D:\Nerd\" /E /H /C /I /Y
```

启动容器服务

```PowerShell
net start containerd
```



