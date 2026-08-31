import subprocess
import time
import os
import sys

ADB = r"C:\Users\trama\AppData\Local\Android\Sdk\platform-tools\adb.exe"

DEVICE = "ZD222GYVTF"

def adb(cmd, check=True):
    full_cmd = f'"{ADB}" -s {DEVICE} {cmd}'
    print(f"[ADB] {full_cmd}")
    res = subprocess.run(full_cmd, shell=True, capture_output=True, text=True)
    if check and res.returncode != 0:
        print(f"[ERROR] {res.stderr}")
    return res.stdout.strip()

def wake():
    adb("shell input keyevent 224")
    adb("shell input keyevent 82")
    adb("shell input swipe 540 1800 540 400 200")
    time.sleep(0.5)

def main():
    print("=== Starting Full E2E Human-Like Manual Test of KeyFlow on Physical Device ===")
    wake()

    # Permissions
    adb("shell settings put secure enabled_accessibility_services com.keyflow.keyflow_app/com.keyflow.keyflow_app.KeyflowAccessibilityService")
    adb("shell settings put secure accessibility_enabled 1")
    adb("shell appops set com.keyflow.keyflow_app SYSTEM_ALERT_WINDOW allow")
    adb("shell pm grant com.keyflow.keyflow_app android.permission.POST_NOTIFICATIONS")

    # Start Screen Recording in Background
    print(">>> Starting screen recording to /sdcard/keyflow_full_e2e.mp4...")
    rec_proc = subprocess.Popen(f'"{ADB}" -s {DEVICE} shell screenrecord --time-limit 180 /sdcard/keyflow_full_e2e.mp4', shell=True)
    time.sleep(2)

    try:
        # Step 1: Launch KeyFlow
        print(">>> [Step 1] Launching KeyFlow Main Activity...")
        adb("shell am force-stop com.keyflow.keyflow_app")
        time.sleep(1)
        adb("shell am start -n com.keyflow.keyflow_app/.MainActivity --ez DEMO_MODE true")
        time.sleep(3)

        # Step 2: Sign In with test account
        print(">>> [Step 2] Authenticating with tramakrishna3012@gmail.com...")
        # Check if login or onboarding
        # Tap email field
        adb("shell input tap 540 1080")
        time.sleep(0.5)
        # Clear and enter email
        adb("shell input text tramakrishna3012@gmail.com")
        time.sleep(0.5)
        # Tap password field
        adb("shell input tap 540 1240")
        time.sleep(0.5)
        adb("shell input text \\#TRama1230")
        time.sleep(0.5)
        # Tap Sign In button
        adb("shell input tap 540 1440")
        time.sleep(2)
        # If on onboarding/get started
        adb("shell input tap 540 1590")
        time.sleep(2)

        # Step 3: Explore Dashboard & Metrics
        print(">>> [Step 3] Inspecting Dashboard...")
        adb("shell input swipe 540 1600 540 700 500")
        time.sleep(1.5)
        adb("shell input swipe 540 700 540 1600 500")
        time.sleep(1.5)

        # Step 4: Open Calculator and Type calculation
        print(">>> [Step 4] Opening Calculator and Typing calculation: 4500+5500+2000...")
        adb("shell monkey -p com.google.android.calculator -c android.intent.category.LAUNCHER 1")
        time.sleep(2)
        # Type numbers using keyevents or coordinates
        # 4, 5, 0, 0
        adb("shell input keyevent 11 12 7 7")
        time.sleep(0.4)
        # + (keyevent 81 or plus)
        adb("shell input keyevent 81")
        time.sleep(0.4)
        # 5, 5, 0, 0
        adb("shell input keyevent 12 12 7 7")
        time.sleep(0.4)
        adb("shell input keyevent 81")
        time.sleep(0.4)
        # 2, 0, 0, 0
        adb("shell input keyevent 9 7 7 7")
        time.sleep(0.4)
        # = (keyevent 66 for enter / equals)
        adb("shell input keyevent 66")
        time.sleep(2.5)

        # Step 5: Open Chrome and Type search query
        print(">>> [Step 5] Opening Chrome and Typing search query...")
        adb("shell monkey -p com.android.chrome -c android.intent.category.LAUNCHER 1")
        time.sleep(2.5)
        # Tap search bar
        adb("shell input tap 540 220")
        time.sleep(1)
        adb("shell input text https://keyflow.dev/demo")
        time.sleep(0.5)
        adb("shell input keyevent 66")
        time.sleep(2)

        # Step 6: Return to KeyFlow History Tab
        print(">>> [Step 6] Navigating to KeyFlow History Tab...")
        adb("shell am start -n com.keyflow.keyflow_app/.MainActivity --ez DEMO_MODE true")
        time.sleep(2)
        # Tap History tab in bottom nav (approx x=360, y=2250 on 1080x2400)
        adb("shell input tap 360 2280")
        time.sleep(2)
        # Scroll through history to show 2-level grouped UI
        adb("shell input swipe 540 1400 540 700 400")
        time.sleep(1.5)
        adb("shell input swipe 540 700 540 1400 400")
        time.sleep(1.5)

        # Step 7: Test 1-Click Copy Button
        print(">>> [Step 7] Testing 1-Click Copy Snippet Action...")
        # Tap the copy button on the first snippet (approx right side x=950, y=650)
        adb("shell input tap 940 680")
        time.sleep(1.5)

        # Step 8: Test Search Filter
        print(">>> [Step 8] Testing Search in History...")
        adb("shell input tap 540 240")
        time.sleep(0.5)
        adb("shell input text 4500")
        time.sleep(1.5)
        adb("shell input keyevent 66")
        time.sleep(2)

        # Step 9: Settings & Accessibility Toggle
        print(">>> [Step 9] Testing Settings Screen...")
        adb("shell input tap 900 2280")
        time.sleep(2)
        adb("shell input swipe 540 1500 540 700 400")
        time.sleep(1.5)
        adb("shell input swipe 540 700 540 1500 400")
        time.sleep(1.5)

        print("=== Manual Human-Like E2E Flow Finished Successfully ===")

    finally:
        print(">>> Stopping recording...")
        time.sleep(2)
        try:
            rec_proc.terminate()
        except:
            pass
        time.sleep(3)

    # Pull video recording
    os.makedirs(r"d:\Freelance\KeyFlow\demo_recordings", exist_ok=True)
    video_dest = r"d:\Freelance\KeyFlow\demo_recordings\keyflow_full_e2e.mp4"
    adb(f"pull /sdcard/keyflow_full_e2e.mp4 \"{video_dest}\"")
    print(f"Recorded video saved to {video_dest}")

if __name__ == "__main__":
    main()
