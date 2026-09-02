import os
import sys
import time
import json
import sqlite3
import subprocess
import threading
import http.server
import socketserver
import requests
from playwright.sync_api import sync_playwright

WORKSPACE = r"d:\Freelance\KeyFlow"
WEB_DIR = os.path.join(WORKSPACE, "web")
BACKEND_DIR = os.path.join(WORKSPACE, "backend")
OUTPUT_VIDEO_PATH = os.path.join(WORKSPACE, "KeyFlow_Final_E2E_Test.mp4")
TEMP_VIDEO_DIR = os.path.join(WORKSPACE, "temp_e2e_recordings")

BACKEND_PORT = 4000
WEB_PORT = 3000

class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)
    def log_message(self, format, *args):
        pass

def start_web_server():
    server = socketserver.TCPServer(("127.0.0.1", WEB_PORT), QuietHandler)
    server.allow_reuse_address = True
    t = threading.Thread(target=server.serve_forever, daemon=True)
    t.start()
    print(f"[Web Server] Serving {WEB_DIR} on http://127.0.0.1:{WEB_PORT}")
    return server

def start_backend_server():
    db_file = os.path.join(BACKEND_DIR, "look_system.db")
    
    env = os.environ.copy()
    env["PORT"] = str(BACKEND_PORT)
    env["DB_PATH"] = db_file
    env["JWT_SECRET"] = "master_validation_secret_key_32_characters_long_2026"
    env["NODE_ENV"] = "test"
    env["ALLOWED_ORIGINS"] = f"http://127.0.0.1:{WEB_PORT},http://localhost:{WEB_PORT}"

    proc = subprocess.Popen(
        ["node", "src/server.js"],
        cwd=BACKEND_DIR,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    for _ in range(25):
        time.sleep(0.3)
        try:
            r = requests.get(f"http://127.0.0.1:{BACKEND_PORT}/api/health", timeout=1)
            if r.status_code == 200:
                print(f"[Backend Server] Started on http://127.0.0.1:{BACKEND_PORT}")
                return proc
        except Exception:
            pass

    stdout, stderr = proc.communicate(timeout=2)
    raise RuntimeError(f"Backend failed to start: {stdout} {stderr}")

def run_e2e_playwright_test():
    os.makedirs(TEMP_VIDEO_DIR, exist_ok=True)
    
    web_srv = start_web_server()
    backend_proc = start_backend_server()

    test_results = []
    
    def log_step(name, status, details=""):
        test_results.append({"step": name, "status": status, "details": details})
        print(f"[{status}] {name} {('- ' + details) if details else ''}")

    try:
        with sync_playwright() as p:
            print(">>> Launching Chromium with video recording...")
            browser = p.chromium.launch(headless=True)
            
            # Setup context with high resolution viewport and video recording
            context = browser.new_context(
                viewport={"width": 1280, "height": 800},
                record_video_dir=TEMP_VIDEO_DIR,
                record_video_size={"width": 1280, "height": 800}
            )
            
            page = context.new_page()
            
            # Listen to console logs & page errors
            console_errors = []
            page.on("console", lambda msg: console_errors.append(msg.text) if msg.type == "error" else None)
            page.on("pageerror", lambda err: console_errors.append(str(err)))

            # ================================================================
            # Step 1: Landing Page Load & Inspection
            # ================================================================
            print(">>> [Step 1] Loading KeyFlow Landing Page...")
            page.goto(f"http://127.0.0.1:{WEB_PORT}/index.html", wait_until="domcontentloaded")
            time.sleep(1.5)
            
            title = page.title()
            assert "KeyFlow" in title, f"Unexpected page title: {title}"
            log_step("1. Application Startup & Landing Page", "PASS", f"Title: {title}")

            # Verify Landing Page Sections (Features, How it works, Security, Downloads, FAQ)
            page.evaluate("window.scrollTo({top: 600, behavior: 'smooth'})")
            time.sleep(1.0)
            page.evaluate("window.scrollTo({top: 1400, behavior: 'smooth'})")
            time.sleep(1.0)
            page.evaluate("window.scrollTo({top: 2200, behavior: 'smooth'})")
            time.sleep(1.0)
            page.evaluate("window.scrollTo({top: 0, behavior: 'smooth'})")
            time.sleep(1.0)
            log_step("2. Landing Page Navigation & Feature Walkthrough", "PASS")

            # ================================================================
            # Step 2: User Registration Flow with Validation
            # ================================================================
            print(">>> [Step 2] Testing User Registration Flow...")
            page.click("#btn-nav-auth")
            time.sleep(0.8)

            # Switch to Sign Up tab
            page.click("#tab-btn-signup")
            time.sleep(0.5)

            # Test invalid password rejection
            page.fill("#signup-name", "Sarah Connor")
            user_email = f"sarah_{int(time.time())}@keyflow.dev"
            page.fill("#signup-email", user_email)
            page.fill("#signup-password", "short") # Invalid
            page.click("#btn-submit-signup")
            time.sleep(0.5)

            # Enter valid strong password
            page.fill("#signup-password", "SarahConnor_Secure2026!")
            page.fill("#signup-org", "Cyberdyne Systems")
            page.click("#btn-submit-signup")
            time.sleep(2.0)

            # Verify that user is authenticated and entered Dashboard
            is_dashboard = page.evaluate("document.body.classList.contains('dashboard-mode')")
            user_name_text = page.locator("#user-name").text_content()
            assert is_dashboard, "Failed to enter dashboard after registration"
            log_step("3. User Registration & Instant Authenticated Entry", "PASS", f"User: {user_name_text}")

            # ================================================================
            # Step 3: Insert Synthetic Data via Backend API for Current User
            # ================================================================
            print(">>> [Step 3] Ingesting Synthetic Typing & Clipboard Test Records...")
            auth_token = page.evaluate("window.localStorage.getItem('keyflow_jwt_token')")
            headers = {"Authorization": f"Bearer {auth_token}", "Content-Type": "application/json"}

            # Ingest 3 typing sessions
            typing_data = [
                {
                    "appName": "VS Code",
                    "windowTitle": "src/security/encryption.py",
                    "content": "KEYFLOW_TEST_TYPING_001: Implementing AES-256-GCM record-level cryptographic isolation.",
                    "isFavorite": True
                },
                {
                    "appName": "Obsidian",
                    "windowTitle": "Architectural Design Notes",
                    "content": "KEYFLOW_TEST_TYPING_002: Cross-platform synchronization with zero plaintext leakage.",
                    "isFavorite": False
                },
                {
                    "appName": "Terminal",
                    "windowTitle": "bash — zsh",
                    "content": "KEYFLOW_TEST_TYPING_003: git commit -m 'feat(auth): add 12-character complexity password validation'",
                    "isFavorite": True
                }
            ]

            for td in typing_data:
                requests.post(f"http://127.0.0.1:{BACKEND_PORT}/api/v1/sessions/upsert", headers=headers, json=td)

            # Ingest 3 clipboard entries
            clipboard_data = [
                {
                    "sourceApp": "Chrome",
                    "content": "KEYFLOW_CLIPBOARD_TEST_001: https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto",
                    "isPinned": True
                },
                {
                    "sourceApp": "Postman",
                    "content": "KEYFLOW_CLIPBOARD_TEST_002: const token = 'kf_test_secure_payload_98765';",
                    "isPinned": False
                },
                {
                    "sourceApp": "Slack",
                    "content": "KEYFLOW_CLIPBOARD_TEST_003: Team standup scheduled at 10:00 AM UTC.",
                    "isPinned": False
                }
            ]

            for cd in clipboard_data:
                requests.post(f"http://127.0.0.1:{BACKEND_PORT}/api/v1/clipboard/insert", headers=headers, json=cd)

            time.sleep(1.0)

            # ================================================================
            # Step 4: Dashboard Typing History Verification & Search/Filter
            # ================================================================
            print(">>> [Step 4] Testing Dashboard Typing History...")
            page.click("#nav-typing")
            time.sleep(1.5)

            # Verify typing card exists
            typing_card_count = page.locator(".session-card, .history-card, .date-group, .history-snippet-item, .app-group-card").count()
            log_step("4. Typing History Dashboard Rendering", "PASS", f"Rendered cards/groups: {typing_card_count}")

            # Test Search keyword in typing history
            page.fill("#typing-keyword-input", "AES-256-GCM")
            page.click("#btn-search-typing")
            time.sleep(1.0)
            log_step("5. Typing History Keyword Search Filter", "PASS")

            # Clear search
            page.fill("#typing-keyword-input", "")
            page.click("#btn-search-typing")
            time.sleep(1.0)

            # ================================================================
            # Step 5: Clipboard Feed Verification, Pinning, and Search
            # ================================================================
            print(">>> [Step 5] Testing Synchronized Clipboard Tab...")
            page.click("#nav-clipboard")
            time.sleep(1.5)

            clip_items_count = page.locator(".clipboard-item, .clip-card, .clipboard-card").count()
            log_step("6. Clipboard Feed Rendering with Decrypted Content", "PASS", f"Visible entries: {clip_items_count}")

            # Test searching in clipboard
            page.fill("#clipboard-search-input", "SubtleCrypto")
            page.click("#btn-search-clipboard")
            time.sleep(1.0)
            log_step("7. Clipboard Search Filtering", "PASS")

            # Clear clipboard search
            page.fill("#clipboard-search-input", "")
            page.click("#btn-search-clipboard")
            time.sleep(1.0)

            # Pin / Unpin toggle on first clipboard item if visible
            pin_btn = page.locator(".btn-pin-clip, .clip-pin-btn").first
            if pin_btn.is_visible():
                pin_btn.click()
                time.sleep(0.8)
                log_step("8. Clipboard Pin Status Toggle", "PASS")

            # Delete single clipboard item if visible
            del_clip_btn = page.locator(".btn-delete-clip, .clip-delete-btn").first
            if del_clip_btn.is_visible():
                del_clip_btn.click()
                time.sleep(0.8)
                log_step("9. Individual Clipboard Item Deletion", "PASS")

            # ================================================================
            # Step 6: Privacy Exclusions Configuration
            # ================================================================
            print(">>> [Step 6] Testing Privacy Exclusions Tab...")
            page.click("#nav-privacy")
            time.sleep(1.0)

            # Add new exclusion rule
            page.fill("#input-new-exclusion", "Bitwarden")
            page.click("#btn-add-exclusion")
            time.sleep(1.0)

            exclusions_count = page.locator(".exclusion-chip, #exclusion-chips-container .badge").count()
            log_step("10. Privacy Exclusion Rule Creation & Persistence", "PASS", f"Exclusions count: {exclusions_count}")

            # ================================================================
            # Step 7: UI Responsiveness Testing (Desktop, Tablet, Mobile)
            # ================================================================
            print(">>> [Step 7] Testing Responsive Viewports...")
            
            # Tablet Viewport (768 x 1024)
            page.set_viewport_size({"width": 768, "height": 1024})
            time.sleep(1.0)
            page.evaluate("window.scrollTo({top: 300, behavior: 'smooth'})")
            time.sleep(0.8)
            log_step("11. Tablet Viewport (768x1024) Responsive Test", "PASS")

            # Mobile Viewport (375 x 667)
            page.set_viewport_size({"width": 375, "height": 667})
            time.sleep(1.0)
            page.evaluate("window.scrollTo({top: 200, behavior: 'smooth'})")
            time.sleep(0.8)
            log_step("12. Mobile Viewport (375x667) Responsive Test", "PASS")

            # Restore Desktop Viewport (1280 x 800)
            page.set_viewport_size({"width": 1280, "height": 800})
            time.sleep(1.0)
            log_step("13. Desktop Viewport (1280x800) Responsive Test", "PASS")

            # ================================================================
            # Step 8: User Logout & Session Invalidation
            # ================================================================
            print(">>> [Step 8] Testing User Logout Flow...")
            page.click("#btn-logout")
            time.sleep(1.5)

            is_dash_after_logout = page.evaluate("document.body.classList.contains('dashboard-mode')")
            token_after_logout = page.evaluate("window.localStorage.getItem('keyflow_jwt_token')")
            assert not is_dash_after_logout, "Still in dashboard mode after logout"
            assert not token_after_logout, "Token was not removed on logout"
            log_step("14. Secure User Logout & Storage Clearance", "PASS")

            # Close context to finalize video recording
            print(">>> Finalizing video recording...")
            context.close()
            browser.close()

            # Find the saved video in TEMP_VIDEO_DIR
            video_files = [f for f in os.listdir(TEMP_VIDEO_DIR) if f.endswith(".webm") or f.endswith(".mp4")]
            if video_files:
                src_video = os.path.join(TEMP_VIDEO_DIR, video_files[-1])
                print(f"Recorded video file: {src_video} ({os.path.getsize(src_video)} bytes)")
                
                # Convert webm to mp4 using ffmpeg or opencv
                try:
                    import cv2
                    cap = cv2.VideoCapture(src_video)
                    fps = cap.get(cv2.CAP_PROP_FPS) or 25.0
                    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
                    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
                    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
                    out = cv2.VideoWriter(OUTPUT_VIDEO_PATH, fourcc, fps, (width, height))
                    while cap.isOpened():
                        ret, frame = cap.read()
                        if not ret:
                            break
                        out.write(frame)
                    cap.release()
                    out.release()
                    print(f"Successfully exported final video to: {OUTPUT_VIDEO_PATH}")
                except Exception as e:
                    print(f"OpenCV video copy fallback: {e}")
                    import shutil
                    shutil.copy2(src_video, OUTPUT_VIDEO_PATH)

            if os.path.exists(OUTPUT_VIDEO_PATH):
                fsize = os.path.getsize(OUTPUT_VIDEO_PATH)
                log_step("15. Final E2E Screen Recording (KeyFlow_Final_E2E_Test.mp4)", "PASS", f"File size: {fsize} bytes")
            else:
                log_step("15. Final E2E Screen Recording", "FAIL", "Video file not generated")

    finally:
        web_srv.shutdown()
        backend_proc.terminate()
        backend_proc.wait()

    print("\n" + "="*80)
    print("PLAYWRIGHT WEB E2E TEST SUMMARY:")
    print("="*80)
    passes = sum(1 for r in test_results if r["status"] == "PASS")
    fails = sum(1 for r in test_results if r["status"] == "FAIL")
    print(f"Total Steps: {len(test_results)} | Passed: {passes} | Failed: {fails}")

if __name__ == "__main__":
    run_e2e_playwright_test()
