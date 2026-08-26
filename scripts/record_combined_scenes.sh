#!/system/bin/sh

wake() {
    input keyevent 224
    input keyevent 82
    input swipe 540 1800 540 400 200
    sleep 0.5
}

wake

# Setup permissions
settings put secure enabled_accessibility_services com.keyflow.keyflow_app/com.keyflow.keyflow_app.KeyflowAccessibilityService
settings put secure accessibility_enabled 1
appops set com.keyflow.keyflow_app SYSTEM_ALERT_WINDOW allow
pm grant com.keyflow.keyflow_app android.permission.POST_NOTIFICATIONS

echo "================================================="
echo " Recording 11 Master Scenes for KeyFlow Demo"
echo "================================================="

# Scene 1: Fresh app launch -> onboarding/welcome screen
echo ">>> [Scene 1/11] Fresh App Launch & Welcome Screen"
am force-stop com.keyflow.keyflow_app
sleep 0.5
screenrecord --time-limit 14 /sdcard/scene_01_welcome.mp4 &
PID=$!
sleep 1
am start -n com.keyflow.keyflow_app/.MainActivity --ez DEMO_MODE true

sleep 2.5
input swipe 540 1400 540 800 400
sleep 1.5
input swipe 540 800 540 1400 400
sleep 2
wait $PID

# Scene 2: Create Account (signup)
echo ">>> [Scene 2/11] Create Account (Sign Up)"
am force-stop com.keyflow.keyflow_app
sleep 0.5
am start -n com.keyflow.keyflow_app/.MainActivity --ez DEMO_MODE true

sleep 1.5
screenrecord --time-limit 18 /sdcard/scene_02_signup.mp4 &
PID=$!
sleep 1
input tap 725 1740
sleep 1.5
input tap 540 660
input text "AlexMorgan"
sleep 0.5
input tap 540 820
input text "alex.morgan@keyflow.io"
sleep 0.5
input tap 540 980
input text "KeyFlow2026!"
sleep 0.5
input tap 540 1140
input text "KeyFlow2026!"
sleep 0.5
input tap 540 1320
sleep 2
input tap 540 1590
sleep 2
wait $PID

# Scene 3: Force-close and relaunch -> Sign In & Home Dashboard
echo ">>> [Scene 3/11] Sign In & Dashboard Navigation"
am force-stop com.keyflow.keyflow_app
sleep 0.5
am start -n com.keyflow.keyflow_app/.MainActivity --ez DEMO_MODE true

sleep 1.5
screenrecord --time-limit 18 /sdcard/scene_03_signin_home.mp4 &
PID=$!
sleep 1
input tap 540 1080
input text "alex.morgan@keyflow.io"
sleep 0.5
input tap 540 1240
input text "KeyFlow2026!"
sleep 0.5
input tap 540 1440
sleep 1
input tap 540 1590
sleep 2
input swipe 540 1600 540 600 500
sleep 1.5
input swipe 540 600 540 1600 500
sleep 2
wait $PID

# Scene 4: Accessibility & floating-bubble permission setup
echo ">>> [Scene 4/11] Accessibility & Overlay Permissions Setup"
am start -n com.keyflow.keyflow_app/.MainActivity --ez DEMO_MODE true

sleep 1
input tap 540 1590
sleep 0.5
screenrecord --time-limit 18 /sdcard/scene_04_permissions.mp4 &
PID=$!
sleep 1
input tap 972 2330
sleep 1.5
input swipe 540 1400 540 800 300
sleep 1
input tap 540 800
sleep 2
input tap 540 600
sleep 1.5
input keyevent 4
sleep 0.5
input keyevent 4
sleep 1.5
input swipe 540 800 540 1400 300
sleep 2
wait $PID

# Scene 5: Background typing capture in Chrome -> History
echo ">>> [Scene 5/11] Background Typing Capture & Grouping"
screenrecord --time-limit 20 /sdcard/scene_05_background_capture.mp4 &
PID=$!
sleep 1
am start -a android.intent.action.VIEW -d 'https://www.google.com' com.android.chrome
sleep 2.5
input tap 540 280
sleep 0.5
input text "KeyFlow_Smart_AI_Typing_Capture_Live_Demo"
sleep 2
am start -n com.keyflow.keyflow_app/.MainActivity --ez DEMO_MODE true

