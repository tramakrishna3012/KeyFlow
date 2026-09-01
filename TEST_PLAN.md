# KeyFlow Master End-to-End Test Plan: Every Screen, Button & Feature

**Document Version:** 3.0  
**Test Scope:** Mobile App (Flutter Android / iOS / Desktop) & Web Application (Cloudflare Workers SPA & React)  
**Execution Type:** Exhaustive Manual & Automated Verification  

---

## 1. Test Strategy & Acceptance Baseline

### 1.1 Quality Gates
1. **0 Unhandled Errors / Zero Crashes**: No unhandled exceptions, ANRs, or blank screen renders.
2. **100% Button & Control Verification**: Every interactive button, switch, tab, modal, and slider must have defined pre-conditions, user input, expected observation, and pass/fail criteria.
3. **Data Integrity & Cryptography**: All stored text must be encrypted locally via SQLCipher AES-256 and decrypted on the web console via WebCrypto.
4. **Zero Keystroke Spam**: Inactivity debouncing (2.5s) and session termination (60s) must function cleanly without character-level database flooding.
5. **Video Playability**: All demo recordings must terminate cleanly with valid MP4 container atom headers (`moov` present).

---

## 2. Mobile Application Test Matrix (Flutter / Android)

### Screen 1: Onboarding & Permissions Carousel
| Test ID | Control Name | Pre-Condition | Action / Input | Expected Result | Pass/Fail |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **MOB-ONB-01** | `Next` Button | Slide 1 (Overview) active | Tap "Next" | Transitions smoothly to Slide 2 (Security) with animated indicator. | PASS |
| **MOB-ONB-02** | `Skip` Button | Slide 1 or 2 active | Tap "Skip" | Jumps directly to Slide 3 (Permissions). | PASS |
| **MOB-ONB-03** | `Enable Accessibility` Button | Slide 3 active; A11y disabled | Tap "Enable Accessibility" | Launches Android Accessibility Settings page targeting KeyFlow service. | PASS |
| **MOB-ONB-04** | `Allow Notifications` Button | Slide 3 active | Tap "Allow Notifications" | Prompts runtime POST_NOTIFICATIONS dialog; persists granted state. | PASS |
| **MOB-ONB-05** | `Get Started` Button | Permissions granted | Tap "Get Started" | Navigates into Home Dashboard; marks onboarding as completed in secure storage. | PASS |

---

### Screen 2: Authentication & Profile
| Test ID | Control Name | Pre-Condition | Action / Input | Expected Result | Pass/Fail |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **MOB-AUTH-01** | `Email Input Field` | Auth screen visible | Enter valid email (`test@keyflow.dev`) | Validates RFC email format; clears error helper text. | PASS |
| **MOB-AUTH-02** | `Password Input Field` | Auth screen visible | Enter password (`Password123!`) | Masks text with bullet characters. | PASS |
| **MOB-AUTH-03** | `Password Visibility Toggle` | Text entered in password | Tap eye icon | Unmasks cleartext password; icon changes to eye-off. | PASS |
| **MOB-AUTH-04** | `Sign In` Button | Valid credentials entered | Tap "Sign In" | Authenticates with backend; stores JWT token in Keystore; navigates to Home. | PASS |
| **MOB-AUTH-05** | `Continue as Guest` Button | Auth screen visible | Tap "Continue as Guest" | Enters offline zero-knowledge mode with local SQLCipher encryption. | PASS |

---

