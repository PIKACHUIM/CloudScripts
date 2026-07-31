# Mirror / Network Acceleration

PIKA SH 使用多级下载通道回退机制，确保在中国大陆网络环境下也能正常下载所需资源。

## 通道优先级

1. **用户强制指定** - 通过 `--mirror=URL` 参数或 `PIKA_MIRROR` 环境变量指定
2. **自建加速站** - benchs.pika.net.cn (GitHub Pages，大陆可直连)
3. **备用加速站** - gh-vps.pika.net.cn, pikash.opkg.cn
4. **公共代理** - github.524228.xyz, ghfast.top, gh-proxy.com
5. **上游直连** - raw.githubusercontent.com (最慢)

## 抗污染探测

每个通道部署探针文件 `.pika-healthz`，探测时同时校验：
- HTTP 状态码为 200
- 响应内容包含 `PIKA_SH_OK` 特征串

这样可以防止 DNS 污染返回的伪页面被误判为可用通道。

## 缓存机制

探测结果缓存到 `/var/cache/pika-sh/mirror.conf`，有效期 24 小时。重新探测在以下情况触发：
- 超过 24 小时
- 缓存通道失效（快速校验不通过）
- 用户强制刷新

## 使用方法

```bash
# 强制指定通道
bash Menu.sh --mirror=https://benchs.pika.net.cn

# 查看当前使用的通道
cat /var/cache/pika-sh/mirror.conf

# 清除缓存强制重新探测
rm /var/cache/pika-sh/mirror.conf
```

## 搭建自建镜像

如需要搭建自己的加速镜像：

1. Fork 本仓库
2. 启用 GitHub Pages（Settings > Pages）
3. 在 Pages 根目录放置 `.pika-healthz` 文件，内容需包含 `PIKA_SH_OK`
4. 使用 Actions 自动同步上游
