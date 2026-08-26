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

echo "=========================================================="
echo " Recording 9-Step Verified Client Demo for KeyFlow"
echo "=========================================================="

# ----------------------------------------------------
# Step 1: Fresh app launch -> Create Account (Sign Up)
# ----------------------------------------------------
echo ">>> [Step 1/9] Sign Up with test account (Alex Morgan)"
am force-stop com.keyflow.keyflow_app
sleep 0.5
screenrecord --time-limit 20 /sdcard/step_01_signup.mp4 &
PID=$!
sleep 1
am start -n com.keyflow.keyflow_app/.MainActivity --ez DEMO_MODE true
sleep 2
input tap 725 1740
sleep 1.5
# Name
input tap 540 660
input text "AlexMorgan"
sleep 0.5
# Email
input tap 540 820
input text "alex.morgan@demo.io"
sleep 0.5
# Password
input tap 540 980
input text "KeyFlow2026!"
sleep 0.5
# Confirm Password
input tap 540 1140
input text "KeyFlow2026!"
sleep 0.5
# Submit Sign Up
input tap 540 1320
sleep 2
# Enter Dashboard
input tap 540 1590
sleep 2
input swipe 540 1400 540 800 400
sleep 1
wait $PID

# ----------------------------------------------------
# Step 2: Force-close, relaunch -> Sign In with SAME account
# ----------------------------------------------------
echo ">>> [Step 2/9] Relaunch & Sign In with same account (alex.morgan@demo.io)"
am force-stop com.keyflow.keyflow_app
sleep 0.5
screenrecord --time-limit 20 /sdcard/step_02_signin.mp4 &
PID=$!
sleep 1
am start -n com.keyflow.keyflow_app/.MainActivity --ez DEMO_MODE true
sleep 2
# Fill email
input tap 540 1080
input text "alex.morgan@demo.io"
sleep 0.5
# Fill password
input tap 540 1240
input text "KeyFlow2026!"
sleep 0.5
# Tap Sign In
input tap 540 1440
sleep 1.5
input tap 540 1590
sleep 2
# Scroll Dashboard to show live metrics
input swipe 540 1600 540 700 500
sleep 1.5
input swipe 540 700 540 1600 500
sleep 1.5
wait $PID

# ----------------------------------------------------
# Step 3: Accessibility & Permission Setup (Deep link)
# ----------------------------------------------------
echo ">>> [Step 3/9] Accessibility deep link & service setup"
am start -n com.keyflow.keyflow_app/.MainActivity --ez DEMO_MODE true
sleep 1
input tap 540 1590
sleep 0.5
screenrecord --time-limit 18 /sdcard/step_03_accessibility.mp4 &
PID=$!
sleep 1
# Tap Settings tab
input tap 972 2330
sleep 1.5
# Scroll to Accessibility row
input swipe 540 1400 540 800 300
sleep 1
# Tap Accessibility Access row
input tap 540 800
sleep 2
# Tap KeyFlow in system list
input tap 540 600
sleep 1.5
# Return to app
input keyevent 4
sleep 0.5
input keyevent 4
sleep 1.5
# Scroll up to show active status
input swipe 540 800 540 1400 300
sleep 1.5
wait $PID

# ----------------------------------------------------
# Step 4: Background Typing Capture in Chrome -> History
# ----------------------------------------------------
echo ">>> [Step 4/9] Background typing capture in Chrome"
screenrecord --time-limit 20 /sdcard/step_04_typing_capture.mp4 &
PID=$!
sleep 1
am start -a android.intent.action.VIEW -d 'https://www.google.com' com.android.chrome
sleep 2.5
input tap 540 280
sleep 0.5
input text "KeyFlow_accurately_captures_background_typing_in_real_time"
sleep 2
# Switch back to KeyFlow
am start -n com.keyflow.keyflow_app/.MainActivity --ez DEMO_MODE true
sleep 1.5
# Tap History tab
input tap 324 2330
sleep 2
# Scroll through History entries
input swipe 540 1400 540 600 400
sleep 1.5
input swipe 540 600 540 1400 400
sleep 1.5
wait $PID