### Screen 3: Home Dashboard
| Test ID | Control Name | Pre-Condition | Action / Input | Expected Result | Pass/Fail |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **MOB-HOME-01** | `Profile Avatar Icon` | Home screen visible | Tap profile avatar | Opens user profile bottom sheet with sync state and email. | PASS |
| **MOB-HOME-02** | `KPI Card 1: Snippets` | Home screen visible | Tap "Snippets Captured" card | Jumps to History tab with all filters reset. | PASS |
| **MOB-HOME-03** | `KPI Card 2: Characters` | Home screen visible | Inspect count | Displays accurate sum of characters typed today. | PASS |
| **MOB-HOME-04** | `KPI Card 3: Time Saved`| Home screen visible | Inspect calculation | Computes estimated time saved based on character volume. | PASS |
| **MOB-HOME-05** | `KPI Card 4: Active Apps`| Home screen visible | Inspect count | Reflects distinct count of applications recorded today. | PASS |
| **MOB-HOME-06** | `Weekly Histogram Bar` | Activity data exists | Tap individual day bar | Highlights bar and displays tooltip with that day's character total. | PASS |
| **MOB-HOME-07** | `Recent Snippet Copy` | Snippet card visible in reel| Tap copy icon | Copies decrypted text to clipboard; shows green toast confirmation. | PASS |
| **MOB-HOME-08** | `Bottom Nav: History` | Home screen visible | Tap "History" in nav bar | Switches to Session Typing Feed screen. | PASS |
| **MOB-HOME-09** | `Bottom Nav: Assist` | Home screen visible | Tap "Assist" in nav bar | Switches to Emoji & Translation Tools screen. | PASS |
| **MOB-HOME-10** | `Bottom Nav: Settings`| Home screen visible | Tap "Settings" in nav bar | Switches to Settings & Preferences screen. | PASS |

---

### Screen 4: Session Typing Feed & Timeline
| Test ID | Control Name | Pre-Condition | Action / Input | Expected Result | Pass/Fail |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **MOB-HIST-01** | `Search Input Bar` | History screen visible | Type `"25000"` or keyword | Real-time filter isolates matching sessions within < 20ms. | PASS |
| **MOB-HIST-02** | `Search Clear 'X'` | Query active in search | Tap 'X' clear button | Clears search text and restores complete session stream. | PASS |
| **MOB-HIST-03** | `App Filter Chip: All` | Specific app selected | Tap "All Apps" chip | Resets filter to show all recorded applications. | PASS |
| **MOB-HIST-04** | `App Filter Chip: Specific`| History screen visible | Tap "Chrome" or "Calculator" | Isolates session cards belonging exclusively to selected app. | PASS |
| **MOB-HIST-05** | `Favorite Star Toggle` | Session card visible | Tap Star icon | Toggles favorite status; updates local database and syncs to cloud. | PASS |
| **MOB-HIST-06** | `Session Copy Button` | Session card visible | Tap Copy icon | Copies full paragraph session content to clipboard with toast alert. | PASS |
| **MOB-HIST-07** | `Session Card Tap` | Session card visible | Tap card body | Opens full Snippet Detail Modal with word counts and share actions. | PASS |

---

### Screen 5: Snippet Detail Modal
| Test ID | Control Name | Pre-Condition | Action / Input | Expected Result | Pass/Fail |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **MOB-DET-01** | `Copy Text Action` | Modal open | Tap "Copy Text" | Copies text to clipboard and shows toast feedback. | PASS |
| **MOB-DET-02** | `Share Snippet Action` | Modal open | Tap "Share" | Triggers native Android/iOS system share intent. | PASS |
| **MOB-DET-03** | `Translate Action` | Modal open | Tap "Translate" | Transfers text into Assist Translation tab. | PASS |
| **MOB-DET-04** | `Delete Snippet Action`| Modal open | Tap "Delete" | Permanently removes record from local SQLite database and closes modal. | PASS |
| **MOB-DET-05** | `Close Modal 'X'` | Modal open | Tap 'X' or drag down | Dismisses detail modal smoothly. | PASS |

---

