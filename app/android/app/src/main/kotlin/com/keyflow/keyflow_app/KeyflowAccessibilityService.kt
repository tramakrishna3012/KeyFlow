package com.keyflow.keyflow_app

import android.accessibilityservice.AccessibilityService
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import androidx.core.app.NotificationCompat

class KeyflowAccessibilityService : AccessibilityService() {

    companion object {
        const val TAG = "KeyflowA11y"
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
        Log.d(TAG, "KeyflowAccessibilityService created")
    }

    override fun onDestroy() {
        super.onDestroy()
        if (instance == this) {
            instance = null
        }
        Log.d(TAG, "KeyflowAccessibilityService destroyed")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        // Show a regular status notification (NOT startForeground — that's illegal
        // for AccessibilityService and causes the "Not working" crash).
        showStatusNotification()
        Log.d(TAG, "KeyflowAccessibilityService connected and ready")
    }

    fun updateExclusions(exclusions: List<String>) {
        exclusionSet = exclusions.map { it.lowercase() }.toSet()
        prefs.edit().putStringSet(KEY_EXCLUSIONS, exclusionSet).apply()
    }

    private fun loadExclusions() {
        exclusionSet = prefs.getStringSet(KEY_EXCLUSIONS, emptySet()) ?: emptySet()
    }

    /**
     * Shows a regular notification to indicate the service is active.
     * AccessibilityService must NOT call startForeground() — Android manages
     * the service lifecycle itself. Calling startForeground() on an
     * AccessibilityService causes an immediate crash ("Not working").
     */
    private fun showStatusNotification() {
        try {
            val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "KeyFlow Active Status",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Notification displaying KeyFlow input capture status"
                }
                notificationManager.createNotificationChannel(channel)
            }

            val notification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("KeyFlow — Active")
                .setContentText("Text capture service is running")
                .setSmallIcon(android.R.drawable.ic_menu_edit)
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .build()

            notificationManager.notify(NOTIFICATION_ID, notification)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show status notification", e)
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || isPaused) return

        try {
            // Only process text-change events
            if (event.eventType != AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED &&
                event.eventType != AccessibilityEvent.TYPE_VIEW_FOCUSED
            ) {
                return
            }

            // SECURITY: Check if field is flagged as a password/secure field
            val isPassword = event.isPassword
            if (isPassword) return

            val sourceNode = try { event.source } catch (_: Exception) { null }
            if (sourceNode?.isPassword == true) {
                sourceNode.recycle()
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
        } catch (e: Exception) {
            Log.e(TAG, "Error processing accessibility event", e)
        }
    }

    private fun isPackageExcluded(packageName: String): Boolean {
        if (exclusionSet.isEmpty()) return false
        val lowerPkg = packageName.lowercase()
        return exclusionSet.any { excludedItem ->
            excludedItem.isNotEmpty() && lowerPkg.contains(excludedItem)
        }
    }

    /**
     * Extracts the incrementally typed text from an accessibility event.
     *
     * For TYPE_VIEW_TEXT_CHANGED events, Android provides:
     * - event.beforeText: the text BEFORE the change
     * - event.text[0]: the full text AFTER the change
     * - event.fromIndex: where the change started
     * - event.addedCount: how many characters were added
     *
     * We extract only the newly added characters to avoid sending
     * the entire field content on every keystroke.
     */
    private fun extractText(event: AccessibilityEvent): String? {
        try {
            if (event.eventType == AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED) {
                val fullText = if (event.text != null && event.text.isNotEmpty()) {
                    event.text.joinToString("")
                } else {
                    null
                }

                if (fullText != null && event.addedCount > 0) {
                    val fromIndex = event.fromIndex
                    val endIndex = fromIndex + event.addedCount
                    if (fromIndex >= 0 && endIndex <= fullText.length) {
                        return fullText.substring(fromIndex, endIndex)
                    }
                }

                // Fallback: if we can't compute the diff, return full text
                return fullText
            }

            // For other event types, try to get text from the source node
            val sourceText = try { event.source?.text?.toString() } catch (_: Exception) { null }
            return sourceText
        } catch (e: Exception) {
            Log.e(TAG, "Error extracting text", e)
            return null
        }
    }

    override fun onInterrupt() {
        Log.d(TAG, "KeyflowAccessibilityService interrupted")
    }
}
