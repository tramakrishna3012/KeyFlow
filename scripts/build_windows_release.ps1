# KeyFlow Windows Release Build & Signing Script
# Requirements: Flutter SDK, MSVC C++ Build Tools, SignTool.exe (Windows SDK)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Building KeyFlow Windows Release Binary  " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

Set-Location "$PSScriptRoot\..\app"

Write-Host "Running flutter pub get..." -ForegroundColor Yellow
flutter pub get

Write-Host "Building Flutter Windows Release..." -ForegroundColor Yellow
flutter build windows --release

$outputExe = "$PSScriptRoot\..\app\build\windows\runner\Release\keyflow_app.exe"

if (Test-Path $outputExe) {
    Write-Host "[SUCCESS] Windows executable built at: $outputExe" -ForegroundColor Green
    
    # Optional SignTool step if certificate environment variables are present
    if ($env:WIN_PFX_PATH -and $env:WIN_PFX_PASSWORD) {
        Write-Host "Authenticode Signing binary with SignTool..." -ForegroundColor Yellow
        & signtool.exe sign /f $env:WIN_PFX_PATH /p $env:WIN_PFX_PASSWORD /fd sha256 /tr http://timestamp.digicert.com /td sha256 $outputExe
        Write-Host "[SUCCESS] Binary successfully signed with Authenticode certificate!" -ForegroundColor Green
    } else {
        Write-Host "[NOTE] Code signing skipped (WIN_PFX_PATH environment variable not set)." -ForegroundColor DarkYellow
    }
} else {
    Write-Error "Windows release build failed: Output binary not found."
}