### Screen 6: Assist & Tools
| Test ID | Control Name | Pre-Condition | Action / Input | Expected Result | Pass/Fail |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **MOB-AST-01** | `Emoji Category Tab` | Assist screen visible | Tap "Smileys" / "Gestures" | Scrolls grid to selected category. | PASS |
| **MOB-AST-02** | `Emoji Cell Tap` | Emoji grid visible | Tap any emoji (e.g. `🚀`) | Copies emoji to clipboard; triggers subtle haptic feedback and toast. | PASS |
| **MOB-AST-03** | `Emoji Search Input` | Assist screen visible | Type `"fire"` | Filters emoji list to matching fire/flame icons. | PASS |
| **MOB-AST-04** | `Translation Source Lang`| Assist screen visible | Select "English" in dropdown | Sets source language for translation engine. | PASS |
| **MOB-AST-05** | `Translation Target Lang`| Assist screen visible | Select "Spanish" in dropdown | Sets target output language. | PASS |
| **MOB-AST-06** | `Translate Now Button` | Text entered in input | Tap "Translate Now" | Generates translated text output in result card. | PASS |
| **MOB-AST-07** | `Copy Translation Button`| Translated text present | Tap copy icon | Copies translated output to clipboard. | PASS |

---

### Screen 7: Settings & Preferences
| Test ID | Control Name | Pre-Condition | Action / Input | Expected Result | Pass/Fail |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **MOB-SET-01** | `Pause Capture Switch` | Capture is active | Toggle switch (White Ball knob)| Pauses accessibility capture; changes state badge to amber "Paused". | PASS |
| **MOB-SET-02** | `Resume Capture Switch`| Capture is paused | Toggle switch | Resumes capture; changes state badge to emerald "Active". | PASS |
| **MOB-SET-03** | `Floating Bubble Switch`| Overlay permission granted| Toggle switch | Spawns draggable circular bubble on Android screen overlay. | PASS |
| **MOB-SET-04** | `Excluded Apps Tile` | Settings screen visible | Tap "Excluded Applications" | Opens package exclusion manager modal with installed app list. | PASS |
| **MOB-SET-05** | `App Blacklist Checkbox`| Exclusion modal open | Check/uncheck app | Saves package exclusion; accessibility service discards app events. | PASS |
| **MOB-SET-06** | `Auto-exclude Passwords`| Settings screen visible | Inspect switch | Locked ON by default to enforce privacy compliance. | PASS |
| **MOB-SET-07** | `Retention Policy Picker`| Settings screen visible | Select "30 Days" from menu | Enforces 30-day auto-purge policy in background scheduler. | PASS |
| **MOB-SET-08** | `Export JSON Button` | History records exist | Tap "Export JSON" | Generates and shares standard JSON archive file of all records. | PASS |
| **MOB-SET-09** | `Clear All Data Button` | Settings screen visible | Tap "Clear All Data" | Opens destructive confirmation dialog. | PASS |
| **MOB-SET-10** | `Confirm Shred Action` | Confirmation dialog open | Tap "Shred & Reset" | Truncates all SQLite tables and clears secure storage credentials. | PASS |
| **MOB-SET-11** | `Sign Out Button` | User is logged in | Tap "Sign Out" | Clears JWT session, revokes tokens, and returns to Auth screen. | PASS |

---

### Screen 8: Floating Assistant Bot Overlay (Android)
| Test ID | Control Name | Pre-Condition | Action / Input | Expected Result | Pass/Fail |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **MOB-BOT-01** | `Draggable Bubble Icon` | Overlay is active | Drag bubble across screen | Moves smoothly across screen and snaps to left or right margin. | PASS |
| **MOB-BOT-02** | `Single Tap Expand` | Bubble visible | Tap bubble icon | Expands floating quick menu with status and pause/resume button. | PASS |
| **MOB-BOT-03** | `Quick Pause Toggle` | Quick menu open | Tap "Pause Capture" | Instantly pauses capture without opening the main app. | PASS |
| **MOB-BOT-04** | `Open KeyFlow Shortcut`| Quick menu open | Tap "Open KeyFlow" | Brings KeyFlow application to foreground. | PASS |

---

## 3. Web Application Test Matrix (Cloudflare Workers & React)

