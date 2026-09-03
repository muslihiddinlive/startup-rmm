# ============================================================
#  Startup RMM — O'rnatuvchi
#  Administrator sifatida ishga tushiring:
#    Right-click → "Run with PowerShell" (yoki Run as Administrator)
# ============================================================

$TASK_NAME  = "StartupRMM-Client"
$INSTALL_DIR = "$env:APPDATA\rmm"
$SCRIPT_DST  = "$INSTALL_DIR\client.ps1"

Write-Host "=== Startup RMM Client o'rnatilmoqda ===" -ForegroundColor Cyan

# 1. Papka va faylni ko'chirish
New-Item -ItemType Directory -Force -Path $INSTALL_DIR | Out-Null
$scriptSrc = Join-Path $PSScriptRoot "client.ps1"
Copy-Item -Path $scriptSrc -Destination $SCRIPT_DST -Force
Write-Host "✅ Fayl ko'chirildi: $SCRIPT_DST" -ForegroundColor Green

# 2. Avvalgi taskni o'chirish (agar mavjud bo'lsa)
if (Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TASK_NAME -Confirm:$false
}

# 3. Scheduled Task yaratish
$action = New-ScheduledTaskAction `
    -Execute    "powershell.exe" `
    -Argument   "-WindowStyle Hidden -ExecutionPolicy Bypass -NonInteractive -File `"$SCRIPT_DST`""

# Tizim yoqilganda va login bo'lganda ishga tushadi
$triggers = @(
    $(New-ScheduledTaskTrigger -AtStartup),
    $(New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME)
)

$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit 0 `
    -RestartCount 10 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -StartWhenAvailable

$principal = New-ScheduledTaskPrincipal `
    -UserId    $env:USERNAME `
    -LogonType Interactive `
    -RunLevel  Highest

Register-ScheduledTask `
    -TaskName  $TASK_NAME `
    -Action    $action `
    -Trigger   $triggers `
    -Settings  $settings `
    -Principal $principal `
    -Force | Out-Null

Write-Host "✅ Task Scheduler ga qo'shildi: $TASK_NAME" -ForegroundColor Green

# 4. Darhol ishga tushirish
Start-ScheduledTask -TaskName $TASK_NAME
Write-Host "✅ Client ishga tushdi!" -ForegroundColor Green

Write-Host ""
Write-Host "Client ID:" -NoNewline
$idFile = "$INSTALL_DIR\client_id.txt"
Start-Sleep -Seconds 2
if (Test-Path $idFile) {
    Write-Host " $(Get-Content $idFile)" -ForegroundColor Yellow
} else {
    Write-Host " (birinchi ishga tushishda generatsiya bo'ladi)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "O'rnatish tugadi! Endi Telegram botdan /clients buyrug'ini yuboring." -ForegroundColor Cyan
