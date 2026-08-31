import subprocess
import time
import os
import sys
import shutil

ADB = r"C:\Users\trama\AppData\Local\Android\Sdk\platform-tools\adb.exe"

def get_device():
    res = subprocess.run(f'"{ADB}" devices', shell=True, capture_output=True, text=True)
    for line in res.stdout.strip().split('\n')[1:]:
        if '\tdevice' in line:
            return line.split('\t')[0].strip()
    return None

DEVICE = get_device()

def adb(cmd, check=True):
    dev_flag = f"-s {DEVICE}" if DEVICE else ""
    full_cmd = f'"{ADB}" {dev_flag} {cmd}'
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
    print("=== Starting Parallel Mobile & Web Live Sync Recording Flow ===")
    wake()

    # Step 0: Install updated APK with Clipboard capture and Calculator privacy fixes
    apk_path = r"d:\Freelance\KeyFlow\app\build\app\outputs\flutter-apk\app-debug.apk"
    if os.path.exists(apk_path):
        print(f">>> Installing updated APK from {apk_path}...")
        adb(f'install -r -d "{apk_path}"')
        time.sleep(2)

    # Reset App State for fresh Sign Up demonstration
    print(">>> Preparing clean environment...")
    adb("shell pm clear com.keyflow.keyflow_app")
    time.sleep(1)

    # Set required permissions
    adb("shell settings put secure enabled_accessibility_services com.keyflow.keyflow_app/com.keyflow.keyflow_app.KeyflowAccessibilityService")
    adb("shell settings put secure accessibility_enabled 1")
    adb("shell appops set com.keyflow.keyflow_app SYSTEM_ALERT_WINDOW allow")
    adb("shell pm grant com.keyflow.keyflow_app android.permission.POST_NOTIFICATIONS")
    adb("shell pm grant com.keyflow.keyflow_app android.permission.RECORD_AUDIO")

    # Clean previous recordings on device
    adb("shell rm -f /sdcard/parallel_sync_demo.mp4")

    # Start Screen Recording
    print(">>> Starting screen recording on physical device to /sdcard/parallel_sync_demo.mp4...")
    rec_proc = subprocess.Popen(f'"{ADB}" -s {DEVICE} shell screenrecord --size 1080x2400 --bit-rate 6000000 /sdcard/parallel_sync_demo.mp4', shell=True)
    time.sleep(2.5)

    try:
        # Step 1: Launch KeyFlow fresh
        print(">>> [Step 1] Fresh Launch of KeyFlow...")
        adb("shell am start -n com.keyflow.keyflow_app/.MainActivity --ez DEMO_MODE true")
        time.sleep(3.5)

        # Onboarding screen navigation
        adb("shell input tap 540 2150")
        time.sleep(1.5)
        adb("shell input tap 540 2150")
        time.sleep(1.5)
        adb("shell input tap 540 2150")
        time.sleep(2)

        # Step 2: Sign Up with clean account
        print(">>> [Step 2] Sign Up Flow on Mobile...")
        # Toggle to Sign Up mode (tap "Don't have an account? Sign Up")
        adb("shell input tap 720 1720")
        time.sleep(1)

        # Enter Full Name
        adb("shell input tap 540 680")
        time.sleep(0.5)
        adb("shell input text Rama\\ Krishna")
        time.sleep(0.5)

        # Enter Email
        adb("shell input tap 540 840")
        time.sleep(0.5)
        adb("shell input text tramakrishna3012@gmail.com")
        time.sleep(0.5)

        # Enter Password
        adb("shell input tap 540 1000")
        time.sleep(0.5)
        adb("shell input text \\#TRama1230")
        time.sleep(0.5)

        # Tap Submit (Create Account)
        adb("shell input tap 540 1200")
        time.sleep(3)

        # Ensure inside Dashboard
        adb("shell input tap 540 1440")
        time.sleep(2)
        adb("shell input tap 540 1590")
        time.sleep(2)

        # Step 3: Explore Dashboard & Active Monitoring
        print(">>> [Step 3] Exploring Dashboard & Live Telemetry...")
        adb("shell input swipe 540 1600 540 700 500")
        time.sleep(1.5)
        adb("shell input swipe 540 700 540 1600 500")
        time.sleep(1.5)

        # Step 4: Real Typing in Calculator
        print(">>> [Step 4] Opening Calculator and typing: 75000+25000=100000...")
        adb("shell monkey -p com.google.android.calculator -c android.intent.category.LAUNCHER 1")
        time.sleep(2)
        # 7, 5, 0, 0, 0
        adb("shell input keyevent 14 12 7 7 7")
        time.sleep(0.3)
        # + (plus)
        adb("shell input keyevent 81")
        time.sleep(0.3)
        # 2, 5, 0, 0, 0
        adb("shell input keyevent 9 12 7 7 7")
        time.sleep(0.3)
        # = (enter)
        adb("shell input keyevent 66")
        time.sleep(2.5)

        # Step 5: Test Clipboard Copy feature
        print(">>> [Step 5] Testing Clipboard Copied Text Capture Feature...")
        # Copy a text snippet to clipboard using Android broadcast/shell
        adb("shell monkey -p com.android.chrome -c android.intent.category.LAUNCHER 1")
        time.sleep(2)
        adb("shell input tap 540 220")
        time.sleep(0.8)
        adb("shell input text https://keyflow.dev/sync-test")
        time.sleep(0.5)
        adb("shell input keyevent 66")
        time.sleep(2)

        # Step 6: Return to KeyFlow History Tab
        print(">>> [Step 6] Navigating to KeyFlow History Tab...")
        adb("shell am start -n com.keyflow.keyflow_app/.MainActivity --ez DEMO_MODE true")
        time.sleep(2.5)
        # Tap History tab
        adb("shell input tap 360 2280")
        time.sleep(2.5)

        # Scroll through 2-level grouped history
        adb("shell input swipe 540 1400 540 700 400")
        time.sleep(1.5)
        adb("shell input swipe 540 700 540 1400 400")
        time.sleep(1.5)

        # Step 7: Tap 1-Click Copy on Snippet
        print(">>> [Step 7] Tapping 1-Click Copy button on Snippet...")
        adb("shell input tap 940 680")
        time.sleep(1.5)

        # Step 8: Search in History
        print(">>> [Step 8] Testing History Search...")
        adb("shell input tap 540 240")
        time.sleep(0.5)
        adb("shell input text 75000")
        time.sleep(1.5)
        adb("shell input keyevent 66")
        time.sleep(2)

        # Step 9: Settings Tab & Switch Toggle Demonstration
        print(">>> [Step 9] Navigating to Settings Tab to demonstrate White Ball Switch Toggle...")
        adb("shell input tap 900 2280")
        time.sleep(2)
        adb("shell input swipe 540 1500 540 700 400")
        time.sleep(1.5)
        adb("shell input swipe 540 700 540 1500 400")
        time.sleep(1.5)

        print("=== Physical Device Testing Sequence Complete ===")

    finally:
        print(">>> Finalizing video recording cleanly with SIGINT...")
        time.sleep(1.5)
        # Cleanly interrupt screenrecord so Android flushes the MP4 moov atom
        adb("shell pkill -2 screenrecord", check=False)
        time.sleep(3.5)
        try:
            rec_proc.terminate()
        except:
            pass
        time.sleep(1.5)

    # Pull video recording
    os.makedirs(r"d:\Freelance\KeyFlow\demo_recordings", exist_ok=True)
    video_dest = r"d:\Freelance\KeyFlow\demo_recordings\parallel_sync_demo.mp4"
    adb(f'pull /sdcard/parallel_sync_demo.mp4 "{video_dest}"')
    print(f"Recorded video saved to {video_dest}")

    # Copy to brain artifact directory for user access
    artifact_dest = r"C:\Users\trama\.gemini\antigravity-ide\brain\eddae5e5-4bf3-40ba-bfc2-9d6eb312cbd4\parallel_sync_demo.mp4"
    shutil.copyfile(video_dest, artifact_dest)
    print(f"Copied video to artifact directory: {artifact_dest}")

if __name__ == "__main__":
    main()
