# Claude Code 自定义状态栏

在 Claude Code CLI 终端底部实时显示 **Token 用量、缓存命中、CNY 费用、上下文占用**。

```
session-name │ 本轮 ↑12.3k ↓1.2k ¥0.0123 │ 累计 ↑98.7k ↓14.5k ¥1.2345 (上下文 42%) 余额¥98.77
```

---

## 功能

- **本轮统计**：每轮对话的输入/输出 token 数和实时费用
- **缓存命中**：自动识别缓存命中 token，按折扣价计费
- **累计费用**：跨轮次累积，会话结束后保留记录
- **上下文占用**：实时显示上下文窗口使用百分比
- **余额追踪**：可设置充值余额，自动扣减显示剩余
- **多模型定价**：内置 Kimi / MiMo / DeepSeek 定价，可自定义

## 支持的模型

| 模型 | 输入（未命中缓存） | 输入（命中缓存） | 输出 |
|------|------------------:|----------------:|-----:|
| Kimi K2.6 | ¥6.50/M | ¥1.10/M | ¥27.00/M |
| Kimi K2.5 | ¥4.00/M | ¥0.70/M | ¥21.00/M |
| MiMo V2.5 Pro | ¥3.00/M | ¥0.025/M | ¥6.00/M |
| MiMo V2.5 | ¥1.00/M | ¥0.02/M | ¥2.00/M |
| DeepSeek V4 Pro | ¥3.00/M | ¥0.025/M | ¥6.00/M |
| DeepSeek V4 Flash | ¥1.00/M | ¥0.02/M | ¥2.00/M |

> 其他模型自动使用兜底定价（MiMo V2.5），可手动修改脚本添加。

---

## 安装（Windows）

**前置要求**：已安装 [Claude Code CLI](https://claude.ai/code) 和 [Node.js](https://nodejs.org/)

在 PowerShell 中运行一键安装：

```powershell
irm https://raw.githubusercontent.com/2239058652/claude-code-cli-skills/main/install.ps1 | iex
```

安装完成后**重启 Claude Code** 即可生效。

---

## 手动安装

适用于网络受限或一键脚本执行失败的情况。

### 第一步：下载脚本文件

**方法 A：直接下载单个文件**

浏览器打开以下链接，右键另存为，保存文件名为 `statusline-command.sh`：

```
https://raw.githubusercontent.com/2239058652/claude-code-cli-skills/main/statusline-command.sh
```

**方法 B：克隆整个仓库**

```powershell
git clone https://github.com/2239058652/claude-code-cli-skills.git
```

### 第二步：复制脚本到正确位置

在 PowerShell 中执行：

```powershell
# 如果 .claude 目录不存在则创建
New-Item -ItemType Directory -Path "$env:USERPROFILE\.claude" -Force

# 复制文件（将路径替换为你实际下载或克隆的位置）
Copy-Item "C:\下载路径\statusline-command.sh" "$env:USERPROFILE\.claude\statusline-command.sh"
```

确认文件到位：

```powershell
Test-Path "$env:USERPROFILE\.claude\statusline-command.sh"
# 输出 True 则说明文件已就位
```

### 第三步：配置 settings.json

用记事本或 VS Code 打开以下路径的文件（不存在则新建）：

```
C:\Users\你的用户名\.claude\settings.json
```

**如果文件不存在**，新建并写入：

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  },
  "env": {
    "CLAUDE_CODE_NO_FLICKER": "1"
  }
}
```

**如果文件已有内容**，在现有 JSON 中补充这两个字段：

```json
{
  "原有字段": "原有内容",
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  },
  "env": {
    "CLAUDE_CODE_NO_FLICKER": "1"
  }
}
```

> ⚠️ JSON 中最后一个字段后面不加逗号。可将文件内容粘贴到 [jsonlint.com](https://jsonlint.com) 验证格式是否正确。

### 第四步：重启 Claude Code

关闭所有 Claude Code 窗口后重新打开，状态栏即可生效。

### 验证是否生效

启动后发送任意一条消息，底部应出现类似以下的状态栏：

```
session-name │ 本轮 ↑12.3k ↓1.2k ¥0.0123 │ 累计 ↑98.7k ↓14.5k ¥1.2345 (上下文 42%)
```

如果没有出现，按以下顺序排查：

1. 运行 `node --version` 确认 Node.js 已安装
2. 运行 `Test-Path "$env:USERPROFILE\.claude\statusline-command.sh"` 确认脚本存在
3. 打开 `settings.json` 检查格式是否合法

---

## 修改定价

定价存储在脚本内，找到对应模型的 `if` 分支直接修改数字即可，单位为 **¥/百万 token**。

也可以使用内置的 `/prs` 指令（需另行安装）交互式修改定价。

---

## 设置余额

编辑 `~/.claude/session-costs.json`，在对应会话名下添加 `balance` 字段：

```json
{
  "your-session-name": {
    "total": 1.23,
    "balance": 100.00
  }
}
```

---

## 文件说明

| 文件 | 说明 |
|------|------|
| `~/.claude/statusline-command.sh` | 主脚本 |
| `~/.claude/settings.json` | Claude Code 配置 |
| `~/.claude/session-costs.json` | 费用累计记录（自动生成） |

---

## 已知限制

- 输出 token 费用存在约 6–12% 低估（流式输出特性导致）
- 需要 Node.js 环境（不依赖 jq/bc）
- Windows 下多项目并发时偶发费用丢失（概率极低，影响极小）