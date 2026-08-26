import os, sys, cv2, numpy as np

def create_title_card(scene_num, title, subtitle, duration_sec=2.5, fps=30, w=1080, h=2400):
    total_frames = int(duration_sec * fps)
    
    # Create base canvas with modern dark background
    canvas = np.zeros((h, w, 3), dtype=np.uint8)
    for y in range(h):
        # Vertical dark gradient from deep navy to charcoal
        r = int(13 + (y / h) * 12)
        g = int(17 + (y / h) * 15)
        b = int(28 + (y / h) * 20)
        canvas[y, :] = [b, g, r] # BGR
    
    # Decorative accent card in center
    card_top = 800
    card_bot = 1600
    card_left = 80
    card_right = 1000
    
    # Draw semi-transparent rounded card
    sub_img = canvas[card_top:card_bot, card_left:card_right]
    card_overlay = np.full(sub_img.shape, (42, 28, 30), dtype=np.uint8) # Dark purple tint
    cv2.addWeighted(card_overlay, 0.85, sub_img, 0.15, 0, sub_img)
    canvas[card_top:card_bot, card_left:card_right] = sub_img
    
    # Card outline border (Vibrant Purple BGR: 237, 58, 124 -> RGB: 124, 58, 237)
    cv2.rectangle(canvas, (card_left, card_top), (card_right, card_bot), (237, 98, 144), 4)
    
    # KeyFlow App Logo / Icon representation
    cv2.circle(canvas, (w // 2, card_top + 140), 60, (237, 98, 144), -1)
    cv2.putText(canvas, "KF", (w // 2 - 38, card_top + 160), cv2.FONT_HERSHEY_DUPLEX, 1.6, (255, 255, 255), 3, cv2.LINE_AA)
    
    # Scene Badge Text
    badge_text = f"KEYFLOW FEATURE DEMO - SCENE {scene_num:02d} OF 11"
    text_size = cv2.getTextSize(badge_text, cv2.FONT_HERSHEY_SIMPLEX, 0.9, 2)[0]
    badge_x = (w - text_size[0]) // 2
    cv2.putText(canvas, badge_text, (badge_x, card_top + 280), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (120, 200, 255), 2, cv2.LINE_AA)
    
    # Main Scene Title
    title_lines = [title]
    if len(title) > 28:
        # Split title into two lines
        words = title.split()
        mid = len(words) // 2
        title_lines = [" ".join(words[:mid]), " ".join(words[mid:])]
    
    curr_y = card_top + 420
    for line in title_lines:
        t_size = cv2.getTextSize(line, cv2.FONT_HERSHEY_DUPLEX, 1.5, 3)[0]
        cv2.putText(canvas, line, ((w - t_size[0]) // 2, curr_y), cv2.FONT_HERSHEY_DUPLEX, 1.5, (255, 255, 255), 3, cv2.LINE_AA)
        curr_y += 70
        
    # Subtitle
    sub_size = cv2.getTextSize(subtitle, cv2.FONT_HERSHEY_SIMPLEX, 0.85, 2)[0]
    cv2.putText(canvas, subtitle, ((w - sub_size[0]) // 2, card_bot - 100), cv2.FONT_HERSHEY_SIMPLEX, 0.85, (180, 180, 190), 2, cv2.LINE_AA)
    
    return [canvas.copy() for _ in range(total_frames)]

def overlay_caption(frame, scene_num, caption_text, w=1080, h=2400):
    # Overlay floating pill banner at bottom
    bar_y1 = h - 220
    bar_y2 = h - 110
    bar_x1 = 60
    bar_x2 = w - 60
    
    # Semi-transparent dark overlay box
    sub = frame[bar_y1:bar_y2, bar_x1:bar_x2]
    overlay = np.zeros(sub.shape, dtype=np.uint8)
    for y in range(sub.shape[0]):
        overlay[y, :] = [30, 20, 25] # BGR
    cv2.addWeighted(overlay, 0.88, sub, 0.12, 0, sub)
    frame[bar_y1:bar_y2, bar_x1:bar_x2] = sub
    
    # Border
    cv2.rectangle(frame, (bar_x1, bar_y1), (bar_x2, bar_y2), (237, 98, 144), 3)
    
    # Text
    badge = f"[ SCENE {scene_num}/11 ] "
    cv2.putText(frame, badge, (bar_x1 + 30, bar_y1 + 65), cv2.FONT_HERSHEY_SIMPLEX, 0.85, (120, 220, 255), 2, cv2.LINE_AA)
    badge_w = cv2.getTextSize(badge, cv2.FONT_HERSHEY_SIMPLEX, 0.85, 2)[0][0]
    
    cv2.putText(frame, caption_text, (bar_x1 + 30 + badge_w, bar_y1 + 65), cv2.FONT_HERSHEY_SIMPLEX, 0.85, (255, 255, 255), 2, cv2.LINE_AA)
    return frame

def main():
    recordings_dir = "d:/Freelance/KeyFlow/demo_recordings"
    output_path = "d:/Freelance/KeyFlow/demo_recordings/KeyFlow_Complete_Demo.mp4"
    
    scenes = [
        (1, "scene_01_welcome.mp4", "Welcome & App Launch", "First-time launch & onboarding experience"),
        (2, "scene_02_signup.mp4", "Account Creation (Sign Up)", "Registration with email & password"),
        (3, "scene_03_signin_home.mp4", "Sign In & Live Dashboard", "Authentication & real-time typing analytics"),
        (4, "scene_04_permissions.mp4", "Accessibility & System Setup", "In-app deep link to Android settings"),
        (5, "scene_05_background_capture.mp4", "Background Typing Capture", "Instant keystroke capture in Chrome"),
        (6, "scene_06_sensitive_exclusion.mp4", "Privacy & Sensitive Redaction", "Automatic password field exclusion"),
        (7, "scene_07_floating_bot.mp4", "Floating Assistant Bot", "System overlay bubble & quick capture toggles"),
        (8, "scene_08_history_search.mp4", "Smart History & Search", "Grouped history timeline & copy snippet"),
        (9, "scene_09_excluded_apps.mp4", "Excluded Applications Manager", "Blacklisting apps from background tracking"),
        (10, "scene_10_translate_emoji.mp4", "Translate & Emoji Utilities", "Multi-language neural translation & emojis"),
        (11, "scene_11_profile_signout.mp4", "Security, 2FA & Sign Out", "Account profile & secure cloud sign-out"),
    ]
    
    w, h = 1080, 2400
    fps = 30.0
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(output_path, fourcc, fps, (w, h))
    
    print("=" * 60)
    print(" Combining All 11 Scenes into Master KeyFlow Demo Video")
    print("=" * 60)
    
    total_written_frames = 0
    
    for scene_num, filename, title, subtitle in scenes:
        filepath = os.path.join(recordings_dir, filename)
        if not os.path.exists(filepath):
            print(f"[-] Missing: {filename}")
            continue
            
        print(f"\n[+] Processing Scene {scene_num:02d}: {title}")
        
        # 1. Write Title Card (2.5 seconds = 75 frames)
        title_frames = create_title_card(scene_num, title, subtitle, duration_sec=2.5, fps=fps, w=w, h=h)
        for tf in title_frames:
            out.write(tf)
            total_written_frames += 1
            
        # 2. Read and overlay scene video frames
        cap = cv2.VideoCapture(filepath)
        orig_fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
        frame_list = []
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            if frame.shape[0] != h or frame.shape[1] != w:
                frame = cv2.resize(frame, (w, h))
            frame_list.append(frame)
        cap.release()
        
        if not frame_list:
            print(f"    Warning: No frames read for {filename}")
            continue
            
        print(f"    Source: {len(frame_list)} raw frames (~{len(frame_list)/orig_fps:.2f}s)")
        
        # Resample to 30 FPS timeline
        target_frames = max(len(frame_list), int(len(frame_list) * (fps / orig_fps)))
        # Target minimum 8 seconds per scene for thorough presentation
        target_frames = max(target_frames, int(8.0 * fps))
        
        for i in range(target_frames):
            src_idx = min(int(i * (len(frame_list) / target_frames)), len(frame_list) - 1)
            frame_copy = frame_list[src_idx].copy()
            frame_with_hud = overlay_caption(frame_copy, scene_num, subtitle, w=w, h=h)
            out.write(frame_with_hud)
            total_written_frames += 1
            
    out.release()
    
    total_sec = total_written_frames / fps
    size_mb = os.path.getsize(output_path) / (1024 * 1024)
    print("\n" + "=" * 60)
    print(f" MASTER DEMO CREATED: {output_path}")
    print(f" Total Duration: {int(total_sec // 60)}m {int(total_sec % 60):02d}s ({total_sec:.2f} seconds)")
    print(f" File Size: {size_mb:.2f} MB")
    print(f" Total Frames: {total_written_frames} @ 30.0 FPS")
    print("=" * 60)

if __name__ == "__main__":
    main()
