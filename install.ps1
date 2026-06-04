# Claude Code 自定义状态栏 - Windows 一键安装脚本
# 用法：irm https://raw.githubusercontent.com/YOUR_USERNAME/claude-statusline/main/install.ps1 | iex

$ErrorActionPreference = "Stop"

$REPO     = "YOUR_USERNAME/claude-statusline"
$RAW_BASE = "https://raw.githubusercontent.com/$REPO/main"
$CLAUDE_DIR = "$env:USERPROFILE\.claude"

Write-Host ""
Write-Host "=== Claude Code 状态栏安装程序 ===" -ForegroundColor Cyan

# 检查 Node.js
Write-Host ""
Write-Host "► 检查 Node.js..." -NoNewline
try {
    $nodeVersion = node --version 2>$null
    Write-Host " $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host " 未找到" -ForegroundColor Red
    Write-Host "  请先安装 Node.js：https://nodejs.org/" -ForegroundColor Yellow
    exit 1
}

# 检查 Claude Code
Write-Host "► 检查 Claude Code..." -NoNewline
try {
    $claudeVersion = claude --version 2>$null
    Write-Host " $claudeVersion" -ForegroundColor Green
} catch {
    Write-Host " 未找到" -ForegroundColor Red
    Write-Host "  请先安装 Claude Code：https://claude.ai/code" -ForegroundColor Yellow
    exit 1
}

# 创建 .claude 目录
if (!(Test-Path $CLAUDE_DIR)) {
    New-Item -ItemType Directory -Path $CLAUDE_DIR | Out-Null
}

# 下载脚本
Write-Host "► 下载 statusline-command.sh..." -NoNewline
try {
    Invoke-WebRequest `
        -Uri "$RAW_BASE/statusline-command.sh" `
        -OutFile "$CLAUDE_DIR\statusline-command.sh" `
        -UseBasicParsing
    Write-Host " 完成" -ForegroundColor Green
} catch {
    Write-Host " 失败" -ForegroundColor Red
    Write-Host "  错误：$_" -ForegroundColor Yellow
    exit 1
}

# 更新 settings.json
Write-Host "► 更新 settings.json..." -NoNewline
$settingsPath = "$CLAUDE_DIR\settings.json"

$settings = @{}
if (Test-Path $settingsPath) {
    try {
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json -AsHashtable
    } catch {
        # 解析失败则备份后重建
        Copy-Item $settingsPath "$settingsPath.bak"
        Write-Host ""
        Write-Host "  原 settings.json 解析失败，已备份为 settings.json.bak" -ForegroundColor Yellow
        $settings = @{}
    }
}

$settings["statusCommand"] = "bash ~/.claude/statusline-command.sh"

if (!$settings.ContainsKey("env")) {
    $settings["env"] = @{}
}
$settings["env"]["CLAUDE_CODE_NO_FLICKER"] = "1"

$settings | ConvertTo-Json -Depth 5 | Set-Content $settingsPath -Encoding UTF8
Write-Host " 完成" -ForegroundColor Green

# 完成
Write-Host ""
Write-Host "=== 安装完成 ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "  脚本位置：$CLAUDE_DIR\statusline-command.sh"
Write-Host "  配置位置：$settingsPath"
Write-Host ""
Write-Host "  请重启 Claude Code 使状态栏生效。" -ForegroundColor Yellow
Write-Host ""