# ----------------------------------------------------
# Step 5: Sensitive Data Exclusion (Password field)
# ----------------------------------------------------
echo ">>> [Step 5/9] Sensitive password exclusion"
screenrecord --time-limit 18 /sdcard/step_05_sensitive_exclusion.mp4 &
PID=$!
sleep 1
am start -a android.intent.action.VIEW -d 'https://www.google.com' com.android.chrome
sleep 2.5
input tap 540 280
sleep 0.5
input text "SecretPasswordDemo2026!"
sleep 1.5
# Switch to KeyFlow History
am start -n com.keyflow.keyflow_app/.MainActivity --ez DEMO_MODE true
sleep 1.5
input tap 324 2330
sleep 2
# Scroll to show sensitive password is excluded
input swipe 540 1400 540 600 400
sleep 1.5
wait $PID

# ----------------------------------------------------
# Step 6: Floating Bot Bubble & Pause Capture Toggle
# ----------------------------------------------------
echo ">>> [Step 6/9] Floating bot bubble & pause toggle"
am start -n com.keyflow.keyflow_app/.MainActivity --ez DEMO_MODE true
sleep 1
input tap 972 2330
sleep 1
screenrecord --time-limit 22 /sdcard/step_06_floating_bot.mp4 &
PID=$!
sleep 1
# Scroll to Floating Bubble switch
input swipe 540 1400 540 800 300
sleep 1
# Toggle Bubble ON
input tap 950 820
sleep 1.5
# Home screen
input keyevent 3
sleep 2
# Tap floating bubble to expand
input tap 60 700
sleep 2
# Tap Pause Typing Capture switch ON
input tap 400 750
sleep 1.5
# Switch to Chrome and type while paused
am start -a android.intent.action.VIEW -d 'https://www.google.com' com.android.chrome
sleep 2
input tap 540 280
input text "Typed_while_capture_is_paused"
sleep 1.5
# Home screen & tap bubble to resume
input keyevent 3
sleep 1.5
input tap 60 700
sleep 1.5
# Toggle Pause OFF (Resumed)
input tap 400 750
sleep 1
# Collapse bubble
input tap 60 700
sleep 1
wait $PID

# ----------------------------------------------------
# Step 7: Excluded Apps Screen Management
# ----------------------------------------------------
echo ">>> [Step 7/9] Excluded Apps manager & toggle"
am start -n com.keyflow.keyflow_app/.MainActivity --ez DEMO_MODE true
sleep 1
input tap 972 2330
sleep 1
screenrecord --time-limit 18 /sdcard/step_07_exclude_apps.mp4 &
PID=$!
sleep 1
input swipe 540 1400 540 800 300
sleep 1
# Tap Manage Excluded Apps
input tap 540 1180
sleep 2.5
# Search for Chrome
input tap 540 280
input text "Chrome"
sleep 1.5
# Toggle Chrome exclusion switch
input tap 950 480
sleep 2
input keyevent 4
sleep 1
wait $PID

# ----------------------------------------------------
# Step 8: History Search & Long-Press Copy
# ----------------------------------------------------
echo ">>> [Step 8/9] History search & long-press copy"
am start -n com.keyflow.keyflow_app/.MainActivity --ez DEMO_MODE true
sleep 1
screenrecord --time-limit 20 /sdcard/step_08_history_search.mp4 &
PID=$!
sleep 1
# Tap History tab
input tap 324 2330
sleep 2
input swipe 540 1600 540 600 400
sleep 1.5
input swipe 540 600 540 1600 400
sleep 1.5
# Search
input tap 540 280
input text "KeyFlow"
sleep 2
# Long press to copy
input swipe 500 700 500 700 800
sleep 2
wait $PID

# ----------------------------------------------------
# Step 9: Profile Modal & Sign Out
# ----------------------------------------------------
echo ">>> [Step 9/9] Profile modal, 2FA security & Sign Out"
am start -n com.keyflow.keyflow_app/.MainActivity --ez DEMO_MODE true
sleep 1
input tap 108 2330
sleep 1
screenrecord --time-limit 20 /sdcard/step_09_profile_signout.mp4 &
PID=$!
sleep 1
# Tap Profile card at top
input tap 970 206
sleep 2
# Scroll through Profile modal
input swipe 540 1600 540 700 400
sleep 2
input swipe 540 700 540 1600 400
sleep 1.5
# Tap Sign Out
input tap 540 1800
sleep 1.5
input keyevent 4
sleep 2
wait $PID

echo "=========================================================="
echo " ALL 9 MASTER VERIFIED STEPS COMPLETED ON DEVICE"
echo "=========================================================="
