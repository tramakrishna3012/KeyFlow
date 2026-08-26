package com.keyflow.keyflow_app

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.text.TextUtils
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File


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
            "isCapturePaused" -> {
                result.success(KeyflowAccessibilityService.isPaused)
            }
            "startCapture" -> {
                KeyflowAccessibilityService.isPaused = false
                KeyflowAccessibilityService.instance?.updateForegroundNotification(false)
                KeyflowOverlayService.notifyStatusChanged()
                result.success(true)
            }
            "stopCapture", "pauseCapture" -> {
                KeyflowAccessibilityService.isPaused = true
                KeyflowAccessibilityService.instance?.updateForegroundNotification(true)
                KeyflowOverlayService.notifyStatusChanged()
                result.success(true)
            }
            "resumeCapture" -> {
                KeyflowAccessibilityService.isPaused = false
                KeyflowAccessibilityService.instance?.updateForegroundNotification(false)
                KeyflowOverlayService.notifyStatusChanged()
                result.success(true)
            }
            "canDrawOverlays" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    result.success(Settings.canDrawOverlays(context))
                } else {
                    result.success(true)
                }
            }
            "requestOverlayPermission" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:${context.packageName}")
                    ).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    result.success(true)
                } else {
                    result.success(true)
                }
            }
            "showOverlayBubble" -> {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context)) {
                    KeyflowOverlayService.start(context)
                    result.success(true)
                } else {
                    result.success(false)
                }
            }
            "hideOverlayBubble" -> {
                KeyflowOverlayService.stop(context)
                result.success(true)
            }
            "getInstalledApps" -> {
                val includeSystem = call.argument<Boolean>("includeSystem") ?: false
                Thread {
                    val apps = getInstalledApps(includeSystem)
                    val handler = android.os.Handler(android.os.Looper.getMainLooper())
                    handler.post {
                        result.success(apps)
                    }
                }.start()
            }
            "setExclusionList" -> {
                val list = (call.arguments as? List<*>)?.filterIsInstance<String>()
                if (list != null) {
                    KeyflowAccessibilityService.updateExclusions(list)
                }
                result.success(true)
            }
            "setAutostart" -> {
                result.success(true)
            }
            "isAutostartEnabled" -> {
                result.success(true)
            }

            "canRequestPackageInstalls" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    result.success(context.packageManager.canRequestPackageInstalls())
                } else {
                    result.success(true)
                }
            }
            "openUnknownAppSourcesSettings" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                        data = Uri.parse("package:${context.packageName}")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    result.success(true)
                } else {
                    result.success(true)
                }
            }
            "installApk" -> {
                val filePath = call.argument<String>("filePath")
                if (filePath.isNullOrBlank()) {
                    result.error("INVALID_PATH", "File path cannot be null or empty", null)
                    return
                }
                val installSuccess = installApkFile(filePath)
                result.success(installSuccess)
            }
            "getPendingEvents" -> {
                val file = java.io.File(context.filesDir, "pending_events.jsonl")
                if (file.exists()) {
                    val lines = file.readLines()
                    val list = lines.filter { it.isNotBlank() }.mapNotNull { line ->
                        try {
                            val json = org.json.JSONObject(line)
                            val map = mutableMapOf<String, Any?>()
                            json.keys().forEach { k -> map[k] = json.get(k) }
                            map
                        } catch (_: Exception) {
                            null
                        }
                    }
                    file.delete()
                    result.success(list)
                } else {
                    result.success(emptyList<Map<String, Any?>>())
                }
            }
            "isBatteryOptimizationIgnored" -> {
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as? android.os.PowerManager
                val isIgnored = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    powerManager?.isIgnoringBatteryOptimizations(context.packageName) ?: false
                } else {
                    true
                }
                result.success(isIgnored)
            }
            "requestIgnoreBatteryOptimizations" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    val powerManager = context.getSystemService(Context.POWER_SERVICE) as? android.os.PowerManager
                    if (powerManager?.isIgnoringBatteryOptimizations(context.packageName) == false) {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:${context.packageName}")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                    }
                }
                result.success(true)
            }
            else -> {
                result.notImplemented()
            }
        }
    }


    private fun installApkFile(filePath: String): Boolean {
        return try {
            val file = File(filePath)
            if (!file.exists()) return false

            val apkUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                FileProvider.getUriForFile(
                    context,
                    "${context.packageName}.fileprovider",
                    file
                )
            } else {
                Uri.fromFile(file)
            }

            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(apkUri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
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

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
        val handler = android.os.Handler(android.os.Looper.getMainLooper())
        KeyflowAccessibilityService.eventListener = { eventMap ->
            handler.post {
                this.eventSink?.success(eventMap)
            }
        }
    }

    override fun onCancel(arguments: Any?) {
        this.eventSink = null
        KeyflowAccessibilityService.eventListener = null
    }

    private fun getInstalledApps(includeSystem: Boolean): List<Map<String, Any?>> {
        val pm = context.packageManager
        val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val resolveInfos = pm.queryIntentActivities(mainIntent, 0)
        val appList = mutableListOf<Map<String, Any?>>()
        val seenPackages = mutableSetOf<String>()

        for (info in resolveInfos) {
            val packageName = info.activityInfo.packageName
            if (packageName == context.packageName) continue
            if (seenPackages.contains(packageName)) continue
            seenPackages.add(packageName)

            val appName = info.loadLabel(pm).toString()
            val isSystem = (info.activityInfo.applicationInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0

            if (!includeSystem && isSystem) {
                val lowerPkg = packageName.lowercase()
                val isEssentialUserFacing = lowerPkg.contains("chrome") ||
                        lowerPkg.contains("browser") ||
                        lowerPkg.contains("calculator") ||
                        lowerPkg.contains("notes") ||
                        lowerPkg.contains("message") ||
                        lowerPkg.contains("mail") ||
                        lowerPkg.contains("gallery") ||
                        lowerPkg.contains("camera") ||
                        lowerPkg.contains("clock") ||
                        lowerPkg.contains("contact") ||
                        lowerPkg.contains("dialer") ||
                        lowerPkg.contains("deskclock")
                if (!isEssentialUserFacing) {
                    continue
                }
            }

            val iconBytes = drawableToByteArray(info.loadIcon(pm))
            val isBanking = isLikelyBankingApp(packageName, appName)

            appList.add(
                mapOf(
                    "appName" to appName,
                    "packageName" to packageName,
                    "appIcon" to iconBytes,
                    "isSystemApp" to isSystem,
                    "isBankingApp" to isBanking
                )
            )
        }

        appList.sortBy { (it["appName"] as? String)?.lowercase() ?: "" }
        return appList
    }

    private fun isLikelyBankingApp(packageName: String, appName: String): Boolean {
        val lowerPkg = packageName.lowercase()
        val lowerName = appName.lowercase()

        val keywords = listOf(
            "bank", "pay", "upi", "wallet", "finance", "money", "crypto",
            "credit", "paisa", "phonepe", "paytm", "gpay", "dreamplug",
            "bhim", "cred", "revolut", "monzo", "chase", "wells", "citi",
            "capitalone", "barclays", "hsbc", "santander", "fidelity",
            "schwab", "robinhood", "coinbase", "binance", "paypal", "venmo",
            "cashapp", "zelle", "klarna", "afterpay", "affirm", "hdfc",
            "icici", "sbi", "axis", "kotak"
        )
        return keywords.any { lowerPkg.contains(it) || lowerName.contains(it) }
    }

    private fun drawableToByteArray(drawable: Drawable?): ByteArray? {
        if (drawable == null) return null
        return try {
            val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
                drawable.bitmap
            } else {
                val width = if (drawable.intrinsicWidth > 0) Math.min(drawable.intrinsicWidth, 96) else 96
                val height = if (drawable.intrinsicHeight > 0) Math.min(drawable.intrinsicHeight, 96) else 96
                val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bmp)
                drawable.setBounds(0, 0, canvas.width, canvas.height)
                drawable.draw(canvas)
                bmp
            }
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 85, stream)
            stream.toByteArray()
        } catch (_: Exception) {
            null
        }
    }
}