### Section 1: Public Header & Authentication
| Test ID | Control Name | Pre-Condition | Action / Input | Expected Result | Pass/Fail |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **WEB-AUTH-01** | `Sign In / Register` | Public landing page visible | Click header auth button | Opens Auth Modal with glassmorphic backdrop blur. | PASS |
| **WEB-AUTH-02** | `Auth Modal: Tab Switch`| Modal open | Click "Sign In" / "Register" | Toggles between login and registration form inputs. | PASS |
| **WEB-AUTH-03** | `Sign In Submission` | Credentials entered | Click "Sign In" button | Authenticates; stores token; reveals full 7-tab sidebar navigation. | PASS |
| **WEB-AUTH-04** | `Close Auth Modal 'X'` | Modal open | Click 'X' or outside backdrop| Closes modal cleanly. | PASS |

---

### Section 2: Sidebar Navigation
| Test ID | Control Name | Pre-Condition | Action / Input | Expected Result | Pass/Fail |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **WEB-NAV-01** | `Tab 1: Overview` | Authenticated | Click "Executive Overview" | Renders enterprise KPIs, telemetry volume, and hourly charts. | PASS |
| **WEB-NAV-02** | `Tab 2: Typing Stream` | Authenticated | Click "Typing Stream" | Renders session paragraph feed with Replay Draft affordances. | PASS |
| **WEB-NAV-03** | `Tab 3: Clipboard Feed`| Authenticated | Click "Clipboard History" | Renders classified clipboard feed (Code, URLs, Plain Text). | PASS |
| **WEB-NAV-04** | `Tab 4: Search` | Authenticated | Click "Search & Filtering" | Renders advanced query builder and tabular results. | PASS |
| **WEB-NAV-05** | `Tab 5: App Breakdown` | Authenticated | Click "App Usage Breakdown"| Renders application productivity charts. | PASS |
| **WEB-NAV-06** | `Tab 6: Admin Controls`| Authenticated as Admin | Click "Admin & Org Controls"| Renders user management, role assignments, and device lists. | PASS |
| **WEB-NAV-07** | `Tab 7: Privacy & Exclusions`| Authenticated | Click "Privacy & Exclusions"| Renders blacklisted app packages and DSAR deletion controls. | PASS |
| **WEB-NAV-08** | `Sign Out Button` | Authenticated | Click "Sign Out" in footer | Clears localStorage token; resets state; returns to public landing view. | PASS |

---

### Section 3: Tab 2 — Session Typing Stream Feed
| Test ID | Control Name | Pre-Condition | Action / Input | Expected Result | Pass/Fail |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **WEB-SESS-01** | `Refresh Telemetry` | Stream tab visible | Click "Refresh Telemetry" | Fetches new Supabase entries; decrypts via WebCrypto; renders new cards. | PASS |
| **WEB-SESS-02** | `Search Filter Field` | Stream tab visible | Type search keyword | Filters session cards dynamically in real time. | PASS |
| **WEB-SESS-03** | `App Filter Chips` | Stream tab visible | Click "Chrome" / "Calculator"| Isolates session cards belonging exclusively to selected app. | PASS |
| **WEB-SESS-04** | `Session Copy Button` | Session card visible | Click "Copy" on session card | Copies decrypted paragraph to browser clipboard; shows green toast. | PASS |
| **WEB-SESS-05** | `Replay Draft Button` | Session card visible | Click "Replay Draft" button | Opens interactive Replay Draft Modal with timeline scrubber. | PASS |

---

