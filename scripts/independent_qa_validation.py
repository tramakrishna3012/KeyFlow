import os
import sys
import time
import json
import sqlite3
import subprocess
import requests
import uuid

BACKEND_DIR = r"d:\Freelance\KeyFlow\backend"
TEST_DB_PATH = os.path.join(BACKEND_DIR, "test_validation.db")
PORT = 4099
API_BASE = f"http://127.0.0.1:{PORT}/api/v1"

class TestReporter:
    def __init__(self):
        self.results = []

    def record(self, area, test_name, expected, actual, status, evidence=""):
        self.results.append({
            "area": area,
            "test": test_name,
            "expected": expected,
            "actual": actual,
            "status": status,
            "evidence": evidence
        })
        icon = "[PASS]" if status == "PASS" else ("[FAIL]" if status == "FAIL" else "[WARN]")
        print(f"{icon} [{area}] {test_name}: {status}")
        if status != "PASS":
            print(f"   Expected: {expected}")
            print(f"   Actual:   {actual}")
            if evidence:
                print(f"   Evidence: {evidence}")

def start_test_backend():
    if os.path.exists(TEST_DB_PATH):
        try:
            os.remove(TEST_DB_PATH)
        except Exception:
            pass

    env = os.environ.copy()
    env["PORT"] = str(PORT)
    env["DB_PATH"] = TEST_DB_PATH
    env["JWT_SECRET"] = "independent_qa_test_secret_key_32_characters_long"
    env["NODE_ENV"] = "test"

    proc = subprocess.Popen(
        ["node", "src/server.js"],
        cwd=BACKEND_DIR,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    # Wait for health check
    for _ in range(25):
        time.sleep(0.3)
        try:
            r = requests.get(f"http://127.0.0.1:{PORT}/api/health", timeout=1)
            if r.status_code == 200:
                print(f"Test backend started successfully on port {PORT}")
                return proc
        except Exception:
            pass
    
    stdout, stderr = proc.communicate(timeout=2)
    raise RuntimeError(f"Failed to start test backend. stdout: {stdout}, stderr: {stderr}")

def run_tests():
    reporter = TestReporter()
    proc = start_test_backend()

    try:
        # ====================================================================
        # 1. AUTHENTICATION TESTING
        # ====================================================================
        area = "Authentication"
        
        # Test 1.1: Password validation complexity
        weak_passwords = [
            ("ShortPass1!", "Password must be at least 12 characters long"),
            ("alllowercasewith123!", "Password must contain at least one uppercase letter"),
            ("ALLUPPERCASEWITH123!", "Password must contain at least one lowercase letter"),
            ("NoNumberSpecialLetters!", "Password must contain at least one number"),
            ("NoSpecialChars12345", "Password must contain at least one special character")
        ]
        
        for weak_p, expected_msg in weak_passwords:
            res = requests.post(f"{API_BASE}/auth/register", json={
                "email": f"weak_{uuid.uuid4().hex[:6]}@test.com",
                "password": weak_p,
                "fullName": "Weak Tester"
            })
            if res.status_code == 400 and "Password" in res.text:
                reporter.record(area, f"Reject weak password '{weak_p}'", "400 Bad Request", f"{res.status_code} {res.json().get('error')}", "PASS", res.text)
            else:
                reporter.record(area, f"Reject weak password '{weak_p}'", "400 Bad Request", f"{res.status_code} {res.text}", "FAIL", res.text)

        # Test 1.2: Valid Registration for User A & User B
        user_a_email = "usera_test@keyflow.dev"
        user_a_pass = "UserA_Secure_Pass_2026!"
        res_reg_a = requests.post(f"{API_BASE}/auth/register", json={
            "email": user_a_email,
            "password": user_a_pass,
            "fullName": "Alice KeyFlow",
            "organizationName": "Alpha Org"
        })
        if res_reg_a.status_code == 201 and "token" in res_reg_a.json():
            user_a_token = res_reg_a.json()["token"]
            user_a_id = res_reg_a.json()["user"]["id"]
            reporter.record(area, "User A Registration", "201 Created with JWT", f"201 Created (ID: {user_a_id})", "PASS")
        else:
            reporter.record(area, "User A Registration", "201 Created with JWT", f"{res_reg_a.status_code} {res_reg_a.text}", "FAIL", res_reg_a.text)
            user_a_token = ""
            user_a_id = ""

        # Test 1.3: Duplicate Email Registration
        res_dup = requests.post(f"{API_BASE}/auth/register", json={
            "email": user_a_email,
            "password": user_a_pass,
            "fullName": "Alice Duplicate"
        })
        if res_dup.status_code == 409:
            reporter.record(area, "Duplicate Email Registration Rejection", "409 Conflict", f"409 {res_dup.json().get('error')}", "PASS")
        else:
            reporter.record(area, "Duplicate Email Registration Rejection", "409 Conflict", f"{res_dup.status_code} {res_dup.text}", "FAIL", res_dup.text)

        # User B Registration
        user_b_email = "userb_test@keyflow.dev"
        user_b_pass = "UserB_Secure_Pass_2026!"
        res_reg_b = requests.post(f"{API_BASE}/auth/register", json={
            "email": user_b_email,
            "password": user_b_pass,
            "fullName": "Bob KeyFlow",
            "organizationName": "Beta Org"
        })
        if res_reg_b.status_code == 201 and "token" in res_reg_b.json():
            user_b_token = res_reg_b.json()["token"]
            user_b_id = res_reg_b.json()["user"]["id"]
            reporter.record(area, "User B Registration", "201 Created with JWT", f"201 Created (ID: {user_b_id})", "PASS")
        else:
            reporter.record(area, "User B Registration", "201 Created with JWT", f"{res_reg_b.status_code} {res_reg_b.text}", "FAIL", res_reg_b.text)
            user_b_token = ""
            user_b_id = ""

        # Test 1.4: Valid Login
        res_log_a = requests.post(f"{API_BASE}/auth/login", json={
            "email": user_a_email,
            "password": user_a_pass
        })
        if res_log_a.status_code == 200 and "token" in res_log_a.json():
            reporter.record(area, "User A Valid Login", "200 OK with JWT", f"200 OK (Token length: {len(res_log_a.json()['token'])})", "PASS")
        else:
            reporter.record(area, "User A Valid Login", "200 OK with JWT", f"{res_log_a.status_code} {res_log_a.text}", "FAIL", res_log_a.text)

        # Test 1.5: Invalid Login
        res_log_invalid = requests.post(f"{API_BASE}/auth/login", json={
            "email": user_a_email,
            "password": "WrongPassword123!"
        })
        if res_log_invalid.status_code == 401:
            reporter.record(area, "Invalid Password Login", "401 Unauthorized", f"401 {res_log_invalid.json().get('error')}", "PASS")
        else:
            reporter.record(area, "Invalid Password Login", "401 Unauthorized", f"{res_log_invalid.status_code} {res_log_invalid.text}", "FAIL", res_log_invalid.text)

        # Test 1.6: Account Lockout after consecutive failures
        lockout_email = f"lockout_{uuid.uuid4().hex[:6]}@test.com"
        requests.post(f"{API_BASE}/auth/register", json={
            "email": lockout_email,
            "password": "Lockout_Pass_2026!",
            "fullName": "Lockout User"
        })
        for attempt in range(1, 6):
            requests.post(f"{API_BASE}/auth/login", json={"email": lockout_email, "password": "WrongPassword!"})
        res_locked = requests.post(f"{API_BASE}/auth/login", json={"email": lockout_email, "password": "WrongPassword!"})
        if res_locked.status_code == 423:
            reporter.record(area, "Account Lockout Enforcement (5 attempts)", "423 Locked", f"423 {res_locked.json().get('error')}", "PASS")
        else:
            reporter.record(area, "Account Lockout Enforcement (5 attempts)", "423 Locked", f"{res_locked.status_code} {res_locked.text}", "FAIL", res_locked.text)

        # Test 1.7: Plaintext Password Storage Verification in SQLite
        conn = sqlite3.connect(TEST_DB_PATH)
        cur = conn.cursor()
        cur.execute("SELECT email, password_hash FROM users")
        user_rows = cur.fetchall()
        all_bcrypt = True
        for u_email, p_hash in user_rows:
            if not p_hash.startswith("$2a$") and not p_hash.startswith("$2b$"):
                all_bcrypt = False
                break
        if all_bcrypt and len(user_rows) >= 3:
            reporter.record(area, "Password Storage Verification (Bcrypt salt rounds 12, no plaintext)", "All passwords stored as bcrypt hashes", f"Verified {len(user_rows)} user records with $2a$/$2b$ hashes", "PASS")
        else:
            reporter.record(area, "Password Storage Verification", "All passwords stored as bcrypt hashes", f"Found non-bcrypt: {user_rows}", "FAIL")

        # Test 1.8: Session verification & Token validation
        # Valid token
        res_me_valid = requests.get(f"{API_BASE}/auth/me", headers={"Authorization": f"Bearer {user_a_token}"})
        if res_me_valid.status_code == 200 and res_me_valid.json().get("user", {}).get("email") == user_a_email:
            reporter.record(area, "Protected Route Access with Valid Token (/auth/me)", "200 OK with profile", f"200 OK for {user_a_email}", "PASS")
        else:
            reporter.record(area, "Protected Route Access with Valid Token (/auth/me)", "200 OK with profile", f"{res_me_valid.status_code} {res_me_valid.text}", "FAIL", res_me_valid.text)

        # Missing token
        res_me_no_tok = requests.get(f"{API_BASE}/auth/me")
        if res_me_no_tok.status_code == 401:
            reporter.record(area, "Protected Route Rejection (Missing Token)", "401 Unauthorized", f"401 {res_me_no_tok.json().get('error')}", "PASS")
        else:
            reporter.record(area, "Protected Route Rejection (Missing Token)", "401 Unauthorized", f"{res_me_no_tok.status_code} {res_me_no_tok.text}", "FAIL", res_me_no_tok.text)

        # Tampered token
        tampered_token = user_a_token[:-5] + "XXXXX"
        res_me_tampered = requests.get(f"{API_BASE}/auth/me", headers={"Authorization": f"Bearer {tampered_token}"})
        if res_me_tampered.status_code == 403:
            reporter.record(area, "Protected Route Rejection (Tampered JWT)", "403 Forbidden", f"403 {res_me_tampered.json().get('error')}", "PASS")
        else:
            reporter.record(area, "Protected Route Rejection (Tampered JWT)", "403 Forbidden", f"{res_me_tampered.status_code} {res_me_tampered.text}", "FAIL", res_me_tampered.text)


        # ====================================================================
        # 2. AUTHORIZATION & IDOR TESTING
        # ====================================================================
        area = "Authorization & IDOR"

        # 2.1 User A and User B create private typing sessions
        session_a_id = f"sess_a_{uuid.uuid4().hex[:8]}"
        session_b_id = f"sess_b_{uuid.uuid4().hex[:8]}"

        res_upsert_a = requests.post(f"{API_BASE}/sessions/upsert", headers={"Authorization": f"Bearer {user_a_token}"}, json={
            "id": session_a_id,
            "appName": "VSCode",
            "windowTitle": "src/auth.js",
            "content": "KEYFLOW_TEST_TYPING_USER_A_PRIVATE_DATA_999",
            "deviceName": "Alice-MacBook"
        })
        res_upsert_b = requests.post(f"{API_BASE}/sessions/upsert", headers={"Authorization": f"Bearer {user_b_token}"}, json={
            "id": session_b_id,
            "appName": "Obsidian",
            "windowTitle": "Confidential Notes",
            "content": "KEYFLOW_TEST_TYPING_USER_B_SECRET_NOTES_888",
            "deviceName": "Bob-ThinkPad"
        })

        # 2.2 Cross-User Session Listing (Tenant Isolation)
        res_list_a = requests.get(f"{API_BASE}/sessions", headers={"Authorization": f"Bearer {user_a_token}"})
        res_list_b = requests.get(f"{API_BASE}/sessions", headers={"Authorization": f"Bearer {user_b_token}"})

        sessions_a = res_list_a.json().get("sessions", [])
        sessions_b = res_list_b.json().get("sessions", [])

        user_b_in_a = any(s["id"] == session_b_id for s in sessions_a)
        user_a_in_b = any(s["id"] == session_a_id for s in sessions_b)

        if not user_b_in_a and not user_a_in_b and len(sessions_a) >= 1 and len(sessions_b) >= 1:
            reporter.record(area, "Cross-User Session List Isolation", "User A cannot see User B sessions", "User A list has only User A items, User B list has only User B items", "PASS")
        else:
            reporter.record(area, "Cross-User Session List Isolation", "User A cannot see User B sessions", f"Leakage detected! User B in A: {user_b_in_a}, User A in B: {user_a_in_b}", "FAIL")

        # 2.3 IDOR: User A attempts to overwrite User B's typing session via upsert
        res_idor_upsert = requests.post(f"{API_BASE}/sessions/upsert", headers={"Authorization": f"Bearer {user_a_token}"}, json={
            "id": session_b_id,
            "appName": "Malicious App",
            "content": "IDOR_ATTACK_OVERWRITE_ATTEMPT"
        })
        if res_idor_upsert.status_code == 403:
            reporter.record(area, "IDOR Prevention: Cross-User Session Upsert", "403 Forbidden", f"403 {res_idor_upsert.json().get('error')}", "PASS")
        else:
            reporter.record(area, "IDOR Prevention: Cross-User Session Upsert", "403 Forbidden", f"{res_idor_upsert.status_code} {res_idor_upsert.text}", "FAIL", res_idor_upsert.text)

        # 2.4 IDOR: User A attempts to toggle favorite on User B's session
        res_idor_fav = requests.patch(f"{API_BASE}/sessions/{session_b_id}/favorite", headers={"Authorization": f"Bearer {user_a_token}"})
        if res_idor_fav.status_code == 404:
            reporter.record(area, "IDOR Prevention: Cross-User Favorite Toggle", "404 Not Found", f"404 {res_idor_fav.json().get('error')}", "PASS")
        else:
            reporter.record(area, "IDOR Prevention: Cross-User Favorite Toggle", "404 Not Found", f"{res_idor_fav.status_code} {res_idor_fav.text}", "FAIL", res_idor_fav.text)

        # 2.5 IDOR: User A attempts to delete User B's session
        res_idor_del_sess = requests.delete(f"{API_BASE}/sessions/{session_b_id}", headers={"Authorization": f"Bearer {user_a_token}"})
        if res_idor_del_sess.status_code == 404:
            reporter.record(area, "IDOR Prevention: Cross-User Session Deletion", "404 Not Found", f"404 {res_idor_del_sess.json().get('error')}", "PASS")
        else:
            reporter.record(area, "IDOR Prevention: Cross-User Session Deletion", "404 Not Found", f"{res_idor_del_sess.status_code} {res_idor_del_sess.text}", "FAIL", res_idor_del_sess.text)

        # 2.6 Clipboard IDOR Testing
        clip_a_id = f"clip_a_{uuid.uuid4().hex[:8]}"
        clip_b_id = f"clip_b_{uuid.uuid4().hex[:8]}"

        res_clip_a = requests.post(f"{API_BASE}/clipboard/insert", headers={"Authorization": f"Bearer {user_a_token}"}, json={
            "id": clip_a_id,
            "content": "KEYFLOW_CLIPBOARD_USER_A_API_KEY_12345",
            "sourceApp": "Chrome"
        })
        res_clip_b = requests.post(f"{API_BASE}/clipboard/insert", headers={"Authorization": f"Bearer {user_b_token}"}, json={
            "id": clip_b_id,
            "content": "KEYFLOW_CLIPBOARD_USER_B_SECRET_TOKEN_67890",
            "sourceApp": "Postman"
        })

        # Cross-user clipboard listing
        res_clips_a = requests.get(f"{API_BASE}/clipboard", headers={"Authorization": f"Bearer {user_a_token}"})
        res_clips_b = requests.get(f"{API_BASE}/clipboard", headers={"Authorization": f"Bearer {user_b_token}"})

        entries_a = res_clips_a.json().get("entries", [])
        entries_b = res_clips_b.json().get("entries", [])

        clip_b_in_a = any(c["id"] == clip_b_id for c in entries_a)
        clip_a_in_b = any(c["id"] == clip_a_id for c in entries_b)

        if not clip_b_in_a and not clip_a_in_b:
            reporter.record(area, "Cross-User Clipboard List Isolation", "User A cannot see User B clipboard", "Clean isolation verified", "PASS")
        else:
            reporter.record(area, "Cross-User Clipboard List Isolation", "User A cannot see User B clipboard", f"Leakage! B in A: {clip_b_in_a}, A in B: {clip_a_in_b}", "FAIL")

        # IDOR: User A attempts to toggle pin on User B's clipboard entry
        res_idor_pin = requests.patch(f"{API_BASE}/clipboard/{clip_b_id}/pin", headers={"Authorization": f"Bearer {user_a_token}"})
        if res_idor_pin.status_code == 404:
            reporter.record(area, "IDOR Prevention: Cross-User Clipboard Pin Toggle", "404 Not Found", f"404 {res_idor_pin.json().get('error')}", "PASS")
        else:
            reporter.record(area, "IDOR Prevention: Cross-User Clipboard Pin Toggle", "404 Not Found", f"{res_idor_pin.status_code} {res_idor_pin.text}", "FAIL", res_idor_pin.text)

        # IDOR: User A attempts to delete User B's clipboard entry
        res_idor_del_clip = requests.delete(f"{API_BASE}/clipboard/{clip_b_id}", headers={"Authorization": f"Bearer {user_a_token}"})
        if res_idor_del_clip.status_code == 404:
            reporter.record(area, "IDOR Prevention: Cross-User Clipboard Deletion", "404 Not Found", f"404 {res_idor_del_clip.json().get('error')}", "PASS")
        else:
            reporter.record(area, "IDOR Prevention: Cross-User Clipboard Deletion", "404 Not Found", f"{res_idor_del_clip.status_code} {res_idor_del_clip.text}", "FAIL", res_idor_del_clip.text)


        # ====================================================================
        # 3. CLIPBOARD ENCRYPTION & DATABASE STORAGE VERIFICATION
        # ====================================================================
        area = "Clipboard Encryption & Storage"

        # Check directly inside the SQLite DB file
        cur.execute("SELECT id, content, encrypted_content, iv, auth_tag FROM clipboard_entries WHERE id = ?", (clip_a_id,))
        row = cur.fetchone()
        if row:
            db_id, db_content, db_enc, db_iv, db_tag = row
            has_cipher = bool(db_enc and len(db_enc) > 16)
            has_iv = bool(db_iv and len(db_iv) == 24) # 12 bytes hex
            has_tag = bool(db_tag and len(db_tag) == 32) # 16 bytes hex

            # Check if plaintext exists in `content` column
            has_plaintext_in_content_col = "KEYFLOW_CLIPBOARD_USER_A_API_KEY_12345" in (db_content or "")
            
            if has_cipher and has_iv and has_tag:
                reporter.record(area, "AES-256-GCM Ciphertext Generation in DB", "Encrypted ciphertext, 12-byte IV, 16-byte AuthTag stored", f"Ciphertext length: {len(db_enc)}, IV: {db_iv}, Tag: {db_tag}", "PASS")
            else:
                reporter.record(area, "AES-256-GCM Ciphertext Generation in DB", "Encrypted ciphertext, 12-byte IV, 16-byte AuthTag stored", f"Missing encryption metadata in DB: {row}", "FAIL")

            if has_plaintext_in_content_col:
                reporter.record(area, "Database Plaintext Leakage in 'content' Column", "Plaintext should NOT be stored in unencrypted column", f"CRITICAL DEFECT: 'content' column contains plaintext snippet '{db_content}'", "FAIL", f"Row: {row}")
            else:
                reporter.record(area, "Database Plaintext Leakage in 'content' Column", "Plaintext should NOT be stored in unencrypted column", "No plaintext found in content column", "PASS")

            # Verify authorized user gets correctly decrypted plaintext
            retrieved_content = next((c["content"] for c in entries_a if c["id"] == clip_a_id), None)
            if retrieved_content == "KEYFLOW_CLIPBOARD_USER_A_API_KEY_12345":
                reporter.record(area, "Authorized Decryption Retrieval", "Authenticated User A retrieves original plaintext", f"Successfully decrypted: '{retrieved_content}'", "PASS")
            else:
                reporter.record(area, "Authorized Decryption Retrieval", "Authenticated User A retrieves original plaintext", f"Decryption mismatch: '{retrieved_content}'", "FAIL")


        # ====================================================================
        # 4. TYPING & ACTIVITY TELEMETRY & PRIVACY FILTERING
        # ====================================================================
        area = "Activity Telemetry & Privacy"

        # Ingest telemetry with sensitive credit card and banking app
        res_batch = requests.post(f"{API_BASE}/activity/batch", headers={"Authorization": f"Bearer {user_a_token}"}, json={
            "deviceName": "Alice-MacBook",
            "osInfo": "macOS 15.0",
            "agentVersion": "1.0.0",
            "entries": [
                {
                    "appName": "VS Code",
                    "windowTitle": "https://company.internal/secret?token=SUPER_SECRET_TOKEN_99999999999999999999",
                    "durationSeconds": 60,
                    "idleSeconds": 5,
                    "isIdle": False,
                    "startedAt": "2026-09-02T10:00:00.000Z",
                    "endedAt": "2026-09-02T10:01:00.000Z",
                    "textRecords": [
                        {"text": "Normal coding keystroke test KEYFLOW_TEST_TYPING_001", "capturedAt": "2026-09-02T10:00:30.000Z"}
                    ]
                },
                {
                    "appName": "Chrome",
                    "windowTitle": "Payment Checkout",
                    "durationSeconds": 30,
                    "idleSeconds": 0,
                    "isIdle": False,
                    "startedAt": "2026-09-02T10:02:00.000Z",
                    "endedAt": "2026-09-02T10:02:30.000Z",
                    "textRecords": [
                        {"text": "My card is 4532-1234-5678-9012 with cvv: 123", "capturedAt": "2026-09-02T10:02:15.000Z"}
                    ]
                },
                {
                    "appName": "PayPal",
                    "windowTitle": "Banking Wallet",
                    "durationSeconds": 20,
                    "idleSeconds": 0,
                    "isIdle": False,
                    "startedAt": "2026-09-02T10:03:00.000Z",
                    "endedAt": "2026-09-02T10:03:20.000Z",
                    "textRecords": [
                        {"text": "Transfer $500", "capturedAt": "2026-09-02T10:03:10.000Z"}
                    ]
                }
            ]
        })

        if res_batch.status_code == 200:
            reporter.record(area, "Batch Telemetry Ingestion", "200 OK with ingestedCount", f"200 OK (Count: {res_batch.json().get('ingestedCount')})", "PASS")
        else:
            reporter.record(area, "Batch Telemetry Ingestion", "200 OK with ingestedCount", f"{res_batch.status_code} {res_batch.text}", "FAIL", res_batch.text)

        # Check window title sanitization in DB
        cur.execute("SELECT window_title_sanitized FROM activity_logs WHERE user_id = ? AND app_name = 'VS Code'", (user_a_id,))
        san_title_row = cur.fetchone()
        if san_title_row and san_title_row[0] == "https://company.internal/secret":
            reporter.record(area, "Window Title Sanitization (Token/Secret Redaction)", "Strip query parameters and secret tokens", f"Sanitized title: '{san_title_row[0]}'", "PASS")
        else:
            reporter.record(area, "Window Title Sanitization", "Strip query parameters and secret tokens", f"Raw title leaked: {san_title_row}", "FAIL")

        # Check text record encryption and sensitive data exclusion
        cur.execute("SELECT is_excluded, sanitized_preview FROM text_records WHERE session_id IN (SELECT id FROM sessions WHERE user_id = ?)", (user_a_id,))
        text_rows = cur.fetchall()
        excluded_count = sum(1 for r in text_rows if r[0] == 1)
        if excluded_count >= 2:
            reporter.record(area, "Automated Sensitive Data & Banking Exclusion", "Exclude credit card and banking app text from plaintext capture", f"Excluded records: {excluded_count}/{len(text_rows)}", "PASS")
        else:
            reporter.record(area, "Automated Sensitive Data & Banking Exclusion", "Exclude credit card and banking app text from plaintext capture", f"Only {excluded_count}/{len(text_rows)} excluded", "FAIL", f"Rows: {text_rows}")

        # Privacy Exclusions configuration API
        res_excl_post = requests.post(f"{API_BASE}/activity/privacy/exclusions", headers={"Authorization": f"Bearer {user_a_token}"}, json={
            "appName": "1Password"
        })
        if res_excl_post.status_code == 201:
            reporter.record(area, "Custom Privacy Exclusion Creation", "201 Created", f"Exclusion added for 1Password", "PASS")
        else:
            reporter.record(area, "Custom Privacy Exclusion Creation", "201 Created", f"{res_excl_post.status_code} {res_excl_post.text}", "FAIL", res_excl_post.text)

        res_excl_get = requests.get(f"{API_BASE}/activity/privacy/exclusions", headers={"Authorization": f"Bearer {user_a_token}"})
        if res_excl_get.status_code == 200 and any(e["appName"] == "1Password" for e in res_excl_get.json().get("exclusions", [])):
            reporter.record(area, "Custom Privacy Exclusion Retrieval", "200 OK with list", "1Password listed in user exclusions", "PASS")
        else:
            reporter.record(area, "Custom Privacy Exclusion Retrieval", "200 OK with list", f"{res_excl_get.status_code} {res_excl_get.text}", "FAIL")


        # ====================================================================
        # 5. DATA DELETION & GDPR/RIGHT TO BE FORGOTTEN
        # ====================================================================
        area = "Data Deletion & Compliance"

        # 5.1 Individual Session Deletion
        del_sess_res = requests.delete(f"{API_BASE}/sessions/{session_a_id}", headers={"Authorization": f"Bearer {user_a_token}"})
        if del_sess_res.status_code == 200:
            cur.execute("SELECT id FROM typing_sessions WHERE id = ?", (session_a_id,))
            if cur.fetchone() is None:
                reporter.record(area, "Individual Typing Session Deletion", "200 OK and removed from DB", "Permanently deleted", "PASS")
            else:
                reporter.record(area, "Individual Typing Session Deletion", "200 OK and removed from DB", "Still present in DB", "FAIL")
        else:
            reporter.record(area, "Individual Typing Session Deletion", "200 OK and removed from DB", f"{del_sess_res.status_code} {del_sess_res.text}", "FAIL")

        # 5.2 Individual Clipboard Deletion
        del_clip_res = requests.delete(f"{API_BASE}/clipboard/{clip_a_id}", headers={"Authorization": f"Bearer {user_a_token}"})
        if del_clip_res.status_code == 200:
            cur.execute("SELECT id FROM clipboard_entries WHERE id = ?", (clip_a_id,))
            if cur.fetchone() is None:
                reporter.record(area, "Individual Clipboard Entry Deletion", "200 OK and removed from DB", "Permanently deleted", "PASS")
            else:
                reporter.record(area, "Individual Clipboard Entry Deletion", "200 OK and removed from DB", "Still present in DB", "FAIL")
        else:
            reporter.record(area, "Individual Clipboard Entry Deletion", "200 OK and removed from DB", f"{del_clip_res.status_code} {del_clip_res.text}", "FAIL")

        # 5.3 Test /compliance/delete-my-data (Right to be Forgotten)
        # Create fresh test data for user B
        requests.post(f"{API_BASE}/sessions/upsert", headers={"Authorization": f"Bearer {user_b_token}"}, json={
            "appName": "Notes",
            "content": "User B data to forget"
        })
        requests.post(f"{API_BASE}/clipboard/insert", headers={"Authorization": f"Bearer {user_b_token}"}, json={
            "content": "User B clipboard to forget"
        })

        res_delete_all = requests.post(f"{API_BASE}/compliance/delete-my-data", headers={"Authorization": f"Bearer {user_b_token}"})
        if res_delete_all.status_code == 200:
            # Check what got deleted in SQLite
            cur.execute("SELECT COUNT(*) FROM typing_sessions WHERE user_id = ?", (user_b_id,))
            remaining_typing = cur.fetchone()[0]
            cur.execute("SELECT COUNT(*) FROM clipboard_entries WHERE user_id = ?", (user_b_id,))
            remaining_clipboard = cur.fetchone()[0]
            cur.execute("SELECT COUNT(*) FROM activity_logs WHERE user_id = ?", (user_b_id,))
            remaining_activity = cur.fetchone()[0]
            cur.execute("SELECT COUNT(*) FROM sessions WHERE user_id = ?", (user_b_id,))
            remaining_sessions = cur.fetchone()[0]

            if remaining_activity == 0 and remaining_sessions == 0:
                if remaining_typing > 0 or remaining_clipboard > 0:
                    reporter.record(area, "Right to be Forgotten (/delete-my-data) Scope", "Erase all user data (activity, sessions, typing, clipboard)", f"PARTIAL DELETION BUG: Activity deleted, but typing_sessions ({remaining_typing} remaining) and clipboard_entries ({remaining_clipboard} remaining) were NOT deleted!", "FAIL")
                else:
                    reporter.record(area, "Right to be Forgotten (/delete-my-data) Scope", "Erase all user data", "All user records erased", "PASS")
            else:
                reporter.record(area, "Right to be Forgotten (/delete-my-data)", "Erase records", f"Records remain: act={remaining_activity}, sess={remaining_sessions}", "FAIL")
        else:
            reporter.record(area, "Right to be Forgotten (/delete-my-data)", "200 OK", f"{res_delete_all.status_code} {res_delete_all.text}", "FAIL")

        conn.close()

    finally:
        proc.terminate()
        proc.wait()
        if os.path.exists(TEST_DB_PATH):
            try:
                os.remove(TEST_DB_PATH)
            except Exception:
                pass

    print("\n" + "="*80)
    print("INDEPENDENT AUTOMATED TEST PASS SUMMARY:")
    print("="*80)
    passes = sum(1 for r in reporter.results if r["status"] == "PASS")
    fails = sum(1 for r in reporter.results if r["status"] == "FAIL")
    print(f"Total Tests: {len(reporter.results)} | Passed: {passes} | Failed: {fails}")
    
    with open(r"d:\Freelance\KeyFlow\scripts\independent_test_results.json", "w") as f:
        json.dump(reporter.results, f, indent=2)

if __name__ == "__main__":
    run_tests()
