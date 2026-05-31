# Tīra instalācija — noņem lietotni un kešu, tad uzliek jaunāko APK.
# Lietošana: .\scripts\install_mobile_clean.ps1

$ErrorActionPreference = "Stop"
$pkg = "lv.edgarsfoto.efpic_live"
$apk = Join-Path $PSScriptRoot "..\mobile\build\app\outputs\flutter-apk\app-release.apk"

if (-not (Test-Path $apk)) {
    Write-Host "APK nav atrasts. Būvē release..."
    Push-Location (Join-Path $PSScriptRoot "..\mobile")
    flutter build apk --release
    Pop-Location
}

$serial = (adb devices | Select-String "device$" | Select-Object -First 1) -replace "\s+device",""
if (-not $serial) { throw "Nav pievienota Android ierīce (adb devices)." }

Write-Host "Noņem $pkg no $serial ..."
adb -s $serial shell am force-stop $pkg 2>$null
adb -s $serial uninstall $pkg 2>$null

Write-Host "Instalē $apk ..."
adb -s $serial install -r $apk

Write-Host "Versija:"
adb -s $serial shell dumpsys package $pkg | Select-String "versionName"
