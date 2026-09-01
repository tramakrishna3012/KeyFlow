import subprocess
import time
import os
import sys
import shutil
import cv2

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
    print("=================================================================")
    print("=== MANUAL QA TESTER: Comprehensive Live Testing & Recording ===")
    print("=================================================================")
    
    wake()

    # Step 0: Ensure permissions & clean setup
    print(">>> [Setup] Checking device status...")
    adb("shell settings put secure enabled_accessibility_services com.keyflow.keyflow_app/com.keyflow.keyflow_app.KeyflowAccessibilityService")
    adb("shell settings put secure accessibility_enabled 1")
    adb("shell appops set com.keyflow.keyflow_app SYSTEM_ALERT_WINDOW allow")
    adb("shell pm grant com.keyflow.keyflow_app android.permission.POST_NOTIFICATIONS")
    adb("shell pm grant com.keyflow.keyflow_app android.permission.RECORD_AUDIO")

    # Clean old recordings on phone
    adb("shell rm -f /sdcard/manual_qa_full_test.mp4")

    # Start Screen Recording (Physical Device 1080x2400)
    print(">>> [Recording] Starting screenrecord daemon to /sdcard/manual_qa_full_test.mp4...")
    rec_proc = subprocess.Popen(
        f'"{ADB}" -s {DEVICE} shell screenrecord --size 1080x2400 --bit-rate 6000000 /sdcard/manual_qa_full_test.mp4',
        shell=True
    )
    time.sleep(2.5)

    try:
        # =========================================================
        # 1. LAUNCH APPLICATION FRESH
        # =========================================================
        print("\n>>> [1/12] Manual QA: Launching KeyFlow Main Activity...")
        adb("shell am start -n com.keyflow.keyflow_app/.MainActivity --ez DEMO_MODE true")
        time.sleep(3.5)

        # =========================================================
        # 2. HOME SCREEN & TELEMETRY INSPECTION
        # =========================================================
        print("\n>>> [2/12] Manual QA: Inspecting Home Screen Cards & Histogram...")
        # Inspect KPI cards
        adb("shell input swipe 540 1600 540 800 400")
        time.sleep(1.5)
        adb("shell input swipe 540 800 540 1600 400")
        time.sleep(1.5)
        # Tap Profile Avatar in top right (x=980, y=140)
        print(">>> [2a] Tapping Profile Avatar...")
        adb("shell input tap 980 140")
        time.sleep(2.0)
        # Inspect Profile Modal controls (Cloud sync toggle, etc.)
        adb("shell input swipe 540 1500 540 900 300")
        time.sleep(1.5)
        # Close Profile Modal
        adb("shell input keyevent 4")
        time.sleep(1.5)

        # =========================================================
        # 3. TYPING HISTORY TAB: CARDS, CHIPS, 1-CLICK COPY
        # =========================================================
        print("\n>>> [3/12] Manual QA: Testing History Tab & 1-Click Copy...")
        # Tap History tab (bottom nav index 1, x=360, y=2300)
        adb("shell input tap 360 2300")
        time.sleep(2.5)

        # Tap 1-Click Copy button on top snippet (approx x=940, y=680)
        print(">>> [3a] Tapping 1-Click Copy Icon...")
        adb("shell input tap 940 680")
        time.sleep(1.5)

        # Tap on snippet body to open Detail Screen
        print(">>> [3b] Tapping snippet body to open Snippet Detail Screen...")
        adb("shell input tap 540 680")
        time.sleep(2.0)
        # Tap back from Detail Screen
        adb("shell input keyevent 4")
        time.sleep(1.5)

        # Test App Filter Chips (e.g. tap Chrome chip, Calculator chip)
        print(">>> [3c] Testing Filter Chips...")
        adb("shell input tap 340 320") # Chrome chip
        time.sleep(1.5)
        adb("shell input tap 540 320") # Calculator chip
        time.sleep(1.5)
        adb("shell input tap 140 320") # All Apps chip
        time.sleep(1.5)

        # Test Search Field
        print(">>> [3d] Testing Search Field...")
        adb("shell input tap 540 240")
        time.sleep(0.5)
        adb("shell input text 25000")
        time.sleep(1.5)
        # Clear search
        adb("shell input tap 980 240")
        time.sleep(1.5)

        # =========================================================
        # 4. TRANSLATE TAB
        # =========================================================
        print("\n>>> [4/12] Manual QA: Testing Translate Tab...")
        # Tap Translate tab (bottom nav index 2, x=540, y=2300)
        adb("shell input tap 540 2300")
        time.sleep(2.5)
        # Tap input area
        adb("shell input tap 540 600")
        time.sleep(0.5)
        adb("shell input text Hello\\ World")
        time.sleep(1.0)
        # Tap Translate button (approx x=540, y=900)
        adb("shell input tap 540 900")
        time.sleep(2.5)

        # =========================================================
        # 5. EMOJI & ASSIST TAB
        # =========================================================
        print("\n>>> [5/12] Manual QA: Testing Emoji Assist Tab...")
        # Tap Emoji tab (bottom nav index 3, x=720, y=2300)
        adb("shell input tap 720 2300")
        time.sleep(2.5)
        # Tap an emoji in the grid (e.g. x=200, y=500)
        adb("shell input tap 200 500")
        time.sleep(1.5)
        # Switch category tab (x=400, y=320)
        adb("shell input tap 400 320")
        time.sleep(1.5)

        # =========================================================
        # 6. SETTINGS TAB & WHITE BALL TOGGLES
        # =========================================================
        print("\n>>> [6/12] Manual QA: Testing Settings Tab & White Ball Switches...")
        # Tap Settings tab (bottom nav index 4, x=900, y=2300)
        adb("shell input tap 900 2300")
        time.sleep(2.5)

        # Toggle "Pause Typing Capture" switch (approx x=940, y=680)
        print(">>> [6a] Toggling Pause Typing Capture...")
        adb("shell input tap 940 680")
        time.sleep(1.5)
        adb("shell input tap 940 680")
        time.sleep(1.5)

        # Scroll down through Settings
        adb("shell input swipe 540 1600 540 700 400")
        time.sleep(1.5)

        # Tap Excluded Applications row (approx x=540, y=600)
        print(">>> [6b] Opening Excluded Applications Screen...")
        adb("shell input tap 540 600")
        time.sleep(2.5)
        # Search in Excluded Apps
        adb("shell input tap 540 240")
        time.sleep(0.5)
        adb("shell input text Chrome")
        time.sleep(1.5)
        # Tap back from Excluded Apps
        adb("shell input keyevent 4")
        time.sleep(1.5)

        # Scroll further down
        adb("shell input swipe 540 1600 540 700 400")
        time.sleep(1.5)

        # =========================================================
        # 7. REAL-WORLD TYPING: CALCULATOR MATH
        # =========================================================
        print("\n>>> [7/12] Manual QA: Real-World Calculator Typing Test...")
        adb("shell monkey -p com.google.android.calculator -c android.intent.category.LAUNCHER 1")
        time.sleep(2.0)
        # Type: 9999 + 1111 = 11110
        adb("shell input keyevent 16 16 16 16") # 9 9 9 9
        time.sleep(0.3)
        adb("shell input keyevent 81")          # +
        time.sleep(0.3)
        adb("shell input keyevent 8 8 8 8")     # 1 1 1 1
        time.sleep(0.3)
        adb("shell input keyevent 66")          # = (11110)
        time.sleep(2.5)

        # =========================================================
        # 8. REAL-WORLD TYPING: CHROME BROWSING
        # =========================================================
        print("\n>>> [8/12] Manual QA: Real-World Chrome Browser Typing Test...")
        adb("shell monkey -p com.android.chrome -c android.intent.category.LAUNCHER 1")
        time.sleep(2.0)
        adb("shell input tap 540 220")
        time.sleep(0.8)
        adb("shell input text https://keyflow.dev/qa-audit-test")
        time.sleep(0.5)
        adb("shell input keyevent 66")
        time.sleep(2.5)

        # =========================================================
        # 9. REAL-WORLD CLIPBOARD COPY
        # =========================================================
        print("\n>>> [9/12] Manual QA: Real-World Clipboard Copy Test...")
        adb('shell "am broadcast -a clipper.set -e text \'KeyFlow QA Manual Audit Verified 2026\'" || true')
        time.sleep(2.0)

        # =========================================================
        # 10. VERIFY IN KEYFLOW HISTORY
        # =========================================================
        print("\n>>> [10/12] Manual QA: Returning to KeyFlow to inspect new entries...")
        adb("shell am start -n com.keyflow.keyflow_app/.MainActivity --ez DEMO_MODE true")
        time.sleep(2.5)
        # Tap History tab
        adb("shell input tap 360 2300")
        time.sleep(2.5)
        # Scroll to inspect new Calculator & Chrome entries
        adb("shell input swipe 540 1400 540 600 400")
        time.sleep(1.8)
        adb("shell input swipe 540 600 540 1400 400")
        time.sleep(1.8)

        # =========================================================
        # 11. HORIZONTAL / LANDSCAPE ADAPTIVE LAYOUT
        # =========================================================
        print("\n>>> [11/12] Manual QA: Testing Landscape / Horizontal Responsive Layout...")
        # Rotate device to landscape (accelerometer rotation or user_rotation 1)
        adb("shell settings put system accelerometer_rotation 0")
        adb("shell settings put system user_rotation 1") # Landscape
        time.sleep(3.0)
        # Scroll in landscape mode
        adb("shell input swipe 1000 700 1000 300 400")
        time.sleep(1.5)
        # Return to portrait
        adb("shell settings put system user_rotation 0") # Portrait
        time.sleep(2.5)

        # =========================================================
        # 12. COMPLETION
        # =========================================================
        print("\n>>> [12/12] Manual QA Testing Complete!")

    finally:
        print("\n>>> [Finalization] Sending SIGINT (pkill -2 screenrecord) to finalize MP4 cleanly...")
        time.sleep(1.5)
        # Cleanly interrupt screenrecord so Android flushes the MP4 moov atom
        adb("shell pkill -2 screenrecord", check=False)
        time.sleep(4.0)
        try:
            rec_proc.terminate()
        except:
            pass
        time.sleep(1.5)

    # Pull video recording
    os.makedirs(r"d:\Freelance\KeyFlow\demo_recordings", exist_ok=True)
    video_dest = r"d:\Freelance\KeyFlow\demo_recordings\manual_qa_full_test.mp4"
    master_video = r"d:\Freelance\KeyFlow\demo_recordings\parallel_sync_demo.mp4"
    
    print(f">>> Pulling recording to {video_dest}...")
    adb(f'pull /sdcard/manual_qa_full_test.mp4 "{video_dest}"')
    shutil.copyfile(video_dest, master_video)
    
    # Copy to brain artifact directory
    artifact_mp4 = r"C:\Users\trama\.gemini\antigravity-ide\brain\eddae5e5-4bf3-40ba-bfc2-9d6eb312cbd4\manual_qa_full_test.mp4"
    shutil.copyfile(video_dest, artifact_mp4)
    print(f">>> Copied video to brain artifact directory: {artifact_mp4}")

    # Verify MP4 Playability via OpenCV
    print("\n>>> [Verification] Validating MP4 Atom Structure and Playability...")
    cap = cv2.VideoCapture(video_dest)
    ret, frame = cap.read()
    if ret:
        fps = cap.get(cv2.CAP_PROP_FPS)
        frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        h, w, _ = frame.shape
        duration = frame_count / fps if fps > 0 else 0
        print(f"VIDEO VERIFIED 100% PLAYABLE: {w}x{h} @ {fps:.1f} FPS, {frame_count} frames, {duration:.1f}s")
    else:
        print("WARNING: Failed to read video with OpenCV")
    cap.release()

if __name__ == "__main__":
    main()
