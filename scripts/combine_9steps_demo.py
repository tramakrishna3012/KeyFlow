import os, sys, cv2, numpy as np

def create_title_card(step_num, title, subtitle, duration_sec=2.5, fps=30, w=1080, h=2400):
    total_frames = int(duration_sec * fps)
    canvas = np.zeros((h, w, 3), dtype=np.uint8)
    
    # Modern subtle dark gradient
    for y in range(h):
        r = int(12 + (y / h) * 14)
        g = int(16 + (y / h) * 16)
        b = int(26 + (y / h) * 22)
        canvas[y, :] = [b, g, r] # BGR
        
    card_top, card_bot = 820, 1580
    card_left, card_right = 70, 1010
    
    # Semi-transparent centered card
    sub = canvas[card_top:card_bot, card_left:card_right]
    card_overlay = np.full(sub.shape, (42, 28, 30), dtype=np.uint8)
    cv2.addWeighted(card_overlay, 0.85, sub, 0.15, 0, sub)
    canvas[card_top:card_bot, card_left:card_right] = sub
    
    # Border
    cv2.rectangle(canvas, (card_left, card_top), (card_right, card_bot), (237, 98, 144), 4)
    
    # Logo
    cv2.circle(canvas, (w // 2, card_top + 130), 55, (237, 98, 144), -1)
    cv2.putText(canvas, "KF", (w // 2 - 34, card_top + 150), cv2.FONT_HERSHEY_DUPLEX, 1.5, (255, 255, 255), 3, cv2.LINE_AA)
    
    # Step Badge
    badge_text = f"KEYFLOW WALKTHROUGH - STEP {step_num:02d} OF 09"
    t_size = cv2.getTextSize(badge_text, cv2.FONT_HERSHEY_SIMPLEX, 0.85, 2)[0]
    cv2.putText(canvas, badge_text, ((w - t_size[0]) // 2, card_top + 260), cv2.FONT_HERSHEY_SIMPLEX, 0.85, (120, 200, 255), 2, cv2.LINE_AA)
    
    # Title (split if long)
    words = title.split()
    if len(title) > 26 and len(words) > 1:
        mid = len(words) // 2
        lines = [" ".join(words[:mid]), " ".join(words[mid:])]
    else:
        lines = [title]
        
    curr_y = card_top + 390
    for line in lines:
        s = cv2.getTextSize(line, cv2.FONT_HERSHEY_DUPLEX, 1.4, 3)[0]
        cv2.putText(canvas, line, ((w - s[0]) // 2, curr_y), cv2.FONT_HERSHEY_DUPLEX, 1.4, (255, 255, 255), 3, cv2.LINE_AA)
        curr_y += 65
        
    # Subtitle
    sub_s = cv2.getTextSize(subtitle, cv2.FONT_HERSHEY_SIMPLEX, 0.85, 2)[0]
    cv2.putText(canvas, subtitle, ((w - sub_s[0]) // 2, card_bot - 85), cv2.FONT_HERSHEY_SIMPLEX, 0.85, (180, 180, 190), 2, cv2.LINE_AA)
    
    return [canvas.copy() for _ in range(total_frames)]

def overlay_caption(frame, step_num, caption_text, w=1080, h=2400):
    bar_y1, bar_y2 = h - 220, h - 110
    bar_x1, bar_x2 = 60, w - 60
    
    sub = frame[bar_y1:bar_y2, bar_x1:bar_x2]
    overlay = np.full(sub.shape, (30, 20, 25), dtype=np.uint8)
    cv2.addWeighted(overlay, 0.88, sub, 0.12, 0, sub)
    frame[bar_y1:bar_y2, bar_x1:bar_x2] = sub
    
    cv2.rectangle(frame, (bar_x1, bar_y1), (bar_x2, bar_y2), (237, 98, 144), 3)
    
    badge = f"[ STEP {step_num}/9 ] "
    cv2.putText(frame, badge, (bar_x1 + 30, bar_y1 + 65), cv2.FONT_HERSHEY_SIMPLEX, 0.85, (120, 220, 255), 2, cv2.LINE_AA)
    badge_w = cv2.getTextSize(badge, cv2.FONT_HERSHEY_SIMPLEX, 0.85, 2)[0][0]
    
    cv2.putText(frame, caption_text, (bar_x1 + 30 + badge_w, bar_y1 + 65), cv2.FONT_HERSHEY_SIMPLEX, 0.85, (255, 255, 255), 2, cv2.LINE_AA)
    return frame

def main():
    recordings_dir = "d:/Freelance/KeyFlow/demo_recordings"
    output_path = "d:/Freelance/KeyFlow/demo_recordings/KeyFlow_Client_Walkthrough.mp4"
    
    steps = [
        (1, "step_01_signup.mp4", "Account Registration", "Create new account with email & password"),
        (2, "step_02_signin.mp4", "Sign In & Persistence", "Relaunch & sign in with the same account"),
        (3, "step_03_accessibility.mp4", "Accessibility Setup", "Deep link to Android settings & enable service"),
        (4, "step_04_typing_capture.mp4", "Background Typing Capture", "Live keystroke capture & date/app grouping"),
        (5, "step_05_sensitive_exclusion.mp4", "Sensitive Data Exclusion", "Password fields automatically excluded"),
        (6, "step_06_floating_bot.mp4", "Floating Assistant Bot", "System overlay bubble & Pause Capture toggle"),
        (7, "step_07_exclude_apps.mp4", "Excluded Apps Manager", "Installed apps list with icons & blacklist toggle"),
        (8, "step_08_history_search.mp4", "History Search & Copy", "Full-text search filter & long-press copy"),
        (9, "step_09_profile_signout.mp4", "Profile & Secure Sign Out", "Account credentials, 2FA & session sign out"),
    ]
    
    w, h = 1080, 2400
    fps = 30.0
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(output_path, fourcc, fps, (w, h))
    
    print("=" * 60)
    print(" Assembling 9-Step Verified Client Walkthrough Video")
    print("=" * 60)
    
    extracted_frames = []
    total_written_frames = 0
    
    for step_num, filename, title, subtitle in steps:
        filepath = os.path.join(recordings_dir, filename)
        if not os.path.exists(filepath):
            print(f"[-] Missing: {filename}")
            continue
            
        print(f"\n[+] Processing Step {step_num:02d}: {title}")
        
        # 1. Title Card (2.5s)
        title_frames = create_title_card(step_num, title, subtitle, duration_sec=2.5, fps=fps, w=w, h=h)
        for tf in title_frames:
            out.write(tf)
            total_written_frames += 1
            
        # 2. Read frames
        cap = cv2.VideoCapture(filepath)
        orig_fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
        raw_frames = []
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            if frame.shape[0] != h or frame.shape[1] != w:
                frame = cv2.resize(frame, (w, h))
            raw_frames.append(frame)
        cap.release()
        
        if not raw_frames:
            print(f"    Warning: No frames read for {filename}")
            continue
            
        # Extract mid-scene frame (clean frame without title/HUD or with HUD)
        mid_idx = len(raw_frames) // 2
        mid_frame_clean = raw_frames[mid_idx].copy()
        frame_save_path = os.path.join(recordings_dir, f"step_{step_num:02d}_frame.png")
        cv2.imwrite(frame_save_path, mid_frame_clean)
        extracted_frames.append((step_num, title, frame_save_path))
        print(f"    Extracted mid-scene frame -> {frame_save_path}")
        
        # Resample frames
        target_frames = max(len(raw_frames), int(len(raw_frames) * (fps / orig_fps)))
        target_frames = max(target_frames, int(8.0 * fps))
        
        for i in range(target_frames):
            src_idx = min(int(i * (len(raw_frames) / target_frames)), len(raw_frames) - 1)
            frame_copy = raw_frames[src_idx].copy()
            frame_with_hud = overlay_caption(frame_copy, step_num, subtitle, w=w, h=h)
            out.write(frame_with_hud)
            total_written_frames += 1
            
    out.release()
    
    total_sec = total_written_frames / fps
    size_mb = os.path.getsize(output_path) / (1024 * 1024)
    print("\n" + "=" * 60)
    print(f" CLIENT WALKTHROUGH COMPLETED: {output_path}")
    print(f" Total Duration: {int(total_sec // 60)}m {int(total_sec % 60):02d}s ({total_sec:.2f} seconds)")
    print(f" File Size: {size_mb:.2f} MB")
    print(f" Total Frames: {total_written_frames} @ 30.0 FPS")
    print("=" * 60)
    
    print("\n[EXTRACTED MID-SCENE FRAMES]")
    for s_num, t, p in extracted_frames:
        print(f"  Step {s_num:02d}: {t} -> {p}")

if __name__ == "__main__":
    main()
