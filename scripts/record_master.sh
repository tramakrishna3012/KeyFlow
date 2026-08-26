#!/system/bin/sh

wake() {
    input keyevent 224
    input keyevent 82
    input swipe 540 1800 540 400 200
    sleep 0.5
}

wake

# 1. demo_signup
echo ">>> [1/9] demo_signup"
am force-stop com.keyflow.keyflow_app
sleep 0.5
am start -n com.keyflow.keyflow_app/.MainActivity
sleep 1.5
screenrecord --time-limit 12 /sdcard/demo_signup.mp4 &
REC_PID=$!
sleep 1
input tap 725 1320
sleep 1
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
sleep 1.5
input tap 540 1160
sleep 2
input swipe 540 1400 540 800 400
wait $REC_PID

# 2. demo_login
echo ">>> [2/9] demo_login"
am force-stop com.keyflow.keyflow_app
sleep 0.5
am start -n com.keyflow.keyflow_app/.MainActivity
sleep 1.5
screenrecord --time-limit 11 /sdcard/demo_login.mp4 &
REC_PID=$!
sleep 1
input tap 540 660
input text "alex.morgan@keyflow.io"
sleep 0.5
input tap 540 820
input text "KeyFlow2026!"
sleep 0.5
input tap 540 1016
sleep 1
input tap 540 1160
sleep 1.5
input swipe 540 1400 540 700 400
sleep 1
input swipe 540 700 540 1400 400
wait $REC_PID

# 3. demo_accessibility_setup
echo ">>> [3/9] demo_accessibility_setup"
am start -n com.keyflow.keyflow_app/.MainActivity
sleep 1
screenrecord --time-limit 12 /sdcard/demo_accessibility_setup.mp4 &
REC_PID=$!
sleep 1
input tap 972 2330
sleep 1
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
wait $REC_PID

# 4. demo_typing_capture
echo ">>> [4/9] demo_typing_capture"
screenrecord --time-limit 13 /sdcard/demo_typing_capture.mp4 &
REC_PID=$!
sleep 1
am start -a android.intent.action.VIEW -d 'https://www.google.com' com.android.chrome
sleep 2
input tap 540 280
sleep 0.5
input text "KeyFlow_Live_Typing_Capture_Demo"
sleep 1.5
am start -n com.keyflow.keyflow_app/.MainActivity
sleep 1
input tap 324 2330
sleep 1.5
input swipe 540 1400 540 600 400
sleep 1.5
input swipe 540 600 540 1400 400
wait $REC_PID

# 5. demo_sensitive_exclusion
echo ">>> [5/9] demo_sensitive_exclusion"
screenrecord --time-limit 11 /sdcard/demo_sensitive_exclusion.mp4 &
REC_PID=$!
sleep 1
am start -a android.intent.action.VIEW -d 'https://www.google.com' com.android.chrome
sleep 2
input tap 540 280
sleep 0.5
input text "SecretPassword999!"
sleep 1
am start -n com.keyflow.keyflow_app/.MainActivity
sleep 1
input tap 324 2330
sleep 1.5
input swipe 540 1200 540 600 300
sleep 1
wait $REC_PID

# 6. demo_floating_bot
echo ">>> [6/9] demo_floating_bot"
am start -n com.keyflow.keyflow_app/.MainActivity
sleep 1
input tap 972 2330
sleep 1
screenrecord --time-limit 13 /sdcard/demo_floating_bot.mp4 &
REC_PID=$!
sleep 1
input swipe 540 1400 540 800 300
sleep 1
input tap 950 820
sleep 1.5
input keyevent 3
sleep 1.5
input tap 60 700
sleep 1.5
input tap 400 750
sleep 1
input tap 400 750
sleep 1
input tap 60 700
sleep 1
wait $REC_PID

# 7. demo_exclude_apps
echo ">>> [7/9] demo_exclude_apps"
am start -n com.keyflow.keyflow_app/.MainActivity
sleep 1
input tap 972 2330
sleep 1
screenrecord --time-limit 11 /sdcard/demo_exclude_apps.mp4 &
REC_PID=$!
sleep 1
input swipe 540 1400 540 800 300
sleep 1
input tap 540 1180
sleep 2
input tap 540 280
input text "Chrome"
sleep 1.5
input tap 950 480
sleep 1.5
input keyevent 4
wait $REC_PID

# 8. demo_history_screen
echo ">>> [8/9] demo_history_screen"
am start -n com.keyflow.keyflow_app/.MainActivity
sleep 1
screenrecord --time-limit 12 /sdcard/demo_history_screen.mp4 &
REC_PID=$!
sleep 1
input tap 324 2330
sleep 1.5
input swipe 540 1600 540 600 400
sleep 1
input swipe 540 600 540 1600 400
sleep 1
input tap 540 280
input text "KeyFlow"
sleep 1.5
input swipe 500 700 500 700 800
sleep 1.5
wait $REC_PID

# 9. demo_profile_account
echo ">>> [9/9] demo_profile_account"
am start -n com.keyflow.keyflow_app/.MainActivity
sleep 1
input tap 108 2330
sleep 1
screenrecord --time-limit 12 /sdcard/demo_profile_account.mp4 &
REC_PID=$!
sleep 1
input tap 970 206
sleep 2
input swipe 540 1600 540 700 400
sleep 1.5
input swipe 540 700 540 1600 400
sleep 1.5
input tap 540 1800
sleep 1.5
input keyevent 4
wait $REC_PID

echo "ALL DEMOS COMPLETED ON DEVICE."
