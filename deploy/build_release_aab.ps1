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

# 统一清理所有代理相关环境变量（含大/小写、NO_PROXY、ALL_PROXY）：
# 国内 CI / 父 shell 经常继承代理，会让 pub get / Gradle 解析镜像时拿到错误的代理地址。
# 仅清当前进程即可——脚本是 fork 出来的独立 PowerShell，不会污染父会话。
@('HTTP_PROXY','HTTPS_PROXY','http_proxy','https_proxy','NO_PROXY','no_proxy','ALL_PROXY','all_proxy') | ForEach-Object {
    Remove-Item "Env:\$_" -ErrorAction SilentlyContinue
}
# 二次校验：残留代理会让 Flutter 走错镜像，国内构建常见坑。
if ($env:HTTP_PROXY -or $env:HTTPS_PROXY -or $env:http_proxy -or $env:https_proxy) {
    Write-Output "[WARN] proxy env still set after cleanup: HTTP_PROXY=$env:HTTP_PROXY HTTPS_PROXY=$env:HTTPS_PROXY"
}

# 崩溃上报（Sentry）：在 https://sentry.io 创建 Android 项目后把 DSN 填到这里。
# 留空 = 构建完全禁用上报（不影响其他功能），上线前强烈建议启用。
$SENTRY_DSN = ''  # 例: 'https://xxxxxxxx@o0.ingest.sentry.io/0'

# RevenueCat Public SDK key（goog_ 开头，RC 后台 → App Settings → API Keys → Public）。
# 留空会导致正式包 AppConfig.revenueCatApiKey 为空字符串 → Purchases 永不配置 →
# 所有订阅购买在运行时抛 "Purchases are not configured in this build"（上架致命缺陷）。
# 因此为空时直接中止构建，绝不产出不可收费的上架包。
$REVENUECAT_API_KEY = ''  # 例: 'goog_XXXXXXXXXXXXXXXX'

if ([string]::IsNullOrWhiteSpace($REVENUECAT_API_KEY)) {
    Write-Output "[ERR] REVENUECAT_API_KEY is empty."
    Write-Output "      A release AAB built without it cannot process ANY purchase"
    Write-Output "      ('Purchases are not configured in this build' at runtime)."
    Write-Output "      Fill the goog_... Public SDK key above before building the launch AAB."
    exit 1
}

$dartDefines = @(
    '--dart-define=ENV=prod',
    "--dart-define=API_BASE_URL=https://freelance-hub-api-f2gn.onrender.com/api/v1",
    "--dart-define=REVENUECAT_API_KEY=$REVENUECAT_API_KEY"
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
