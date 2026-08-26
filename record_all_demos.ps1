$adb = "C:\Users\trama\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$device = "ZD222GYVTF"
$outputDir = "D:\Freelance\KeyFlow\demo_recordings"

function Adb-Shell($cmd) {
    & $adb -s $device shell $cmd
}

function Wake-Device {
    Adb-Shell "input keyevent 224 ; input keyevent 82 ; input swipe 540 1800 540 400 200"
    Start-Sleep -Milliseconds 500
}

Write-Host "================================================="
Write-Host " Recording All 9 Feature Demo Clips for KeyFlow"
Write-Host "================================================="

New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
Wake-Device

# Enable services
Adb-Shell "settings put secure enabled_accessibility_services com.keyflow.keyflow_app/com.keyflow.keyflow_app.KeyflowAccessibilityService ; settings put secure accessibility_enabled 1"
Adb-Shell "appops set com.keyflow.keyflow_app SYSTEM_ALERT_WINDOW allow"
Adb-Shell "pm grant com.keyflow.keyflow_app android.permission.POST_NOTIFICATIONS"

# ----------------------------------------------------
# 1. demo_signup
# ----------------------------------------------------
Write-Host "`n[1/9] Recording demo_signup..."
Adb-Shell "am force-stop com.keyflow.keyflow_app"
Start-Sleep -Milliseconds 400
Adb-Shell "am start -n com.keyflow.keyflow_app/.MainActivity"
Start-Sleep -Seconds 2

$proc = Start-Process -FilePath $adb -ArgumentList "-s $device shell screenrecord --time-limit 14 /sdcard/demo_signup.mp4" -PassThru
Start-Sleep -Seconds 1
# Tap Sign Up switch
Adb-Shell "input tap 725 1320"
Start-Sleep -Seconds 1
# Name
Adb-Shell "input tap 540 660"
Start-Sleep -Milliseconds 300
Adb-Shell "input text 'AlexMorgan'"
# Email
Adb-Shell "input tap 540 820"
Start-Sleep -Milliseconds 300
Adb-Shell "input text 'alex.morgan@keyflow.io'"
# Password
Adb-Shell "input tap 540 980"
Start-Sleep -Milliseconds 300
Adb-Shell "input text 'KeyFlow2026!'"
# Confirm Password
Adb-Shell "input tap 540 1140"
Start-Sleep -Milliseconds 300
Adb-Shell "input text 'KeyFlow2026!'"
# Submit Sign Up
Adb-Shell "input tap 540 1320"
Start-Sleep -Seconds 2
# Continue into app
Adb-Shell "input tap 540 1160"
Start-Sleep -Seconds 1

$proc.WaitForExit(16000)
& $adb -s $device pull /sdcard/demo_signup.mp4 "$outputDir\demo_signup.mp4"
Adb-Shell "rm -f /sdcard/demo_signup.mp4"
Write-Host "demo_signup.mp4 saved."

# ----------------------------------------------------
# 2. demo_login
# ----------------------------------------------------
Write-Host "`n[2/9] Recording demo_login..."
Adb-Shell "am force-stop com.keyflow.keyflow_app"
Start-Sleep -Milliseconds 400
Adb-Shell "am start -n com.keyflow.keyflow_app/.MainActivity"
Start-Sleep -Seconds 2

$proc = Start-Process -FilePath $adb -ArgumentList "-s $device shell screenrecord --time-limit 12 /sdcard/demo_login.mp4" -PassThru
Start-Sleep -Seconds 1
# Fill Email
Adb-Shell "input tap 540 660"
Start-Sleep -Milliseconds 300
Adb-Shell "input text 'alex.morgan@keyflow.io'"
# Fill Password
Adb-Shell "input tap 540 820"
Start-Sleep -Milliseconds 300
Adb-Shell "input text 'KeyFlow2026!'"
# Tap Sign In
Adb-Shell "input tap 540 1016"
Start-Sleep -Seconds 1
Adb-Shell "input tap 540 1160"
Start-Sleep -Seconds 2

$proc.WaitForExit(14000)
& $adb -s $device pull /sdcard/demo_login.mp4 "$outputDir\demo_login.mp4"
Adb-Shell "rm -f /sdcard/demo_login.mp4"
Write-Host "demo_login.mp4 saved."

# ----------------------------------------------------
# 3. demo_accessibility_setup
# ----------------------------------------------------
Write-Host "`n[3/9] Recording demo_accessibility_setup..."
Adb-Shell "am start -n com.keyflow.keyflow_app/.MainActivity"
Start-Sleep -Seconds 1
# Ensure we are inside app
Adb-Shell "input tap 540 1160"
Start-Sleep -Milliseconds 500

