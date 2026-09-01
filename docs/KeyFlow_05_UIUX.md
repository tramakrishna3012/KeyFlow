# KeyFlow — UI/UX Specification & Design System

**Document Version:** 3.0  
**Design Paradigm:** Modern Glassmorphism, Adaptive Material 3, Dark/Light Theme Support  
**Supported Viewports:** Mobile Portrait (360–440dp), Horizontal/Landscape (600–1080dp), Tablet & Desktop (1080–2560dp)  

---

## 1. Design Principles & Aesthetic Philosophy

1. **Radical Transparency**: System state is always obvious. A clean, non-intrusive status notification or floating bubble indicates whether capture is *Active* or *Paused*.
2. **Instant Reusability**: 1-Click copy buttons on every session card and clipboard row with instant toast feedback.
3. **Adaptive Form Factors**: Seamless transitions from bottom navigation on mobile portrait to a scrollable `NavigationRail` sidebar in landscape/desktop modes.
4. **High-Contrast Micro-Affordances**: Switches, inputs, and buttons feature clear, high-contrast visual cues (such as prominent white ball knobs on active toggles).
5. **Interactive Playback**: Reconstruct typing sessions with scrubber sliders, speed multipliers (1x, 2x, 4x), and character count tracking.

---

## 2. Color Palette & Typography (`AppColors`)

```
Primary Accent (Indigo/Blue): #4F46E5 / #2563EB
Background Primary:          #F8FAFC (Clean Light Slate) / #0F172A (Deep Slate Dark)
Surface Card Background:     #FFFFFF (Pure White) / #1E293B (Dark Surface)
Text Primary:                #0F172A (High-Contrast Slate Dark) / #F8FAFC (Light Text)
Text Secondary:              #64748B (Muted Slate) / #94A3B8
Success / Active:            #10B981 (Emerald Green)
Warning / Paused:            #F59E0B (Amber Gold)
Error / Destructive:         #EF4444 (Rose Red)
Border Color:                #E2E8F0 / #334155
```

---

## 3. Mobile Screen Specifications

### 3.1 Onboarding & Consent Flow
- **Slide 1 — What KeyFlow Does**: Explains automatic keystroke debouncing and clipboard synchronization for fast search and reuse.
- **Slide 2 — Privacy & Security**: Highlights zero-knowledge local SQLCipher AES-256 encryption and auto-masking of passwords.
- **Slide 3 — Permission Grant**: Clear explanation of Android Accessibility and Notification requirements.
- **Responsive Geometry**: Clamped to max-width 440dp with `SingleChildScrollView` to prevent keyboard or landscape overflow.

### 3.2 Home Dashboard
- **Greeting & Profile Avatar**: Time-aware greeting (*"Good morning"*, *"Good evening"*) with quick profile modal launcher.
- **Metric KPI Grid**: Adaptive 2x2 grid in portrait (4x1 in landscape) displaying:
  - Total Sessions Captured
  - Total Characters Typed Today
  - Estimated Time Saved
  - Active Tracked Applications
- **Weekly Typing Histogram**: Custom bar chart visualizing daily keystroke volume.
- **Recent Sessions Reel**: Quick carousel of the latest 3 captured sessions with 1-click copy action.

### 3.3 Session Typing Feed Screen
- **Search Header**: Persistent search bar with clear button and sub-20ms query execution.
- **App Filter Chips**: Horizontal scrollable chips (*All Apps*, *Chrome*, *Calculator*, *WhatsApp*) with active entry counts.
- **Date Grouping (Level 1)**: Sticky date headers (*TODAY*, *YESTERDAY*, *DD MMM YYYY*) with total entry badge pills.
- **Session Card (Level 2)**:
  - Header: Application package icon, title (*Chrome*), window title, and device tag.
  - Body: Decrypted paragraph text.
  - Footer: Character count, word count, duration, favorite star toggle, and 1-Click Copy action.

### 3.4 Settings & Preference Screen
- **Account & Profile Card**: Displays active sync status, local/cloud mode, and profile modal trigger.
- **Capture Controls**:
  - `Pause Typing Capture` toggle with high-contrast **white ball knob** (`Colors.white`).
  - Android Accessibility Settings deep-link with live active state reflection.
  - Background Battery Optimization un-restriction launcher.
  - `Floating Assistant Bubble` system overlay toggle.
- **Exclusions & Privacy**:
  - `Excluded Applications` list manager.
  - `Auto-exclude secure password fields` (Locked ON by default).
- **Data Lifecycle & Export**:
  - Retention policy picker (24 Hours, 7 Days, 30 Days, 90 Days, Indefinite).
  - 1-Click JSON data export and secure data shredding action.

### 3.5 Floating Assistant Bot Overlay
- **Draggable Bubble**: Semi-transparent 56dp circular icon that snaps to screen edges.
- **Expanded Quick Menu**: Instant capture pause/resume toggle, status badge, and direct shortcut back into KeyFlow.

---

## 4. Web Dashboard UI (`web/`)

- **Navigation Sidebar**: Left sidebar featuring KeyFlow branding, user avatar card, and 7 view tabs:
  1. *Executive Overview*
  2. *Session Typing Stream*
  3. *Clipboard History Feed*
  4. *Search & Filtering*
  5. *App Usage Breakdown*
  6. *Admin & Org Controls*
  7. *Privacy & Exclusions*
- **Session Typing Stream Feed**:
  - Paragraph-level cards with app badge, window title, device tag (`📱 Motorola Edge 40`), character count, and word count.
  - 1-Click Copy with toast notification.
  - `Replay Draft` button opening the timeline replay modal.
- **Clipboard History Feed**:
  - Type filter tabs: `All`, `Code`, `URLs`, `Plain Text`.
  - Code cards with monospace font and line numbering.
  - URL cards with rich link previews, domain badges, and external launch buttons.
  - Pin/Unpin favorite toggles.
- **Replay Draft Modal**:
  - Interactive slider scrubber for stepping through keystroke snapshots.
  - Animated Play/Pause with 1x, 2x, 4x speed multipliers.
  - Real-time character and word counters.
- **Action Bar**: "Refresh Telemetry" button with loading spinners, global search bar, and app filter dropdowns.
