package com.keyflow.keyflow_app

import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class KeyflowCapturePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, "keyflow/capture")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, "keyflow/capture/stream")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAccessibilityPermissionGranted", "isAccessibilityServiceEnabled" -> {
                result.success(isAccessibilityServiceEnabled())
            }
            "openAccessibilitySettings" -> {
                openAccessibilitySettings()
                result.success(true)
            }
            "startCapture" -> {
                KeyflowAccessibilityService.isPaused = false
                result.success(true)
            }
            "stopCapture", "pauseCapture" -> {
                KeyflowAccessibilityService.isPaused = true
                result.success(true)
            }
            "resumeCapture" -> {
                KeyflowAccessibilityService.isPaused = false
                result.success(true)
            }
            "setExclusionList" -> {
                val list = call.arguments as? List<String>
                if (list != null) {
                    KeyflowAccessibilityService.instance?.updateExclusions(list)
                }
                result.success(true)
            }
            "setAutostart" -> {
                result.success(true)
            }
            "isAutostartEnabled" -> {
                result.success(true)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedService = "${context.packageName}/${KeyflowAccessibilityService::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServices)

        while (colonSplitter.hasNext()) {
            val componentName = colonSplitter.next()
            if (componentName.equals(expectedService, ignoreCase = true)) {
                return true
            }
        }
        return false
    }

    private fun openAccessibilitySettings() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    // MARK: - EventChannel.StreamHandler
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
        KeyflowAccessibilityService.eventListener = { eventMap ->
            this.eventSink?.success(eventMap)
        }
    }

    override fun onCancel(arguments: Any?) {
        this.eventSink = null
        KeyflowAccessibilityService.eventListener = null
    }
}
