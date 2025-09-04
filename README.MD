# 皮卡在线脚本托管平台

## Linux脚本

### 1.安装图形化桌面

- #### Debian 桌面安装

  - ##### 更换APTS软件源

    ```shell
    sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list.d/debian.sources
    sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list
    apt update
    ```
    
    

  - ##### 安装Server环境

    ```shell
    apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Server.sh | bash
    ```
  
    

  - ##### 安装X11GUI环境

    ```shell
    apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Graphy.sh | bash
    ```
  
    

  - ##### 安装DDE Deepin

    ```shell
    apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Deepin.sh | bash
    ```
  
    

  - ##### 安装KDE Plasma

    ```shell
    apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Plasma.sh | bash
    ```
  
    

  - ##### 安装KDE Lingmo

    ```shell
    apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Lingmo.sh | bash
    ```
  
    

  - ##### 安装ENV Xfce4L

    ```shell
    apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Xfce4L.sh | bash
    ```
  
    

  - ##### 安装ENV GNOME3

    ```shell
    apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-GNOME3.sh | bash
    ```


  - 

###  2. Ubuntu 桌面安装



## WinNT脚本

### 1. 安装Docker Native Runtime



### 2. 安装Docker HyperV Runtime



