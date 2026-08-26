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
                    AccessibilityEvent.TYPE_VIEW_FOCUSED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                    AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
            notificationTimeout = 100
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
        android.util.Log.i("KeyflowA11y", "onAccessibilityEvent: type=${event.eventType}, pkg=$packageName, paused=$isPaused, isExcluded=${exclusionSet.contains(packageName)}")
        if (isPaused) return

        if (exclusionSet.contains(packageName)) return


        if (event.eventType == AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED ||
            event.eventType == AccessibilityEvent.TYPE_VIEW_FOCUSED) {

            var text = event.text.joinToString("")
            if (text.isBlank()) {
                try {
                    text = event.source?.text?.toString() ?: ""
                } catch (_: Exception) {
                    text = ""
                }
            }

            android.util.Log.i("KeyflowA11y", "Event type=${event.eventType} extracted text: '$text', isSensitive=${isSensitiveNodeOrEvent(event)}")
            if (text.isBlank()) return

            if (isSensitiveNodeOrEvent(event)) return

            val now = System.currentTimeMillis()
            if (event.eventType == AccessibilityEvent.TYPE_VIEW_FOCUSED &&
                text == lastDispatchedText &&
                packageName == lastDispatchedPackage &&
                (now - lastDispatchedTime) < 5000L) {
                android.util.Log.i("KeyflowA11y", "Skipping duplicate focus event for $packageName: '$text'")
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
            android.util.Log.i("KeyflowA11y", "Invoking eventListener with text '$text', listener=$eventListener")
            eventListener?.invoke(payload)
        }
    }


    private fun isSensitiveNodeOrEvent(event: AccessibilityEvent): Boolean {
        if (event.isPassword) {
            android.util.Log.i("KeyflowA11y", "Sensitive: event.isPassword is true")
            return true
        }

        val source = event.source ?: return false
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

                android.util.Log.i("KeyflowA11y", "Sensitive check: inputType=0x${Integer.toHexString(inputType)}, variation=0x${Integer.toHexString(variation)}, isPasswordVariation=$isPasswordVariation")

                if (isPasswordVariation) {
                    return true
                }
            }
        } finally {
            try {
                source.recycle()
            } catch (_: Exception) {
                // Safe ignore if already recycled by framework
            }
        }
        return false
    }

    override fun onInterrupt() {
        // No-op: KeyFlow accessibility service interruption handling is managed lifecycle-wide.
    }

    override fun onDestroy() {
        super.onDestroy()
        if (instance == this) instance = null
    }
}

