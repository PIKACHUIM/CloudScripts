#!/bin/bash
#From https://github.com/oneclickvirt/gostun
#2024.06.24

rm -rf /usr/bin/gostun
rm -rf gostun
os=$(uname -s)
arch=$(uname -m)

case $os in
  Linux)
    case $arch in
      "x86_64" | "x86" | "amd64" | "x64")
        wget -O gostun https://benchs.pika.net.cn/ecss-bench/gostun-linux-amd64
        ;;
      "i386" | "i686")
        wget -O gostun https://benchs.pika.net.cn/ecss-bench/gostun-linux-386
        ;;
      "armv7l" | "armv8" | "armv8l" | "aarch64" | "arm64")
        wget -O gostun https://benchs.pika.net.cn/ecss-bench/gostun-linux-arm64
        ;;
      *)
        echo "Unsupported architecture: $arch"
        exit 1
        ;;
    esac
    ;;
  Darwin)
    case $arch in
      "x86_64" | "x86" | "amd64" | "x64")
        wget -O gostun https://benchs.pika.net.cn/ecss-bench/gostun-darwin-amd64
        ;;
      "armv7l" | "armv8" | "armv8l" | "aarch64" | "arm64")
        wget -O gostun https://benchs.pika.net.cn/ecss-bench/gostun-darwin-arm64
        ;;
      *)
        echo "Unsupported architecture: $arch"
        exit 1
        ;;
    esac
    ;;
  FreeBSD)
    case $arch in
      amd64)
        wget -O gostun https://benchs.pika.net.cn/ecss-bench/gostun-freebsd-amd64
        ;;
      "i386" | "i686")
        wget -O gostun https://benchs.pika.net.cn/ecss-bench/gostun-freebsd-386
        ;;
      "armv7l" | "armv8" | "armv8l" | "aarch64" | "arm64")
        wget -O gostun https://benchs.pika.net.cn/ecss-bench/gostun-freebsd-arm64
        ;;
      *)
        echo "Unsupported architecture: $arch"
        exit 1
        ;;
    esac
    ;;
  OpenBSD)
    case $arch in
      amd64)
        wget -O gostun https://benchs.pika.net.cn/ecss-bench/gostun-openbsd-amd64
        ;;
      "i386" | "i686")
        wget -O gostun https://benchs.pika.net.cn/ecss-bench/gostun-openbsd-386
        ;;
      "armv7l" | "armv8" | "armv8l" | "aarch64" | "arm64")
        wget -O gostun https://benchs.pika.net.cn/ecss-bench/gostun-openbsd-arm64
        ;;
      *)
        echo "Unsupported architecture: $arch"
        exit 1
        ;;
    esac
    ;;
  *)
    echo "Unsupported operating system: $os"
    exit 1
    ;;
esac

chmod 777 gostun
cp gostun /usr/bin/gostun
