# 皮卡在线脚本托管平台

## Linux脚本

### 清理Linux 垃圾

```shell
apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Cleaner/LinuxClean.sh | bash
```



### 安装图形化桌面

- #### Debian 桌面安装

  - ##### 更换APTS软件源

    ```shell
    sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list.d/debian.sources
    sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list
    apt update && apt upgrade
    ```
    
    

  - ##### 安装Server环境

    ```shell
    apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Server.sh | bash -e
    ```
  
    

  - ##### 安装X11GUI环境

    ```shell
    apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Graphy.sh | bash -e
    ```
  
    

  - ##### 安装DDE Deepin

    ```shell
    apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Deepin.sh | bash -e
    ```
  
    

  - ##### 安装KDE Plasma

    ```shell
    apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Plasma.sh | bash -e
    ```
  
    

  - ##### 安装KDE Lingmo

    ```shell
    apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Lingmo.sh | bash -e
    ```
  
    

  - ##### 安装ENV Xfce4L

    ```shell
    apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Xfce4L.sh | bash -e
    ```
  
    

  - ##### 安装ENV GNOME3

    ```shell
    apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Gnome3.sh | bash -e
    ```
  
    

  - ##### 安装ENV MateDE

    ```shell
    apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-MateDE.sh | bash -e
    ```
  
    

- #### Ubuntu 桌面安装



## WinNT脚本

### 1. 安装Docker Native Runtime



### 2. 安装Docker HyperV Runtime



