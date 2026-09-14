import os
import sys
import time
import shutil
import subprocess
import cv2
import numpy as np

WORKSPACE = r"d:\Freelance\KeyFlow"
DEMO_DIR = os.path.join(WORKSPACE, "demo_recordings")
OUTPUT_PATH = os.path.join(DEMO_DIR, "client_setup_tutorial.mp4")
ARTIFACT_DIR = r"C:\Users\trama\.gemini\antigravity-ide\brain\9a85915b-e2bc-4dd7-9831-39f28b1363c1"
FFMPEG = r"C:\Users\trama\.cursor\extensions\kilocode.kilo-code-7.4.15-win32-x64\bin\ffmpeg.exe"
ADB = r"C:\Users\trama\AppData\Local\Android\Sdk\platform-tools\adb.exe"
DEVICE = "ZD222GYVTF"

def adb(cmd):
    full_cmd = [ADB, "-s", DEVICE] + (cmd if isinstance(cmd, list) else cmd.split())
    res = subprocess.run(full_cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return (res.stdout or '').strip()

def create_slide(title, subtitle, bullets, duration_sec=4.0, fps=30, w=1920, h=1080):
    total_frames = int(duration_sec * fps)
    canvas = np.zeros((h, w, 3), dtype=np.uint8)
    
    # Modern sleek slate dark gradient
    for y in range(h):
        r = int(12 + (y / h) * 12)
        g = int(16 + (y / h) * 14)
        b = int(28 + (y / h) * 20)
        canvas[y, :] = [b, g, r]

    # Accent Top Header Bar
    cv2.rectangle(canvas, (0, 0), (w, 80), (35, 25, 45), -1)
    cv2.line(canvas, (0, 80), (w, 80), (241, 102, 99), 2)
    cv2.circle(canvas, (45, 40), 20, (241, 102, 99), -1)
    cv2.putText(canvas, "KF", (33, 47), cv2.FONT_HERSHEY_DUPLEX, 0.6, (255, 255, 255), 1, cv2.LINE_AA)
    cv2.putText(canvas, "KEYFLOW ENTERPRISE: CLIENT SETUP & SECURITY TUTORIAL", (80, 48), cv2.FONT_HERSHEY_DUPLEX, 0.7, (255, 255, 255), 1, cv2.LINE_AA)
    cv2.putText(canvas, "SYSTEM_KEY v1.0.0-rc", (w - 240, 48), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (100, 240, 160), 1, cv2.LINE_AA)

    # Main Card Container
    card_x1, card_y1, card_x2, card_y2 = 140, 160, w - 140, h - 120
    sub = canvas[card_y1:card_y2, card_x1:card_x2]
    card_overlay = np.full(sub.shape, (22, 18, 30), dtype=np.uint8)
    cv2.addWeighted(card_overlay, 0.90, sub, 0.10, 0, sub)
    canvas[card_y1:card_y2, card_x1:card_x2] = sub
    cv2.rectangle(canvas, (card_x1, card_y1), (card_x2, card_y2), (99, 102, 241), 2)

    # Title
    cv2.putText(canvas, title, (card_x1 + 60, card_y1 + 90), cv2.FONT_HERSHEY_DUPLEX, 1.3, (255, 255, 255), 2, cv2.LINE_AA)
    # Subtitle
    cv2.putText(canvas, subtitle, (card_x1 + 60, card_y1 + 145), cv2.FONT_HERSHEY_SIMPLEX, 0.85, (148, 163, 184), 1, cv2.LINE_AA)
    cv2.line(canvas, (card_x1 + 60, card_y1 + 175), (card_x2 - 60, card_y1 + 175), (51, 65, 85), 1)

    # Bullets
    curr_y = card_y1 + 240
    for bullet in bullets:
        cv2.circle(canvas, (card_x1 + 80, curr_y - 8), 8, (99, 102, 241), -1)
        cv2.circle(canvas, (card_x1 + 80, curr_y - 8), 4, (255, 255, 255), -1)
        cv2.putText(canvas, bullet, (card_x1 + 110, curr_y), cv2.FONT_HERSHEY_DUPLEX, 0.85, (241, 245, 249), 2, cv2.LINE_AA)
        curr_y += 75

    # Footer note
    cv2.putText(canvas, "Motorola Edge 40 Physical Validation Target • Android 15 • SQLCipher Hardware Keystore",
                (w // 2 - 380, h - 50), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (100, 116, 139), 1, cv2.LINE_AA)

    frames = [canvas.copy() for _ in range(total_frames)]
    return frames

def generate_tutorial_video():
    print("=" * 80)
    print("=== GENERATING HIGH-RESOLUTION CLIENT SETUP & TUTORIAL VIDEO ===")
    print("=" * 80)
    os.makedirs(DEMO_DIR, exist_ok=True)
    temp_raw_mp4 = os.path.join(DEMO_DIR, "tutorial_raw.mp4")

    w, h, fps = 1920, 1080, 30
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(temp_raw_mp4, fourcc, fps, (w, h))

    slides = [
        (
            "1. Headless Utility Launch & Stealth Presence",
            "Omitted from App Drawer: Launching via Settings (App Info) or Quick Settings Tile",
            [
                "App identified as 'System_Key' with native OS utility metadata",
                "Primary Launch Vector: Android Settings -> Apps -> System_Key -> 'Open'",
                "Secondary Launch Vector: Custom Quick Settings Notification Shade Tile",
                "Deep-Link Automation Vector: keyflow://vault/open"
            ],
            7.0
        ),
        (
            "2. Zero-Knowledge Cryptographic Authentication",
            "Hardware Keystore Integration & SQLCipher Local Database Encryption",
            [
                "Sign in with verified user credentials (user@keyflow.dev)",
                "Encryption keys derived from session entropy & Android Hardware Keystore (TEE)",
                "Local storage encrypted with SQLCipher AES-256 (keyflow_encrypted.db)",
                "Unauthenticated access returns 'file is encrypted or is not a database'"
            ],
            7.0
        ),
        (
            "3. Zero-Interference Filter for Financial & Banking Apps",
            "Eliminating Tapjacking Alerts & Dropping Processing Before UI Inspection",
            [
                "Early package inspection filters GPay, PhonePe, Paytm, BHIM, and net-banking",
                "Floating overlay auto-hides (View.GONE) to prevent filterTouchesWhenObscured warnings",
                "Zero data logged, buffered, or synchronized from financial environments",
                "Seamless banking UX with 100% fluid touch interaction"
            ],
            7.0
        ),
        (
            "4. Intelligent Paragraph Debounce Engine (2.5s)",
            "Consolidated Text Grouping without Single-Keystroke Noise",
            [
                "Continuous typing in notes/messengers buffers dynamically in memory",
                "2.5-second inactivity timer detects typing pauses and seals cohesive paragraphs",
                "Organized as: Session (Date) -> Application Name -> Consolidated Paragraph Card",
                "Session boundary triggers seal blocks upon app switch or 60s inactivity timeout"
            ],
            7.0
        ),
        (
            "5. Real-Time Cross-Device Synchronization & History",
            "End-to-End Encrypted Cloud Mirroring with Timeline Scrubber",
            [
                "Debounced paragraphs and copied URLs mirror in real time to Web Dashboard",
                "Timeline scrubber enables interactive draft revision recovery",
                "Background persistence maintained under stopWithTask=false",
                "Client setup verified and ready for production operations"
            ],
            8.0
        )
    ]

    for title, sub, bullets, dur in slides:
        print(f">>> Rendering slide: '{title}' ({dur:.1f}s)...")
        frames = create_slide(title, sub, bullets, duration_sec=dur, fps=fps, w=w, h=h)
        for frame in frames:
            out.write(frame)

    out.release()
    print(f">>> Raw tutorial frames written to: {temp_raw_mp4}")

    # Transcode with FFmpeg
    if os.path.exists(FFMPEG):
        print(f">>> Transcoding tutorial with FFmpeg (-c:v libx264 -pix_fmt yuv420p -movflags +faststart -r 30)...")
        ff_cmd = [
            FFMPEG, "-y", "-i", temp_raw_mp4,
            "-c:v", "libx264", "-pix_fmt", "yuv420p",
            "-movflags", "+faststart", "-r", "30",
            OUTPUT_PATH
        ]
        subprocess.run(ff_cmd, check=True)
        if os.path.exists(temp_raw_mp4):
            os.remove(temp_raw_mp4)
    else:
        if os.path.exists(OUTPUT_PATH):
            os.remove(OUTPUT_PATH)
        os.rename(temp_raw_mp4, OUTPUT_PATH)

    # Copy to artifact directory
    if os.path.exists(ARTIFACT_DIR) and os.path.exists(OUTPUT_PATH):
        artifact_mp4 = os.path.join(ARTIFACT_DIR, "client_setup_tutorial.mp4")
        shutil.copyfile(OUTPUT_PATH, artifact_mp4)
        print(f">>> [Artifact] Saved client setup tutorial video to: {artifact_mp4}")

    # Inspect final video
    cap = cv2.VideoCapture(OUTPUT_PATH)
    fps_val = cap.get(cv2.CAP_PROP_FPS) or 30.0
    frame_cnt = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    w_val = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    h_val = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    dur_val = frame_cnt / fps_val
    cap.release()

    print("=" * 80)
    print(f"[SUCCESS] CLIENT SETUP TUTORIAL VIDEO READY: {w_val}x{h_val} @ {fps_val:.1f} FPS, {frame_cnt} frames, {dur_val:.1f}s")
    print(f"File Path: file:///{OUTPUT_PATH.replace(chr(92), '/')}")
    print("=" * 80)
    return True

if __name__ == "__main__":
    generate_tutorial_video()
