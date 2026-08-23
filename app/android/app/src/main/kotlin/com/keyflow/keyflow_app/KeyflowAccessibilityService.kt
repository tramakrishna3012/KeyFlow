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

            if (isSensitiveNodeOrEvent(event)) return

            val payload = mapOf(
                "appName" to packageName,
                "windowTitle" to packageName,
                "text" to text,
                "timestamp" to System.currentTimeMillis()
            )
            eventListener?.invoke(payload)
        }
    }

    private fun isSensitiveNodeOrEvent(event: AccessibilityEvent): Boolean {
        if (event.isPassword) return true

        val source = event.source ?: return false
        try {
            if (source.isPassword) return true

            val inputType = source.inputType
            if (inputType != 0) {
                val variation = inputType and InputType.TYPE_MASK_VARIATION
                val isPasswordVariation = variation == InputType.TYPE_TEXT_VARIATION_PASSWORD ||
                        variation == InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD ||
                        variation == InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD ||
                        variation == InputType.TYPE_NUMBER_VARIATION_PASSWORD

                val isClassTextPassword = (inputType and InputType.TYPE_CLASS_TEXT != 0) &&
                        ((inputType and InputType.TYPE_TEXT_VARIATION_PASSWORD != 0) ||
                         (inputType and InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD != 0) ||
                         (inputType and InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD != 0))

                val isClassNumberPassword = (inputType and InputType.TYPE_CLASS_NUMBER != 0) &&
                        (inputType and InputType.TYPE_NUMBER_VARIATION_PASSWORD != 0)

                if (isPasswordVariation || isClassTextPassword || isClassNumberPassword) {
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

    fun updateExclusions(exclusions: List<String>) {
        exclusionList.clear()
        exclusionList.addAll(exclusions)
    }
}
