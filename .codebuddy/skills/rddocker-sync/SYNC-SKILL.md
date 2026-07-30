# RDDocker → CloudScripts 桌面脚本同步 Skill

## 概述

此文档定义了从 [RDDocker](https://github.com/PIKACHUIM/RDDocker) 项目的 `scripts/install/desktop/` 目录同步桌面安装脚本到 [CloudScripts](https://github.com/PIKACHUIM/CloudScripts) 项目的 `Linux/Desktop/` 目录的标准操作流程。

当用户提到以下关键词时，AI 应自动加载此 Skill：
- "同步 RDDocker 脚本"
- "更新桌面安装脚本"
- "从 RDDocker 拉取最新脚本"
- "刷新 Linux/Desktop"

---

## 一、源与目标映射

### 1.1 源仓库 (RDDocker)

```
https://github.com/PIKACHUIM/RDDocker
├── scripts/install/
│   ├── commons.sh          ← 公共函数库（所有脚本的依赖）
│   ├── desktop/
│   │   ├── deepin.sh
│   │   ├── gnome3.sh
│   │   ├── hyland.sh       ← Hyprland
│   │   ├── lingmo.sh
│   │   ├── nirios.sh       ← Niri
│   │   ├── plasma.sh
│   │   └── xfce4l.sh
│   └── configs/
│       └── de-lingmo.sh    ← Lingmo 会话辅助脚本
```

### 1.2 目标仓库 (CloudScripts)

```
CloudScripts/Linux/Desktop/
├── commons.sh              ← 直接同步，不需要映射
├── LXC-Debian-Deepin.sh    ← 来自 deepin.sh
├── LXC-Debian-Gnome3.sh    ← 来自 gnome3.sh
├── LXC-Debian-Graphy.sh    ← 非 RDDocker 脚本，不参与同步
├── LXC-Debian-Hyprland.sh  ← 来自 hyland.sh
├── LXC-Debian-Lingmo.sh    ← 来自 lingmo.sh
├── LXC-Debian-MateDE.sh    ← 非 RDDocker 脚本，不参与同步
├── LXC-Debian-Niri.sh      ← 来自 nirios.sh
├── LXC-Debian-Plasma.sh    ← 来自 plasma.sh
├── LXC-Debian-Server.sh    ← 非 RDDocker 脚本，不参与同步
└── LXC-Debian-Xfce4L.sh    ← 来自 xfce4l.sh
```

### 1.3 文件命名映射表

| RDDocker 源文件 | CloudScripts 目标文件 |
|----------------|----------------------|
| `scripts/install/commons.sh` | `Linux/Desktop/commons.sh` |
| `scripts/install/desktop/deepin.sh` | `Linux/Desktop/LXC-Debian-Deepin.sh` |
| `scripts/install/desktop/gnome3.sh` | `Linux/Desktop/LXC-Debian-Gnome3.sh` |
| `scripts/install/desktop/hyland.sh` | `Linux/Desktop/LXC-Debian-Hyprland.sh` |
| `scripts/install/desktop/lingmo.sh` | `Linux/Desktop/LXC-Debian-Lingmo.sh` |
| `scripts/install/desktop/nirios.sh` | `Linux/Desktop/LXC-Debian-Niri.sh` |
| `scripts/install/desktop/plasma.sh` | `Linux/Desktop/LXC-Debian-Plasma.sh` |
| `scripts/install/desktop/xfce4l.sh` | `Linux/Desktop/LXC-Debian-Xfce4L.sh` |
| `scripts/install/configs/de-lingmo.sh` | 内联写入 `/usr/local/bin/de-lingmo.sh`（见 2.5） |

---

## 二、转换规则

### 2.1 添加 Shebang 和 set -e

RDDocker 脚本使用 `#!/bin/sh`，CloudScripts 目标脚本使用 `#!/bin/bash`。转换时：

```bash
#!/bin/bash
```

紧接添加 `set -e` 和 commons.sh 引用。

### 2.2 添加 commons.sh 引用

RDDocker 脚本中的：
```bash
INSTALL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$INSTALL_DIR/commons.sh"
```

在 CloudScripts 中改为：
```bash
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$INSTALL_DIR/commons.sh"
```

原因：CloudScripts 中 commons.sh 与目标脚本在同一目录，而非 `..` 父目录。

### 2.3 添加 Flag 文件检查机制

在每个 DE 脚本的 `source commons.sh` 之后、DE 安装逻辑之前，添加以下 Check 块：

```bash
# Check -----------------------------------------------------------
file="/etc/lxc-de-flag"
if [[ ! -f "$file" ]] || [[ ! -s "$file" ]]; then
    apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Server.sh | bash -e
    apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Graphy.sh | bash -e
else
    read -r content < "$file"
    case "$content" in
        0) apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Graphy.sh | bash -e ;;
        9) echo "检查通过，开始安装 XXX 桌面....." ;;
        *) echo "已经安装过桌面，禁止重复安装" && exit ;;
    esac
fi
```

**规则**：
- 将 `XXX` 替换为实际桌面名称（Deepin / GNOME / Lingmo / Plasma / Xfce4 / MATE / Hyprland / Niri）
- 如果 RDDocker 有新的 DE 不支持 Debian Server 链，可修改嵌套逻辑

### 2.4 保留 LXC 基础设施注释

RDDocker 的 DE 安装部分（`# Deepin Desktop (来自 RDDocker)` 注释之后）应保持原样，不做修改。这是从 RDDocker 同步的核心代码段。

### 2.5 处理 RDDocker configs/ 目录下的辅助脚本

RDDocker 的 `configs/de-lingmo.sh` 不在 Desktop 目标目录中单独存放，而是以 heredoc 方式内联写入目标脚本：

```bash
# de-lingmo.sh helper (来自 RDDocker configs/de-lingmo.sh) ----------
cat > /usr/local/bin/de-lingmo.sh <<'LINGMO'
[configs/de-lingmo.sh 的完整内容]
LINGMO
chmod +x /usr/local/bin/de-lingmo.sh
```

### 2.6 ENV 变量大小写

RDDocker 脚本中的 `"${VERSION_CODENAME:-}"` 不需要修改大小写，但注意 CloudScripts 脚本使用 `VERSION_CODENAME`，而 RDDocker debian 部分使用同样的变量名，这是兼容的。

### 2.7 启动脚本段

RDDocker 在每个脚本末尾向 `/run.sh` 追加启动命令。转换时：
- RDDocker 使用 `cat >> /run.sh << 'EOF'` 或 heredoc 方式
- CloudScripts 统一使用 `cat >> /run.sh <<'EOF'`（EOF 加引号防止变量展开）
- 无需修改 RDDocker 的启动逻辑，但需确保 `bash /x11vnc.sh` 引用正确（该脚本由 Graphy.sh 创建）

### 2.8 添加 Flag 写入

在每个脚本末尾 HEARDOC 之后，添加：
```bash
echo N > /etc/lxc-de-flag
```

其中 `N` 是当前桌面环境的数字标识：

| 桌面环境 | Flag 值 |
|---------|--------|
| Deepin | 1 |
| Plasma | 2 |
| Lingmo | 3 |
| Xfce4 | 4 |
| GNOME 3 | 6 |
| MATE | 7 |
| Hyprland | 8 |
| Niri | 9 |

**规则**：新添加的 DE 应选择一个未被占用的数字（> 9），并在此表中记录。

---

## 三、同步步骤（标准操作流程）

### 步骤 1：获取 RDDocker 源文件

使用 `web_fetch` 工具从以下 URL 获取原始脚本内容：

| 文件 | Raw URL |
|------|---------|
| commons.sh | `https://raw.githubusercontent.com/PIKACHUIM/RDDocker/master/scripts/install/commons.sh` |
| deepin.sh | `https://raw.githubusercontent.com/PIKACHUIM/RDDocker/master/scripts/install/desktop/deepin.sh` |
| gnome3.sh | `https://raw.githubusercontent.com/PIKACHUIM/RDDocker/master/scripts/install/desktop/gnome3.sh` |
| hyland.sh | `https://raw.githubusercontent.com/PIKACHUIM/RDDocker/master/scripts/install/desktop/hyland.sh` |
| lingmo.sh | `https://raw.githubusercontent.com/PIKACHUIM/RDDocker/master/scripts/install/desktop/lingmo.sh` |
| nirios.sh | `https://raw.githubusercontent.com/PIKACHUIM/RDDocker/master/scripts/install/desktop/nirios.sh` |
| plasma.sh | `https://raw.githubusercontent.com/PIKACHUIM/RDDocker/master/scripts/install/desktop/plasma.sh` |
| xfce4l.sh | `https://raw.githubusercontent.com/PIKACHUIM/RDDocker/master/scripts/install/desktop/xfce4l.sh` |
| de-lingmo.sh | `https://raw.githubusercontent.com/PIKACHUIM/RDDocker/master/scripts/install/configs/de-lingmo.sh` |

如果 GitHub API 限流，改用：
```
https://api.github.com/repos/PIKACHUIM/RDDocker/contents/scripts/install/desktop
```

### 步骤 2：对比差异

对每个源文件执行：
1. 读取当前 CloudScripts 目标文件（如果存在）
2. 读取 RDDocker 源文件
3. 对比 DE 安装部分（`case "$OS_ID"` 块）是否有新增的发行版支持或包变更
4. 对比启动脚本部分（`cat >> /run.sh` 块）是否有新增启动逻辑

### 步骤 3：应用转换规则

对每个文件按顺序应用第二章列出的转换规则。

### 步骤 4：commons.sh 独立同步

`commons.sh` 直接从 RDDocker 源复制，无需转换（唯一例外是要确保路径引用正确）。

### 步骤 5：检查新增文件

对比 RDDocker `scripts/install/desktop/` 和 CloudScripts `Linux/Desktop/`：
- 如果 RDDocker 有我无 → 创建新脚本（见第四章）
- 如果 RDDocker 无我有 → 保留（CloudScripts 独有的 DE，如 MATE）
- 如果两边都有 → 按转换规则更新

---

## 四、添加新的桌面环境脚本

当 RDDocker 新增一个 DE 脚本时，按以下步骤创建对应的 CloudScripts 脚本：

### 4.1 创建目标文件

文件命名规则：`LXC-Debian-{Name}.sh`

其中 `{Name}` 的映射：
- `hyland.sh` → `Hyprland`
- 新脚本 → 提取 DE 的 PascalCase 名称

### 4.2 模板结构

```bash
#!/bin/bash
# {DE Name} Desktop Environment
# 基于 RDDocker: {Raw URL to source file}

set -e
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$INSTALL_DIR/commons.sh"

# Check -----------------------------------------------------------
file="/etc/lxc-de-flag"
if [[ ! -f "$file" ]] || [[ ! -s "$file" ]]; then
    apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Server.sh | bash -e
    apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Graphy.sh | bash -e
else
    read -r content < "$file"
    case "$content" in
        0) apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Graphy.sh | bash -e ;;
        9) echo "检查通过，开始安装 {DE Name} 桌面....." ;;
        *) echo "已经安装过桌面，禁止重复安装" && exit ;;
    esac
fi

# {DE Name} (来自 RDDocker) -----------------------------------------
[复制 RDDocker 的 case "$OS_ID" 安装逻辑]

# Startup Desktop (来自 RDDocker) ----------------------------------
[复制 RDDocker 的 cat >> /run.sh 启动逻辑]

echo N > /etc/lxc-de-flag
```

### 4.3 分配 Flag 值

按递增顺序选择下一个未占用的数字。当前已占用：1,2,3,4,6,7,8,9。

---

## 五、不需要同步的内容

以下文件/目录**不参与** RDDocker 同步：

| 文件 | 原因 |
|------|------|
| `LXC-Debian-Server.sh` | CloudScripts 独有的基础服务安装脚本 |
| `LXC-Debian-Graphy.sh` | CloudScripts 独有的 X11/VNC/NoMachine 图形环境脚本 |
| `LXC-Debian-MateDE.sh` | RDDocker 未提供 MATE 版本，CloudScripts 自主维护 |
| 所有 `.git` 相关文件 | 版本控制由 CloudScripts 管理 |

---

## 六、验证清单

同步完成后，对每个脚本验证：

- [ ] `#!/bin/bash` + `set -e` 正确
- [ ] `INSTALL_DIR` 路径指向当前目录（非 `..`）
- [ ] Flag 文件检查机制存在且逻辑正确
- [ ] RDDocker 的 `case "$OS_ID"` 安装代码完整复制
- [ ] RDDocker 的 `cat >> /run.sh` 启动代码完整复制
- [ ] Heredoc 定界符加引号（`<<'EOF'`）防止变量展开
- [ ] `bash /x11vnc.sh` 引用正确（由 Graphy.sh 提供）
- [ ] 末尾 `echo N > /etc/lxc-de-flag` 存在且 N 值正确
- [ ] RDDocker 原始 URL 注释存在（便于追溯）
- [ ] `commons.sh` 已在同一目录且内容最新

---

## 七、AI 执行指令

当用户请求同步时，AI 应执行以下操作：

1. **确认范围**：询问用户要同步全部脚本还是特定 DE，或直接全量同步
2. **获取源文件**：使用 `web_fetch` 工具从 Raw URL 获取最新代码（一次性并行调用所有 URL）
3. **读取目标文件**：读取 CloudScripts `Linux/Desktop/` 下对应的目标文件
4. **应用转换规则**：按第二章规则将源代码包装为目标格式
5. **写入目标文件**：使用 `write_to_file` 工具覆盖写入
6. **验证**：按第六章清单检查
7. **报告**：列出同步了哪些文件、新增/更新了哪些内容

### 快速全量同步（AI 应并行执行）

```
1. 获取 commons.sh           → 写入 Linux/Desktop/commons.sh（直接复制）
2. 获取 deepin.sh            → 写入 Linux/Desktop/LXC-Debian-Deepin.sh
3. 获取 gnome3.sh            → 写入 Linux/Desktop/LXC-Debian-Gnome3.sh
4. 获取 hyland.sh            → 写入 Linux/Desktop/LXC-Debian-Hyprland.sh
5. 获取 lingmo.sh            → 写入 Linux/Desktop/LXC-Debian-Lingmo.sh
6. 获取 nirios.sh            → 写入 Linux/Desktop/LXC-Debian-Niri.sh
7. 获取 plasma.sh            → 写入 Linux/Desktop/LXC-Debian-Plasma.sh
8. 获取 xfce4l.sh            → 写入 Linux/Desktop/LXC-Debian-Xfce4L.sh
9. 获取 configs/de-lingmo.sh → 内联到 LXC-Debian-Lingmo.sh
```

---

## 八、更新记录

| 日期 | 操作 | 说明 |
|------|------|------|
| 2026-07-30 | 创建 | 初始 Skill 文档，建立 RDDocker → CloudScripts 同步规范 |
