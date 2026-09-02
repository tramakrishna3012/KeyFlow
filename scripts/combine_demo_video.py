import os
import sys
import time
import cv2
import numpy as np

def create_header(w=1920, h=60, title="KEYFLOW LIVE CROSS-DEVICE E2E VERIFICATION DEMO"):
    header = np.zeros((h, w, 3), dtype=np.uint8)
    for y in range(h):
        r = int(15 + (y / h) * 10)
        g = int(18 + (y / h) * 12)
        b = int(32 + (y / h) * 18)
        header[y, :] = [b, g, r] # BGR
    
    # Bottom border line (Indigo/Purple)
    cv2.line(header, (0, h - 2), (w, h - 2), (241, 102, 99), 2)
    
    # Left Badge
    cv2.circle(header, (32, h // 2), 16, (241, 102, 99), -1)
    cv2.putText(header, "KF", (23, h // 2 + 5), cv2.FONT_HERSHEY_DUPLEX, 0.45, (255, 255, 255), 1, cv2.LINE_AA)
    
    # Main Title
    cv2.putText(header, title, (58, h // 2 + 6), cv2.FONT_HERSHEY_DUPLEX, 0.65, (255, 255, 255), 1, cv2.LINE_AA)
    
    # Left / Right Column Labels
    left_label = "Android Physical (Motorola Edge 40)"
    right_label = "KeyFlow Web Console (Real-Time Cloud Sync)"
    
    cv2.putText(header, left_label, (230, h // 2 + 5), cv2.FONT_HERSHEY_SIMPLEX, 0.40, (180, 200, 240), 1, cv2.LINE_AA)
    cv2.putText(header, "<->", (705, h // 2 + 5), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (100, 240, 150), 1, cv2.LINE_AA)
    cv2.putText(header, right_label, (1130, h // 2 + 5), cv2.FONT_HERSHEY_SIMPLEX, 0.40, (180, 200, 240), 1, cv2.LINE_AA)
    
    # Live Status Dot
    cv2.circle(header, (w - 140, h // 2), 6, (60, 220, 100), -1)
    cv2.putText(header, "LIVE SYNCED", (w - 125, h // 2 + 5), cv2.FONT_HERSHEY_SIMPLEX, 0.42, (60, 220, 100), 1, cv2.LINE_AA)
    
    return header

def composite_side_by_side(mobile_video_path, web_video_path, output_path, fps=30.0, step_captions=None, mobile_trim_sec=0.0, web_trim_sec=0.0):
    """
    Composites mobile recording on left (720x1020) and web recording on right (1200x1020)
    under a 1920x60 header bar, creating a full 1920x1080 @ 30 FPS MP4 video.
    Supports initial stream timestamp offset trimming for frame-accurate synchronization.
    """
    out_w, out_h = 1920, 1080
    header_h = 60
    pane_h = out_h - header_h # 1020
    left_w = 720
    right_w = 1200
    
    print(f"[Compositor] Loading mobile video: {mobile_video_path}")
    print(f"[Compositor] Loading web video:    {web_video_path}")
    
    cap_m = cv2.VideoCapture(mobile_video_path) if os.path.exists(mobile_video_path) else None
    cap_w = cv2.VideoCapture(web_video_path) if os.path.exists(web_video_path) else None
    
    fps_m = cap_m.get(cv2.CAP_PROP_FPS) if cap_m else 30.0
    if not fps_m or fps_m <= 0 or fps_m > 120:
        fps_m = 30.0
        
    fps_w = cap_w.get(cv2.CAP_PROP_FPS) if cap_w else 30.0
    if not fps_w or fps_w <= 0 or fps_w > 120:
        fps_w = 30.0
    
    frames_m = []
    if cap_m:
        while True:
            ret, frame = cap_m.read()
            if not ret:
                break
            frames_m.append(frame)
        cap_m.release()
    
    frames_w = []
    if cap_w:
        while True:
            ret, frame = cap_w.read()
            if not ret:
                break
            frames_w.append(frame)
        cap_w.release()
        
    # Apply initial timestamp trimming for alignment
    skip_m = int(mobile_trim_sec * fps_m)
    if skip_m > 0 and len(frames_m) > skip_m + 10:
        frames_m = frames_m[skip_m:]
        print(f"[Compositor] Trimmed {skip_m} leading mobile frames ({mobile_trim_sec:.2f}s offset).")
        
    skip_w = int(web_trim_sec * fps_w)
    if skip_w > 0 and len(frames_w) > skip_w + 10:
        frames_w = frames_w[skip_w:]
        print(f"[Compositor] Trimmed {skip_w} leading web frames ({web_trim_sec:.2f}s offset).")
        
    count_m = len(frames_m)
    count_w = len(frames_w)
    print(f"[Compositor] Usable frames: {count_m} mobile frames, {count_w} web frames.")
    
    if count_m == 0 and count_w == 0:
        print("[Compositor] Error: No frames found in input videos!")
        return False
        
    duration_m = count_m / fps_m if count_m > 0 else 0.0
    duration_w = count_w / fps_w if count_w > 0 else 0.0
    max_duration = max(duration_m, duration_w, 20.0)
    total_frames = int(max_duration * fps)
    
    # Initialize VideoWriter
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(output_path, fourcc, fps, (out_w, out_h))
    
    header = create_header(w=out_w, h=header_h)
    
    # Background for left pane (Dark sleek gradient)
    left_bg = np.zeros((pane_h, left_w, 3), dtype=np.uint8)
    for y in range(pane_h):
        r = int(10 + (y / pane_h) * 8)
        g = int(12 + (y / pane_h) * 10)
        b = int(20 + (y / pane_h) * 15)
        left_bg[y, :] = [b, g, r]
        
    # Vertical separator line
    cv2.line(left_bg, (left_w - 1, 0), (left_w - 1, pane_h), (50, 55, 75), 1)

    print(f"[Compositor] Rendering {total_frames} composite frames ({total_frames/fps:.1f}s) @ 1:1 realtime speed...")
    
    for i in range(total_frames):
        canvas = np.zeros((out_h, out_w, 3), dtype=np.uint8)
        curr_time = i / fps
        
        # 1. Header
        canvas[0:header_h, 0:out_w] = header
        
        # 2. Left Pane (Mobile)
        left_pane = left_bg.copy()
        if count_m > 0:
            idx_m = min(int(curr_time * fps_m), count_m - 1)
            raw_m = frames_m[idx_m]
            
            # Scale mobile frame (preserve aspect ratio)
            mh, mw = raw_m.shape[:2]
            scale = min((pane_h - 20) / mh, (left_w - 40) / mw)
            target_mw = int(mw * scale)
            target_mh = int(mh * scale)
            
            scaled_m = cv2.resize(raw_m, (target_mw, target_mh), interpolation=cv2.INTER_AREA)
            
            # Center inside left pane
            ox = (left_w - target_mw) // 2
            oy = (pane_h - target_mh) // 2
            
            # Phone border / bezel glow
            cv2.rectangle(left_pane, (ox - 3, oy - 3), (ox + target_mw + 3, oy + target_mh + 3), (80, 90, 120), 2)
            left_pane[oy:oy+target_mh, ox:ox+target_mw] = scaled_m
            
        canvas[header_h:out_h, 0:left_w] = left_pane
        
        # 3. Right Pane (Web Dashboard)
        if count_w > 0:
            idx_w = min(int(curr_time * fps_w), count_w - 1)
            raw_w = frames_w[idx_w]
            scaled_w = cv2.resize(raw_w, (right_w, pane_h), interpolation=cv2.INTER_AREA)
            canvas[header_h:out_h, left_w:out_w] = scaled_w
        else:
            canvas[header_h:out_h, left_w:out_w] = 20 # dark placeholder
            
        # 4. Step caption HUD overlay
        if step_captions:
            progress = i / total_frames
            active_caption = step_captions[-1][1]
            for frac, cap in step_captions:
                if progress <= frac:
                    active_caption = cap
                    break
            
            hud_w, hud_h = 760, 44
            hud_x = left_w + 30
            hud_y = out_h - 60
            
            sub = canvas[hud_y:hud_y+hud_h, hud_x:hud_x+hud_w]
            overlay = np.zeros(sub.shape, dtype=np.uint8)
            for y_sub in range(sub.shape[0]):
                overlay[y_sub, :] = [25, 20, 30]
            cv2.addWeighted(overlay, 0.85, sub, 0.15, 0, sub)
            canvas[hud_y:hud_y+hud_h, hud_x:hud_x+hud_w] = sub
            
            cv2.rectangle(canvas, (hud_x, hud_y), (hud_x + hud_w, hud_y + hud_h), (241, 102, 99), 2)
            cv2.putText(canvas, active_caption, (hud_x + 16, hud_y + 28), cv2.FONT_HERSHEY_DUPLEX, 0.52, (255, 255, 255), 1, cv2.LINE_AA)

        out.write(canvas)
        
    out.release()
    print(f"[Compositor] Successfully wrote {output_path} ({os.path.getsize(output_path)/(1024*1024):.2f} MB)")
    return True

if __name__ == "__main__":
    m_path = "d:/Freelance/KeyFlow/demo_recordings/raw_mobile_demo.mp4"
    w_path = "d:/Freelance/KeyFlow/demo_recordings/raw_web_demo.mp4"
    out_path = "d:/Freelance/KeyFlow/demo_recordings/master_e2e_sync_demo.mp4"
    
    if len(sys.argv) > 3:
        m_path = sys.argv[1]
        w_path = sys.argv[2]
        out_path = sys.argv[3]
        
    composite_side_by_side(m_path, w_path, out_path)
