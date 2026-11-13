# KeyFlow — Graphify Audit & AST / Dependency Map

_Generated audit for upcoming work. Scope: Flutter app (`app/`), Express backend (`backend/`),
web dashboard (`web/`), native capture engines (`native/`, Android `app/android`)._

Head at time of audit: `main` @ merge of PR #4.
Flutter tests: **117 pass**. Backend tests: **18 pass** (need `npm install` first).

---

## 1. Executive status — the five things you asked about

| Area | Status | One-line reason |
|------|--------|-----------------|
| App ↔ web dashboard sync | ❌ **Not wired** | Supabase never initialized → `syncServiceProvider` is always `null` → nothing is pushed to Supabase **or** the Express backend. |
| Keystroke capture / debounce / word-completion | ✅ Working, tested | 1000 ms inactivity debounce, 60 s session timeout, 5-char draft snapshots, app-switch seals session. |
| WhatsApp captured, UPI/bank excluded | ✅ Working (keyword-based caveat) | 4 layers of exclusion; obscure payment apps rely on the broad onboarding list or manual add. |
| No pop-up notifications + runs in background | ✅ Correct | Foreground service, `IMPORTANCE_MIN` silent channel; one mandatory ongoing notification can't be removed by design. |
| Supabase / Postgres "live" DB | ❌ **Loose** | App doesn't connect to Supabase; backend uses **ephemeral SQLite on Render**, not Postgres. |

---

## 2. Data-flow (the "AST tree" of the capture → dashboard pipeline)

```
[User types]
   │
   ▼
Android KeyflowAccessibilityService.onAccessibilityEvent          (native)
   │   • ignoredPackages? -> drop + clear foregroundAppExcluded
   │   • isFinancialOrExcluded(pkg)? -> drop (UPI/bank/user list)   ← exclusion layer A
   │   • isSensitiveNodeOrEvent? (password/pin/otp/cvv) -> drop
   │   • dedupe (800 ms)
   ▼  EventChannel "keyflow/capture/stream"  (or disk buffer pending_events.jsonl)
CaptureService._onNativeEvent                                     (app/lib/features/capture/capture_service.dart)
   │   • isAppExcluded(appName)? -> drop                           ← exclusion layer B (Dart)
   │   • isCopied? -> _saveDirectEntry
   │   └── else -> DartSessionAggregator.handleTypingInput
   ▼
DartSessionAggregator                                             (session_aggregator.dart)
   │   • isPrivacySensitive(app,title,isPwd)? -> drop             ← exclusion layer C (title regex)
   │   • debounce 1000 ms  ─────────────► onSessionUpdate
   │   • timeout 60 000 ms ─────────────► onSessionFinalize
   │   • draft snapshot every 5 chars
   ▼
CaptureService._onSessionAggregatorUpdate
   │   • isAppExcluded(session.appName)? -> drop                   ← exclusion layer D (late)
   │   • sanitize (LookWindowSanitizer)
   ├───────────────► HistoryRepository.addEntry  → SQLite (SQLCipher)   ✅ ACTIVE
   └───────────────► activeSyncService?.syncEntry(entry)
                         │
                         ▼   activeSyncService == null  ← BLOCKED (see §3)
                      SyncService.syncEntry                        (sync_service.dart)
                         ├── _syncToSupabase  → Supabase Postgres   ❌ dead
                         └── _syncToBackend   → POST /api/v1/activity/batch
                                                 → Express (onrender.com)
                                                 → SQLite on disk    ⚠️ ephemeral
                                                 → web dashboard reads it
```

Legend: ✅ active · ⚠️ works but fragile · ❌ never executes.

---

## 3. Root cause of the broken dashboard link

Provider wiring (`app/lib/data/providers.dart`):

```
encryptionServiceProvider ──► supabaseHistoryRepositoryProvider ──► syncServiceProvider ──► captureServiceProvider
                                      │ Supabase.instance.client            │
                                      │ (throws: never initialized)         │ returns null when repo null
                                      ▼                                     ▼
                                   returns null  ───────────────────────► syncService = null
```