$proc = Start-Process -FilePath $adb -ArgumentList "-s $device shell screenrecord --time-limit 14 /sdcard/demo_accessibility_setup.mp4" -PassThru
Start-Sleep -Seconds 1
# Tap Settings tab
Adb-Shell "input tap 972 2330"
Start-Sleep -Seconds 1
# Scroll to Accessibility row
Adb-Shell "input swipe 540 1400 540 800 300"
Start-Sleep -Seconds 1
# Tap Accessibility Access
Adb-Shell "input tap 540 800"
Start-Sleep -Seconds 2
# Tap KeyFlow in system list
Adb-Shell "input tap 540 600"
Start-Sleep -Seconds 1
# Return to app
Adb-Shell "input keyevent 4"
Start-Sleep -Milliseconds 500
Adb-Shell "input keyevent 4"
Start-Sleep -Seconds 2

$proc.WaitForExit(16000)
& $adb -s $device pull /sdcard/demo_accessibility_setup.mp4 "$outputDir\demo_accessibility_setup.mp4"
Adb-Shell "rm -f /sdcard/demo_accessibility_setup.mp4"
Write-Host "demo_accessibility_setup.mp4 saved."

# ----------------------------------------------------
# 4. demo_typing_capture
# ----------------------------------------------------
Write-Host "`n[4/9] Recording demo_typing_capture..."
$proc = Start-Process -FilePath $adb -ArgumentList "-s $device shell screenrecord --time-limit 14 /sdcard/demo_typing_capture.mp4" -PassThru
Start-Sleep -Seconds 1
# Open Chrome
Adb-Shell "am start -a android.intent.action.VIEW -d 'https://www.google.com' com.android.chrome"
Start-Sleep -Seconds 2
Adb-Shell "input tap 540 280"
Start-Sleep -Milliseconds 400
Adb-Shell "input text 'KeyFlow\ Live\ Typing\ Capture\ Demo'"
Start-Sleep -Seconds 2
# Switch back to KeyFlow
Adb-Shell "am start -n com.keyflow.keyflow_app/.MainActivity"
Start-Sleep -Seconds 1
# Tap History tab
Adb-Shell "input tap 324 2330"
Start-Sleep -Seconds 3

$proc.WaitForExit(16000)
& $adb -s $device pull /sdcard/demo_typing_capture.mp4 "$outputDir\demo_typing_capture.mp4"
Adb-Shell "rm -f /sdcard/demo_typing_capture.mp4"
Write-Host "demo_typing_capture.mp4 saved."

# ----------------------------------------------------
# 5. demo_sensitive_exclusion
# ----------------------------------------------------
Write-Host "`n[5/9] Recording demo_sensitive_exclusion..."
$proc = Start-Process -FilePath $adb -ArgumentList "-s $device shell screenrecord --time-limit 12 /sdcard/demo_sensitive_exclusion.mp4" -PassThru
Start-Sleep -Seconds 1
Adb-Shell "am start -a android.intent.action.VIEW -d 'https://www.google.com' com.android.chrome"
Start-Sleep -Seconds 2
Adb-Shell "input tap 540 280"
Start-Sleep -Milliseconds 400
Adb-Shell "input text 'SecretPassword123!'"
Start-Sleep -Seconds 1
Adb-Shell "am start -n com.keyflow.keyflow_app/.MainActivity"
Start-Sleep -Seconds 1
Adb-Shell "input tap 324 2330"
Start-Sleep -Seconds 3

$proc.WaitForExit(14000)
& $adb -s $device pull /sdcard/demo_sensitive_exclusion.mp4 "$outputDir\demo_sensitive_exclusion.mp4"
Adb-Shell "rm -f /sdcard/demo_sensitive_exclusion.mp4"
Write-Host "demo_sensitive_exclusion.mp4 saved."

# ----------------------------------------------------
# 6. demo_floating_bot
# ----------------------------------------------------
Write-Host "`n[6/9] Recording demo_floating_bot..."
Adb-Shell "am start -n com.keyflow.keyflow_app/.MainActivity"
Start-Sleep -Seconds 1
# Ensure Settings tab
Adb-Shell "input tap 972 2330"
Start-Sleep -Seconds 1

$proc = Start-Process -FilePath $adb -ArgumentList "-s $device shell screenrecord --time-limit 14 /sdcard/demo_floating_bot.mp4" -PassThru
Start-Sleep -Seconds 1
# Scroll to Floating Bubble switch
Adb-Shell "input swipe 540 1400 540 800 300"
Start-Sleep -Seconds 1
# Toggle Bubble ON
Adb-Shell "input tap 950 820"
Start-Sleep -Seconds 2
# Go to Home launcher
Adb-Shell "input keyevent 3"
Start-Sleep -Seconds 2
# Tap floating bubble
Adb-Shell "input tap 60 700"
Start-Sleep -Seconds 2
# Tap Pause Typing Capture toggle
Adb-Shell "input tap 400 750"
Start-Sleep -Seconds 1
# Tap Pause toggle again
Adb-Shell "input tap 400 750"
Start-Sleep -Seconds 1

