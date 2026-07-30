# 安全说明

CloudScripts 平台重视安全性，以下说明帮助您了解脚本的安全机制和安全使用方式。

---

## 敏感信息保护

### Setup.sh 加密机制

`Setup.sh` 部署脚本中涉及以下敏感信息时，使用 **AES-256-CBC + PBKDF2** 强加密：

- 代理认证信息（ProxyChains4 配置）
- 哪吒探针服务端密钥
- EasyTier 组网配置
- FRP Panel API 密钥
- 宝塔面板用户名和密码

这些信息在脚本中以 **BASE64 编码的密文** 形式存储，运行时需要输入部署密码进行解密。密码错误会立即退出，不会泄露任何配置信息。

### Vault.sh 加密工具

配套提供 `Vault.sh` 加密工具，用于离线生成加密后的配置值：

```bash
bash <(curl -sSL https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/VPSSets/Vault.sh)
```

工具会交互式引导输入各项敏感信息，输出加密后的 BASE64 字符串，直接粘贴到 `Setup.sh` 脚本中使用。

---

## 代码透明度

### 完全开源

所有脚本源代码在 GitHub 上完全公开，任何人都可以审查：

- 📂 仓库地址：[github.com/PIKACHUIM/CloudScripts](https://github.com/PIKACHUIM/CloudScripts)
- 📜 许可证：GNU General Public License v3（Linux 脚本）/ MIT License（Windows Docker 相关脚本）

### 直接查看脚本内容

由于脚本通过 GitHub Raw 直接分发，您可以随时查看原始代码：

```bash
# 在执行前先查看脚本内容
curl -sSL https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/VPSTest/ecss-bench.sh | less

# 或者下载到本地审查后再执行
wget https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/VPSTest/ecss-bench.sh
cat ecss-bench.sh  # 审查代码
bash ecss-bench.sh  # 确认无误后执行
```

---

## 使用建议

### 执行前

1. **审查代码**：在执行任何脚本前，建议先查看脚本内容
2. **备份数据**：涉及系统修改的脚本执行前，请备份重要数据
3. **测试环境**：如有条件，先在测试环境中运行验证

### 执行中

1. **最小权限**：虽然部分脚本需要 root 权限，但建议仅在必要时使用 root 执行
2. **监控输出**：关注脚本运行时的输出信息，确认一切正常
3. **网络环境**：确保网络连接稳定，避免安装中断

### 执行后

1. **验证结果**：确认服务正常运行、端口正确监听
2. **安全加固**：及时修改默认密码、配置防火墙规则
3. **定期更新**：关注项目更新，及时升级到最新版本的脚本

---

## 常见安全问题

### 执行 curl | bash 安全吗？

这是一个常见的担忧。`curl | bash` 本身只是让脚本在 shell 中执行，安全性取决于：

- ✅ **脚本来源可信**：CloudScripts 脚本在 [GitHub](https://github.com/PIKACHUIM/CloudScripts) 完全开源，可审查
- ✅ **HTTPS 传输**：GitHub Raw 通过 HTTPS 传输，防止中间人篡改
- ⚠️ **用户自身判断**：建议执行前先用 `curl URL | less` 查看代码

### 脚本会收集我的信息吗？

CloudScripts 的脚本**不会主动收集或上传**您的个人信息。但是：

- 部分测评脚本（如 IP 质量检测）会向第三方 API 发起查询请求
- 安装的服务面板（如哪吒探针、3X-UI）需要您自行配置数据上报
- 脚本执行过程中可能向 GitHub / 软件源下载依赖文件

### 加密密码安全吗？

`Setup.sh` 使用 AES-256-CBC + PBKDF2 加密，这是业界公认的安全加密标准。但请注意：

- 🔑 **密码强度**：部署密码请使用足够复杂的字符串
- 🔑 **密码保管**：不要在不可信环境中泄露部署密码
- 🔑 **密码不存储**：脚本执行完毕后不会在系统中存储密码

---

## 许可证

| 组件 | 许可证 |
|------|--------|
| CloudScripts 主项目（Linux 脚本） | GNU General Public License v3 |
| Windows Docker 相关脚本 | MIT License（版权归 Microsoft Corporation） |
| MAS 激活脚本 | 来自 [massgrave.dev](https://massgrave.dev/) 开源项目 |
| 3X-UI 面板脚本 | 来自 [MHSanaei/3x-ui](https://github.com/MHSanaei/3x-ui) |
