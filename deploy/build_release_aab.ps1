# 释放 Flutter lockfile 后启动 release AAB 构建。
# 用法：右键 PowerShell → 用管理员运行此脚本（或 PowerShell 工具执行）。
# lockfile 来自上一轮 flutter 命令的句柄未释放，会阻断新 build。
# 删完后立即启动 release AAB（unset 代理 + ENV=prod + Render 生产后端）。

$lockfile = 'C:\src\flutter\bin\cache\lockfile'
if (Test-Path $lockfile) {
    try {
        Remove-Item -LiteralPath $lockfile -Force -Confirm:$false -ErrorAction Stop
        Write-Output "[OK] lockfile removed: $lockfile"
    } catch {
        Write-Output "[ERR] failed to remove: $_"
        Write-Output "      尝试：关闭所有 dart.exe / flutter 进程后重跑，或重启 PowerShell"
        exit 1
    }
} else {
    Write-Output "[OK] lockfile not present, skip"
}

# 切到 mobile 目录，unset 代理，启动 release AAB 构建
Set-Location 'C:\dev\freelance_hub\mobile'
$env:HTTP_PROXY = $null
$env:HTTPS_PROXY = $null

# 崩溃上报（Sentry）：在 https://sentry.io 创建 Android 项目后把 DSN 填到这里。
# 留空 = 构建完全禁用上报（不影响其他功能），上线前强烈建议启用。
$SENTRY_DSN = ''  # 例: 'https://xxxxxxxx@o0.ingest.sentry.io/0'

$dartDefines = @(
    '--dart-define=ENV=prod',
    "--dart-define=API_BASE_URL=https://freelance-hub-api-f2gn.onrender.com/api/v1"
)
if ($SENTRY_DSN -ne '') {
    $dartDefines += "--dart-define=SENTRY_DSN=$SENTRY_DSN"
    Write-Output "  SENTRY_DSN=已注入"
} else {
    Write-Output "  SENTRY_DSN=(空，崩溃上报禁用)"
}

Write-Output ""
Write-Output "== Starting release AAB build =="
Write-Output "  ENV=prod"
Write-Output "  API_BASE_URL=https://freelance-hub-api-f2gn.onrender.com/api/v1"
Write-Output "  Key: mobile\android\key.properties + freelance-hub.jks (已就绪)"
Write-Output ""
Write-Output "构建完成约需 20-40 分钟（首次拉 Gradle 依赖会久一些）"
Write-Output "产物: mobile\build\app\outputs\bundle\release\app-release.aab"
Write-Output ""

& 'C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe' `
    --disable-dart-dev `
    'C:\src\flutter\bin\cache\flutter_tools.snapshot' `
    build appbundle --release `
    @dartDefines
