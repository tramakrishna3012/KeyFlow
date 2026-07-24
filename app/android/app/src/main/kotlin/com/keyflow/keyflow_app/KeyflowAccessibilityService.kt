package com.keyflow.keyflow_app

import android.accessibilityservice.AccessibilityService
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.view.accessibility.AccessibilityEvent
import androidx.core.app.NotificationCompat

class KeyflowAccessibilityService : AccessibilityService() {

    companion object {
        const val PREFS_NAME = "keyflow_accessibility_prefs"
        const val KEY_EXCLUSIONS = "exclusion_list"
        const val CHANNEL_ID = "keyflow_accessibility_channel"
        const val NOTIFICATION_ID = 1001

        var instance: KeyflowAccessibilityService? = null
            private set

        var eventListener: ((Map<String, Any>) -> Unit)? = null
        var isPaused: Boolean = false
    }

    private lateinit var prefs: SharedPreferences
    private var exclusionSet: Set<String> = emptySet()

    override fun onCreate() {
        super.onCreate()
        instance = this
        prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        loadExclusions()
    }

    override fun onDestroy() {
        super.onDestroy()
        if (instance == this) {
            instance = null
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        startPersistentNotification()
    }

    fun updateExclusions(exclusions: List<String>) {
        exclusionSet = exclusions.map { it.lowercase() }.toSet()
        prefs.edit().putStringSet(KEY_EXCLUSIONS, exclusionSet).apply()
    }

    private fun loadExclusions() {
        exclusionSet = prefs.getStringSet(KEY_EXCLUSIONS, emptySet()) ?: emptySet()
    }

    private fun startPersistentNotification() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "KeyFlow Active Status",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Mandatory notification displaying KeyFlow input capture status"
            }
            notificationManager.createNotificationChannel(channel)
        }

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("KeyFlow - Active")
            .setContentText("KeyFlow text capture service is running")
            .setSmallIcon(android.R.drawable.ic_menu_edit)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || isPaused) return

        // SECURITY: Check if field is flagged as a password/secure field
        val sourceNode = event.source
        val isPassword = event.isPassword || (sourceNode?.isPassword == true)
        if (isPassword) {
            sourceNode?.recycle()
            return
        }

        val packageName = event.packageName?.toString() ?: ""
        if (packageName.isEmpty()) {
            sourceNode?.recycle()
            return
        }

        // SECURITY & PRIVACY: Native Exclusion List check before processing
        if (isPackageExcluded(packageName)) {
            sourceNode?.recycle()
            return
        }

        val capturedText = extractText(event)
        sourceNode?.recycle()

        if (!capturedText.isNullOrEmpty() && eventListener != null) {
            val eventMap: Map<String, Any> = mapOf(
                "text" to capturedText,
                "app_name" to packageName,
                "window_title" to packageName,
                "timestamp" to System.currentTimeMillis()
            )
            eventListener?.invoke(eventMap)
        }
    }

    private fun isPackageExcluded(packageName: String): Boolean {
        if (exclusionSet.isEmpty()) return false
        val lowerPkg = packageName.lowercase()
        return exclusionSet.any { excludedItem ->
            excludedItem.isNotEmpty() && lowerPkg.contains(excludedItem)
        }
    }

    private fun extractText(event: AccessibilityEvent): String? {
        if (event.text != null && event.text.isNotEmpty()) {
            val sb = StringBuilder()
            for (t in event.text) {
                sb.append(t)
            }
            return sb.toString()
        }
        return event.source?.text?.toString()
    }

    override fun onInterrupt() {}
}