### Section 4: Replay Draft Modal (Interactive Engine)
| Test ID | Control Name | Pre-Condition | Action / Input | Expected Result | Pass/Fail |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **WEB-RPL-01** | `Timeline Scrubber Slider`| Replay modal open | Drag slider thumb | Updates draft text dynamically to exact keystroke checkpoint. | PASS |
| **WEB-RPL-02** | `Play / Pause Button` | Replay modal open | Click "Play" button | Starts animated typing progression; icon toggles to "Pause". | PASS |
| **WEB-RPL-03** | `1x Speed Multiplier` | Animated playback active | Click "1x" button | Plays at standard typing speed (300ms/step). | PASS |
| **WEB-RPL-04** | `2x Speed Multiplier` | Animated playback active | Click "2x" button | Plays at double speed (150ms/step). | PASS |
| **WEB-RPL-05** | `4x Speed Multiplier` | Animated playback active | Click "4x" button | Plays at quadruple speed (75ms/step). | PASS |
| **WEB-RPL-06** | `Step Counters` | Scrubber moving | Inspect character/word counts| Updates character and word counters in real time at each step. | PASS |
| **WEB-RPL-07** | `Copy Current Step` | Replay modal open | Click "Copy Current Step" | Copies text at current scrubber position to clipboard. | PASS |
| **WEB-RPL-08** | `Close Replay Modal 'X'`| Replay modal open | Click 'X' or press Escape | Closes modal and stops playback timer. | PASS |

---

### Section 5: Tab 3 — Multi-Device Clipboard Feed
| Test ID | Control Name | Pre-Condition | Action / Input | Expected Result | Pass/Fail |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **WEB-CLIP-01** | `Filter Tab: All` | Clipboard tab visible | Click "All" tab | Displays all clipboard entries regardless of classification. | PASS |
| **WEB-CLIP-02** | `Filter Tab: Code` | Clipboard tab visible | Click "Code" tab | Filters view strictly to syntax-classified code snippets. | PASS |
| **WEB-CLIP-03** | `Filter Tab: URLs` | Clipboard tab visible | Click "URLs" tab | Filters view strictly to URL link cards. | PASS |
| **WEB-CLIP-04** | `Filter Tab: Text` | Clipboard tab visible | Click "Plain Text" tab | Filters view strictly to plain text snippets. | PASS |
| **WEB-CLIP-05** | `Code Card: Copy Action`| Code card visible | Click "Copy" button | Copies exact code block to clipboard with toast confirmation. | PASS |
| **WEB-CLIP-06** | `URL Card: Open Link` | URL card visible | Click "Open Link" button | Opens URL in a new browser tab (`target="_blank"`). | PASS |
| **WEB-CLIP-07** | `Pin Star Toggle` | Any clipboard card visible| Click Pin star icon | Pins entry to top of feed; persists pinned state in cloud DB. | PASS |

---

### Section 6: Tab 4 — Search & Filtering
| Test ID | Control Name | Pre-Condition | Action / Input | Expected Result | Pass/Fail |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **WEB-SRCH-01** | `Keyword Query Field` | Search tab visible | Enter `"calculation"` | Populates search parameter. | PASS |
| **WEB-SRCH-02** | `App Filter Select` | Search tab visible | Select "Calculator" dropdown | Scopes search query to Calculator records. | PASS |
| **WEB-SRCH-03** | `Execute Search Button` | Parameters configured | Click "Search" button | Queries database and populates results table with matching rows. | PASS |
| **WEB-SRCH-04** | `Table Row Copy Action`| Results table rendered | Click "Copy" on row | Copies decrypted row snippet to clipboard. | PASS |

---

### Section 7: Tab 7 — Privacy & DSAR Compliance Controls
| Test ID | Control Name | Pre-Condition | Action / Input | Expected Result | Pass/Fail |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **WEB-PRIV-01** | `Package Name Field` | Privacy tab visible | Enter `"com.example.secure"` | Validates package identifier input. | PASS |
| **WEB-PRIV-02** | `Add Exclusion Button` | Package entered | Click "Add Exclusion" | Adds package to global blacklist; persists rule in database. | PASS |
| **WEB-PRIV-03** | `Delete Exclusion Action`| Exclusion row exists | Click "Remove" icon | Deletes rule; permits subsequent logging for that package. | PASS |
| **WEB-PRIV-04** | `GDPR Shred All Data` | Privacy tab visible | Click "Shred All Records" | Opens destructive confirmation modal. | PASS |
| **WEB-PRIV-05** | `Confirm Shred Action` | Modal open | Click "Confirm Purge" | Executes cryptographic purge across all tenant tables. | PASS |
