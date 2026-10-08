package com.keyflow.keyflow_app

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val SECURITY_CHANNEL = "com.keyflow.app/security"
        const val DEEP_LINK_CHANNEL = "com.keyflow.app/deeplink"
    }

    private var initialDeepLink: String? = null
    private var deepLinkChannel: MethodChannel? = null

    private val isDebuggable: Boolean
        get() = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val isDemoIntent = intent?.getBooleanExtra("DEMO_MODE", false) == true
        if (!isDebuggable && !isDemoIntent) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }

        if (intent?.action == Intent.ACTION_VIEW) {
            initialDeepLink = intent?.dataString
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val link = intent.dataString
        if (link != null) {
            deepLinkChannel?.invokeMethod("onDeepLink", link)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(KeyflowCapturePlugin())

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURITY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecureFlag" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    if (enabled && !isDebuggable) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        val dlChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEEP_LINK_CHANNEL)
        deepLinkChannel = dlChannel
        dlChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> {
                    val link = initialDeepLink
                    initialDeepLink = null
                    result.success(link)
                }
                else -> result.notImplemented()
            }
        }
    }
}