- `app/lib/main.dart:28-34` — Supabase init intentionally removed; comment says "using backend API only", but the backend path is **also** gated behind the Supabase repo, so it never runs either.
- `app/lib/data/providers.dart:56-77` — `supabaseHistoryRepositoryProvider` / `syncServiceProvider` return `null` because `Supabase.instance.client` throws (debug) / is unreliable (release, assertions off).
- `app/lib/features/capture/capture_service.dart:419,460` — `unawaited(activeSyncService?.syncEntry(entry))` → no-op when null.

**Fix options for upcoming work (pick one):**
1. **Decouple the backend path from Supabase.** Build `SyncService` with just the Express client so `_syncToBackend` runs even when Supabase is off. (Smallest change; restores the dashboard feed.)
2. **Actually initialize Supabase** in `main.dart` with URL/anon-key from `--dart-define`, and keep both paths. Requires confirming the web dashboard reads from the same Supabase project + matching the client-side AES key derivation across devices (see §5).
3. Drop Supabase entirely and make the Express backend the single source of truth.

---

## 4. Storage layers referenced vs. actually used

| Layer | Code | Used at runtime? | Notes |
|-------|------|------------------|-------|
| Local encrypted SQLite | `sqlite_history_repository.dart` + SQLCipher | ✅ Yes | Primary store. Working. |
| Supabase Postgres (direct) | `supabase_history_repository.dart`, `supabase/migrations/*.sql` | ❌ No | Never initialized. Migrations unused. |
| Express backend | `backend/` + `sync_service._syncToBackend` | ❌ No (gated) | Would work if sync were wired. |
| Backend DB | `backend/src/services/db.js` | ⚠️ `sqlite3` | **Not Postgres.** Ephemeral on Render → data loss on redeploy unless a persistent disk/volume is attached, or migrate to managed Postgres. |

Emoji/translation Supabase providers (`supabase_providers.dart`) also hit the uninitialized client, but they **fall back gracefully** to static datasets via `.when(error: …)` — no crash.

---

## 5. Secondary findings / risks for upcoming work

1. **Cross-device decryption** (`encryption_service.dart`): the AES-256-GCM key is derived from `userId` via HKDF with salt `kf_<userId>`. For the web dashboard to show captured text, it must derive the **identical** key. If the pairing `encryption_seed` and the web deriver don't match this scheme exactly, synced rows decrypt to garbage and are silently skipped (`supabase_history_repository.dart` catches and skips). Verify end-to-end before trusting the dashboard.
2. **UPI/bank exclusion is keyword-based.** `KeyflowAccessibilityService.financialRegex` = `bank|upi|payment|wallet|creditcard|authenticator` + a fixed `knownFinancialPackages` set. Apps like `com.phonepe.app` are caught only because they're in the known set (the name has no keyword). Recommend: treat the onboarding `isLikelyBankingApp` list as the single source, persist it natively, and add a test asserting a sample of real UPI packages are excluded.
3. **Mandatory foreground notification.** Cannot be fully hidden on modern Android; `IMPORTANCE_MIN` is the quietest. If a truly invisible run is required, that's an OS constraint, not a bug — document it for the client.
4. **Backend tests need `npm install`** in CI before `npm test` (they pass once deps exist). Confirm the CI `analyze-and-test` job installs backend deps, or the backend is effectively untested in CI.
5. **`build-android` CI job is skipped**, so the Kotlin capture/exclusion code is never compiled in CI. All native fixes so far are unverified by any automated build. Recommend enabling a debug `assembleDebug` in CI.

---

## 6. Suggested order of work

1. Restore the dashboard feed — decouple `_syncToBackend` from Supabase (§3 option 1). _High impact, low risk._
2. Give the backend a durable DB — persistent disk on Render or managed Postgres (§4). _High impact._
3. Verify cross-device encryption key agreement app ↔ dashboard (§5.1). _Blocks trusting synced data._
4. Enable `build-android` + backend `npm ci` in CI (§5.4–5.5). _Protects every future change._
5. Harden UPI/bank exclusion with a persisted list + tests (§5.2).