sleep 1.5
input tap 324 2330
sleep 2
input swipe 540 1400 540 600 400
sleep 1.5
input swipe 540 600 540 1400 400
sleep 2
wait $PID

# Scene 6: Sensitive data exclusion (Password field)
echo ">>> [Scene 6/11] Sensitive Data Exclusion & Redaction"
screenrecord --time-limit 18 /sdcard/scene_06_sensitive_exclusion.mp4 &
PID=$!
sleep 1
am start -a android.intent.action.VIEW -d 'https://www.google.com' com.android.chrome
sleep 2.5
input tap 540 280
sleep 0.5
input text "MySecretSuperPassword999!"
sleep 1.5
am start -n com.keyflow.keyflow_app/.MainActivity --ez DEMO_MODE true

sleep 1.5
input tap 324 2330
sleep 2
input swipe 540 1400 540 600 400
sleep 2
wait $PID

# Scene 7: Floating Bot Bubble & Pause Toggle
echo ">>> [Scene 7/11] Floating Assistant Bot & Quick Controls"
am start -n com.keyflow.keyflow_app/.MainActivity --ez DEMO_MODE true

sleep 1
input tap 972 2330
sleep 1
screenrecord --time-limit 20 /sdcard/scene_07_floating_bot.mp4 &
PID=$!
sleep 1
input swipe 540 1400 540 800 300
sleep 1
input tap 950 820
sleep 1.5
input keyevent 3
sleep 2
input tap 60 700
sleep 2
input tap 400 750
sleep 1.5
input tap 400 750
sleep 1.5
input tap 60 700
sleep 2
wait $PID

# Scene 8: History screen search & long-press copy
echo ">>> [Scene 8/11] Smart History Timeline & Search"
am start -n com.keyflow.keyflow_app/.MainActivity --ez DEMO_MODE true

sleep 1
screenrecord --time-limit 20 /sdcard/scene_08_history_search.mp4 &
PID=$!
sleep 1
input tap 324 2330
sleep 2
input swipe 540 1600 540 600 400
sleep 1.5
input swipe 540 600 540 1600 400
sleep 1.5
input tap 540 280
input text "KeyFlow"
sleep 2
input swipe 500 700 500 700 800
sleep 2
wait $PID

# Scene 9: Excluded Apps screen
echo ">>> [Scene 9/11] Excluded Apps Management"
am start -n com.keyflow.keyflow_app/.MainActivity --ez DEMO_MODE true

sleep 1
input tap 972 2330
sleep 1
screenrecord --time-limit 18 /sdcard/scene_09_excluded_apps.mp4 &
PID=$!
sleep 1
input swipe 540 1400 540 800 300
sleep 1
input tap 540 1180
sleep 2.5
input tap 540 280
input text "Chrome"
sleep 1.5
input tap 950 480
sleep 2
input keyevent 4
sleep 1
wait $PID

# Scene 10: Translate & Emoji utilities
echo ">>> [Scene 10/11] On-Device Translate & Emoji Utilities"
am start -n com.keyflow.keyflow_app/.MainActivity --ez DEMO_MODE true

sleep 1
screenrecord --time-limit 22 /sdcard/scene_10_translate_emoji.mp4 &
PID=$!
sleep 1
input tap 540 2330
sleep 2
input tap 553 1157
sleep 2
input tap 928 912
sleep 1.5
input tap 756 2330
sleep 2
input swipe 540 1600 540 600 400
sleep 1.5
input swipe 540 600 540 1600 400
sleep 1.5
input tap 553 2089
sleep 1.5
wait $PID

# Scene 11: Profile modal & sign out
echo ">>> [Scene 11/11] User Profile, 2FA Security & Sign Out"
am start -n com.keyflow.keyflow_app/.MainActivity --ez DEMO_MODE true

sleep 1
input tap 108 2330
sleep 1
screenrecord --time-limit 18 /sdcard/scene_11_profile_signout.mp4 &
PID=$!
sleep 1
input tap 970 206
sleep 2
input swipe 540 1600 540 700 400
sleep 2
input swipe 540 700 540 1600 400
sleep 1.5
input tap 540 1800
sleep 1.5
input keyevent 4
sleep 2
wait $PID

echo "================================================="
echo " ALL 11 MASTER SCENES COMPLETED ON DEVICE"
echo "================================================="