$proc.WaitForExit(16000)
& $adb -s $device pull /sdcard/demo_floating_bot.mp4 "$outputDir\demo_floating_bot.mp4"
Adb-Shell "rm -f /sdcard/demo_floating_bot.mp4"
Write-Host "demo_floating_bot.mp4 saved."

# ----------------------------------------------------
# 7. demo_exclude_apps
# ----------------------------------------------------
Write-Host "`n[7/9] Recording demo_exclude_apps..."
Adb-Shell "am start -n com.keyflow.keyflow_app/.MainActivity"
Start-Sleep -Seconds 1
Adb-Shell "input tap 972 2330"
Start-Sleep -Seconds 1

$proc = Start-Process -FilePath $adb -ArgumentList "-s $device shell screenrecord --time-limit 12 /sdcard/demo_exclude_apps.mp4" -PassThru
Start-Sleep -Seconds 1
# Tap Manage Excluded Apps
Adb-Shell "input tap 540 1180"
Start-Sleep -Seconds 2
# Tap search
Adb-Shell "input tap 540 280"
Start-Sleep -Milliseconds 300
Adb-Shell "input text 'Chrome'"
Start-Sleep -Seconds 1
# Toggle exclusion switch
Adb-Shell "input tap 950 480"
Start-Sleep -Seconds 2

$proc.WaitForExit(14000)
& $adb -s $device pull /sdcard/demo_exclude_apps.mp4 "$outputDir\demo_exclude_apps.mp4"
Adb-Shell "rm -f /sdcard/demo_exclude_apps.mp4"
Write-Host "demo_exclude_apps.mp4 saved."

# ----------------------------------------------------
# 8. demo_history_screen
# ----------------------------------------------------
Write-Host "`n[8/9] Recording demo_history_screen..."
Adb-Shell "am start -n com.keyflow.keyflow_app/.MainActivity"
Start-Sleep -Seconds 1

$proc = Start-Process -FilePath $adb -ArgumentList "-s $device shell screenrecord --time-limit 12 /sdcard/demo_history_screen.mp4" -PassThru
Start-Sleep -Seconds 1
# Tap History tab
Adb-Shell "input tap 324 2330"
Start-Sleep -Seconds 2
# Scroll through History
Adb-Shell "input swipe 540 1400 540 600 400"
Start-Sleep -Seconds 1
Adb-Shell "input swipe 540 600 540 1400 400"
Start-Sleep -Seconds 1
# Tap search
Adb-Shell "input tap 540 280"
Start-Sleep -Milliseconds 300
Adb-Shell "input text 'KeyFlow'"
Start-Sleep -Seconds 1
# Long press on card to copy
Adb-Shell "input swipe 500 700 500 700 800"
Start-Sleep -Seconds 2

$proc.WaitForExit(14000)
& $adb -s $device pull /sdcard/demo_history_screen.mp4 "$outputDir\demo_history_screen.mp4"
Adb-Shell "rm -f /sdcard/demo_history_screen.mp4"
Write-Host "demo_history_screen.mp4 saved."

# ----------------------------------------------------
# 9. demo_profile_account
# ----------------------------------------------------
Write-Host "`n[9/9] Recording demo_profile_account..."
Adb-Shell "am start -n com.keyflow.keyflow_app/.MainActivity"
Start-Sleep -Seconds 1
# Go to Home tab
Adb-Shell "input tap 108 2330"
Start-Sleep -Seconds 1

$proc = Start-Process -FilePath $adb -ArgumentList "-s $device shell screenrecord --time-limit 12 /sdcard/demo_profile_account.mp4" -PassThru
Start-Sleep -Seconds 1
# Tap Profile card at top
Adb-Shell "input tap 970 206"
Start-Sleep -Seconds 2
# Scroll through Profile
Adb-Shell "input swipe 540 1600 540 800 400"
Start-Sleep -Seconds 2
# Scroll back
Adb-Shell "input swipe 540 800 540 1600 400"
Start-Sleep -Seconds 1
# Tap Sign Out
Adb-Shell "input tap 540 1800"
Start-Sleep -Seconds 2

$proc.WaitForExit(14000)
& $adb -s $device pull /sdcard/demo_profile_account.mp4 "$outputDir\demo_profile_account.mp4"
Adb-Shell "rm -f /sdcard/demo_profile_account.mp4"
Write-Host "demo_profile_account.mp4 saved."

Write-Host "`n================================================="
Write-Host " All 9 Feature Recordings Successfully Completed!"
Write-Host "================================================="
Get-ChildItem -Path $outputDir | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize
