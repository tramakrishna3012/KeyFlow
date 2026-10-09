import os
import sys
import time
from playwright.sync_api import sync_playwright

WEB_DIR = r"d:\Freelance\KeyFlow\demo_recordings\web_scenes"
os.makedirs(WEB_DIR, exist_ok=True)

def record_scenes():
    print(">>> Starting Playwright Recording for Web Scenes...")
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        
        # 1. Landing Page & Feature Tour (1920x1080)
        context1 = browser.new_context(
            viewport={"width": 1920, "height": 1080},
            record_video_dir=WEB_DIR,
            record_video_size={"width": 1920, "height": 1080}
        )
        page1 = context1.new_page()
        page1.goto("http://localhost:5173")
        page1.wait_for_timeout(2000)
        
        # Scroll through landing page
        page1.evaluate("window.scrollTo({top: 600, behavior: 'smooth'})")
        page1.wait_for_timeout(2500)
        page1.evaluate("window.scrollTo({top: 1300, behavior: 'smooth'})")
        page1.wait_for_timeout(2500)
        page1.evaluate("window.scrollTo({top: 2000, behavior: 'smooth'})")
        page1.wait_for_timeout(2500)
        
        # Scroll to download & pairing section
        page1.evaluate("document.getElementById('downloads')?.scrollIntoView({behavior: 'smooth'})")
        page1.wait_for_timeout(3000)
        
        context1.close()
        print(">>> [Scene 1] Landing Page tour recorded.")

        # 2. Signup Flow & Dashboard Access (1920x1080)
        context2 = browser.new_context(
            viewport={"width": 1920, "height": 1080},
            record_video_dir=WEB_DIR,
            record_video_size={"width": 1920, "height": 1080}
        )
        page2 = context2.new_page()
        page2.goto("http://localhost:5173")
        page2.wait_for_timeout(1500)
        
        # Click Sign In / Sign Up button
        try:
            page2.click("#btn-nav-auth")
            page2.wait_for_timeout(1500)
            
            # Switch to Sign Up tab in modal if present
            if page2.is_visible("#tab-signup"):
                page2.click("#tab-signup")
                page2.wait_for_timeout(1000)
                
            # Fill registration form
            page2.fill("#register-name", "Rahul Sharma")
            page2.wait_for_timeout(800)
            page2.fill("#register-email", "rahul.sharma@keyflow.dev")
            page2.wait_for_timeout(800)
            page2.fill("#register-password", "SecureFlow2026!")
            page2.wait_for_timeout(1000)
        except Exception as e:
            print("Notice on signup interaction:", e)

        # Transition to authenticated Dashboard
        page2.goto("http://localhost:5173/?test_user=rahul.sharma@keyflow.dev&auto_auth=true#dashboard")
        page2.wait_for_timeout(2500)
        
        # Explore Dashboard tabs
        page2.click("#nav-devices")
        page2.wait_for_timeout(2000)
        page2.click("#nav-typing")
        page2.wait_for_timeout(2500)

        # Open Mobile Pairing Modal
        try:
            pair_btn = page2.query_selector("#btn-dash-pair") or page2.query_selector("#btn-trigger-pairing")
            if pair_btn:
                pair_btn.click()
                page2.wait_for_timeout(4000)
        except Exception as e:
            print("Notice on pairing modal:", e)
            
        context2.close()
        print(">>> [Scene 2] Signup & Web Console recorded.")
        browser.close()

if __name__ == "__main__":
    record_scenes()
