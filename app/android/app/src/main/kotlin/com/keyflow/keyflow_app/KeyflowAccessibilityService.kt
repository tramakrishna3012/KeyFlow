package com.keyflow.keyflow_app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class KeyflowAccessibilityService : AccessibilityService() {

    companion object {
        var instance: KeyflowAccessibilityService? = null
        var isPaused: Boolean = false
        var eventListener: ((Map<String, Any?>) -> Unit)? = null
    }

    private val exclusionList = mutableSetOf<String>()

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
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || isPaused) return

        val packageName = event.packageName?.toString() ?: return
        if (exclusionList.contains(packageName)) return

        if (event.eventType == AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED) {
            val text = event.text.joinToString("")
            if (text.isBlank()) return

            if (event.isPassword) return

            val payload = mapOf(
                "appName" to packageName,
                "windowTitle" to packageName,
                "text" to text,
                "timestamp" to System.currentTimeMillis()
            )
            eventListener?.invoke(payload)
        }
    }

    override fun onInterrupt() {
        // No-op: KeyFlow accessibility service interruption handling is managed lifecycle-wide.
    }

    override fun onDestroy() {
        super.onDestroy()
        if (instance == this) instance = null
    }

    fun updateExclusions(exclusions: List<String>) {
        exclusionList.clear()
        exclusionList.addAll(exclusions)
    }
}
