package com.keyflow.keyflow_app

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.text.TextUtils
import android.util.DisplayMetrics
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.Switch
import android.widget.TextView
import android.widget.Toast

class KeyflowOverlayService : Service() {

    companion object {
        var instance: KeyflowOverlayService? = null
        var isRunning: Boolean = false

        fun start(context: Context) {
            val intent = Intent(context, KeyflowOverlayService::class.java)
            context.startService(intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, KeyflowOverlayService::class.java)
            context.stopService(intent)
        }

        fun notifyStatusChanged() {
            instance?.updateOverlayViews()
        }

        fun isAccessibilityServiceEnabled(context: Context): Boolean {
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
    }

    private lateinit var windowManager: WindowManager
    private var rootContainer: FrameLayout? = null
    private var bubbleView: View? = null
    private var panelView: View? = null
    private lateinit var layoutParams: WindowManager.LayoutParams

    private var isExpanded = false

    private fun dpToPx(dp: Float): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp,
            resources.displayMetrics
        ).toInt()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        isRunning = true
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        setupLayout()
    }

    private fun setupLayout() {
        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        layoutParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 24
            y = dpToPx(200f)
        }

        rootContainer = FrameLayout(this)
        bubbleView = createBubbleView()
        panelView = createPanelView()

        rootContainer?.addView(bubbleView)
        rootContainer?.addView(panelView)
        panelView?.visibility = View.GONE

        try {
            windowManager.addView(rootContainer, layoutParams)
        } catch (e: Exception) {
            android.util.Log.e("KeyflowOverlay", "Error adding overlay view: $e")
        }
    }

    private fun createBubbleView(): View {
        val size = dpToPx(54f)
        val container = FrameLayout(this).apply {
            layoutParams = FrameLayout.LayoutParams(size, size)
        }

        // Circular background with dark slate #0F172A & sky cyan glow border
        val bgDrawable = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(Color.parseColor("#F20F172A"))
            setStroke(dpToPx(1.5f), Color.parseColor("#38BDF8"))
        }
        container.background = bgDrawable

        // Bot icon emoji / text
        val iconText = TextView(this).apply {
            text = "⚡"
            textSize = 22f
            gravity = Gravity.CENTER
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
        container.addView(iconText)

        // Status indicator dot (Top-right)
        val statusDot = View(this).apply {
            val dotSize = dpToPx(9f)
            val a11yEnabled = isAccessibilityServiceEnabled(this@KeyflowOverlayService)
            val paused = KeyflowAccessibilityService.isPaused
            val dotColor = when {
                !a11yEnabled -> Color.parseColor("#EF4444")
                paused -> Color.parseColor("#F59E0B")
                else -> Color.parseColor("#10B981")
            }
            val dotBg = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(dotColor)
                setStroke(dpToPx(1f), Color.parseColor("#0F172A"))
            }
            background = dotBg
            val lp = FrameLayout.LayoutParams(dotSize, dotSize).apply {
                gravity = Gravity.TOP or Gravity.END
                topMargin = dpToPx(4f)
                rightMargin = dpToPx(4f)
            }
            layoutParams = lp
            tag = "statusDot"
        }
        container.addView(statusDot)

        // Dragging & Click Handling
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var isMoved = false

        container.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = layoutParams.x
                    initialY = layoutParams.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isMoved = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - initialTouchX).toInt()
                    val dy = (event.rawY - initialTouchY).toInt()
                    if (Math.abs(dx) > 10 || Math.abs(dy) > 10) {
                        isMoved = true
                    }
                    layoutParams.x = initialX + dx
                    layoutParams.y = initialY + dy
                    windowManager.updateViewLayout(rootContainer, layoutParams)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!isMoved) {
                        expandPanel()
                    }
                    true
                }
                else -> false
            }
        }

        return container
    }

    private fun createPanelView(): View {
        val width = dpToPx(290f)
        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = FrameLayout.LayoutParams(width, FrameLayout.LayoutParams.WRAP_CONTENT)
            setPadding(dpToPx(16f), dpToPx(14f), dpToPx(16f), dpToPx(14f))

            // Rounded Card background with dark slate #0F172A & subtle cyan border
            val bgDrawable = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dpToPx(16f).toFloat()
                setColor(Color.parseColor("#F20F172A"))
                setStroke(dpToPx(1.2f), Color.parseColor("#38BDF8"))
            }
            background = bgDrawable
        }

        // Header Row: [Icon + Title] [Close X]
        val headerRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        val titleText = TextView(this).apply {
            text = "⚡ KeyFlow Bot"
            setTextColor(Color.WHITE)
            textSize = 14f
            typeface = Typeface.DEFAULT_BOLD
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        headerRow.addView(titleText)

        val closeBtn = TextView(this).apply {
            text = "✕"
            setTextColor(Color.parseColor("#94A3B8"))
            textSize = 15f
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dpToPx(8f), dpToPx(4f), dpToPx(8f), dpToPx(4f))
            setOnClickListener {
                collapsePanel()
            }
        }
        headerRow.addView(closeBtn)
        panel.addView(headerRow)

        // Status Card Row
        val statusContainer = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dpToPx(10f), dpToPx(8f), dpToPx(10f), dpToPx(8f))
            val lp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = dpToPx(10f)
                bottomMargin = dpToPx(8f)
            }
            layoutParams = lp

            val cardBg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dpToPx(10f).toFloat()
                setColor(Color.parseColor("#1E293B"))
                setStroke(dpToPx(0.8f), Color.parseColor("#334155"))
            }
            background = cardBg
            tag = "statusCardContainer"
        }

        val statusSummaryText = TextView(this).apply {
            val a11yEnabled = isAccessibilityServiceEnabled(this@KeyflowOverlayService)
            val paused = KeyflowAccessibilityService.isPaused
            val summaryStatus = when {
                !a11yEnabled -> "OS Access: Disabled"
                paused -> "Capture: Paused (Banking Mode)"
                else -> "Capture: Active (Monitoring)"
            }
            val summaryColor = when {
                !a11yEnabled -> Color.parseColor("#EF4444")
                paused -> Color.parseColor("#F59E0B")
                else -> Color.parseColor("#34D399")
            }
            text = summaryStatus
            setTextColor(summaryColor)
            textSize = 12f
            typeface = Typeface.DEFAULT_BOLD
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            tag = "statusSummaryText"
        }
        statusContainer.addView(statusSummaryText)
        panel.addView(statusContainer)

        // CONTROL 1: "Pause Typing Capture" Toggle (Internal isPaused flag)
        val pauseToggleRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = dpToPx(4f)
            }
            setPadding(dpToPx(8f), dpToPx(6f), dpToPx(8f), dpToPx(6f))
            val rowBg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dpToPx(8f).toFloat()
                setColor(Color.parseColor("#131D2E"))
            }
            background = rowBg
        }

        val pauseLabelCol = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }

        val pauseToggleLabel = TextView(this).apply {
            text = "Pause Typing Capture"
            setTextColor(Color.parseColor("#E2E8F0"))
            textSize = 12f
            typeface = Typeface.DEFAULT_BOLD
        }
        pauseLabelCol.addView(pauseToggleLabel)

        val pauseSubLabel = TextView(this).apply {
            text = "Quick pause for banking apps"
            setTextColor(Color.parseColor("#94A3B8"))
            textSize = 10f
        }
        pauseLabelCol.addView(pauseSubLabel)
        pauseToggleRow.addView(pauseLabelCol)

        val pauseSwitch = Switch(this).apply {
            isChecked = KeyflowAccessibilityService.isPaused
            tag = "pauseSwitch"
            setOnCheckedChangeListener { _, isChecked ->
                KeyflowAccessibilityService.isPaused = isChecked
                KeyflowAccessibilityService.instance?.updateForegroundNotification(isChecked)
                updateOverlayViews()

                // Notify Flutter plugin if listening
                KeyflowAccessibilityService.eventListener?.invoke(
                    mapOf(
                        "type" to "pause_changed",
                        "isPaused" to isChecked
                    )
                )
            }
        }
        pauseToggleRow.addView(pauseSwitch)
        panel.addView(pauseToggleRow)

        // CONTROL 2: "Accessibility Access" Toggle-Style Control (Android OS-level permission)
        val a11yToggleRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = dpToPx(6f)
            }
            setPadding(dpToPx(8f), dpToPx(6f), dpToPx(8f), dpToPx(6f))
            val rowBg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dpToPx(8f).toFloat()
                setColor(Color.parseColor("#131D2E"))
            }
            background = rowBg
        }

        val a11yLabelCol = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }

        val a11yStatusText = TextView(this).apply {
            val a11yEnabled = isAccessibilityServiceEnabled(this@KeyflowOverlayService)
            text = if (a11yEnabled) "Accessibility Access: ON" else "Accessibility Access: OFF"
            setTextColor(if (a11yEnabled) Color.parseColor("#34D399") else Color.parseColor("#F59E0B"))
            textSize = 12f
            typeface = Typeface.DEFAULT_BOLD
            tag = "a11yStatusText"
        }
        a11yLabelCol.addView(a11yStatusText)

        val a11ySubLabel = TextView(this).apply {
            text = "Tap to manage in Android Settings"
            setTextColor(Color.parseColor("#94A3B8"))
            textSize = 10f
        }
        a11yLabelCol.addView(a11ySubLabel)
        a11yToggleRow.addView(a11yLabelCol)

        val a11ySwitch = Switch(this).apply {
            val a11yEnabled = isAccessibilityServiceEnabled(this@KeyflowOverlayService)
            isChecked = a11yEnabled
            tag = "a11ySwitch"
        }
        a11yToggleRow.addView(a11ySwitch)

        // Action handler when tapping the Accessibility Access row / switch
        val handleA11yClick: (View) -> Unit = {
            val currentlyEnabled = isAccessibilityServiceEnabled(this@KeyflowOverlayService)
            val instructionMsg = if (currentlyEnabled) {
                "Tap KeyFlow in the list, then toggle it off"
            } else {
                "Tap KeyFlow in the list, then toggle it on"
            }
            Toast.makeText(this@KeyflowOverlayService, instructionMsg, Toast.LENGTH_LONG).show()

            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            collapsePanel()
        }

        a11yToggleRow.setOnClickListener(handleA11yClick)
        a11ySwitch.setOnClickListener(handleA11yClick)
        panel.addView(a11yToggleRow)

        // Action Buttons Row: [Open KeyFlow App] [Hide]
        val actionsRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = dpToPx(10f)
            }
        }

        val openAppBtn = Button(this).apply {
            text = "Open KeyFlow"
            setTextColor(Color.WHITE)
            textSize = 11f
            val btnBg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dpToPx(8f).toFloat()
                setColor(Color.parseColor("#2563EB"))
            }
            background = btnBg
            val lp = LinearLayout.LayoutParams(0, dpToPx(36f), 1f).apply {
                rightMargin = dpToPx(6f)
            }
            layoutParams = lp
            setOnClickListener {
                val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                }
                if (launchIntent != null) {
                    startActivity(launchIntent)
                    collapsePanel()
                }
            }
        }
        actionsRow.addView(openAppBtn)

        val hideBtn = Button(this).apply {
            text = "Hide"
            setTextColor(Color.parseColor("#94A3B8"))
            textSize = 11f
            val btnBg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dpToPx(8f).toFloat()
                setColor(Color.parseColor("#1E293B"))
                setStroke(dpToPx(0.8f), Color.parseColor("#334155"))
            }
            background = btnBg
            val lp = LinearLayout.LayoutParams(dpToPx(56f), dpToPx(36f))
            layoutParams = lp
            setOnClickListener {
                stop(this@KeyflowOverlayService)
            }
        }
        actionsRow.addView(hideBtn)
        panel.addView(actionsRow)

        return panel
    }

    private fun expandPanel() {
        isExpanded = true
        bubbleView?.visibility = View.GONE
        panelView?.visibility = View.VISIBLE
        updateOverlayViews()
    }

    private fun collapsePanel() {
        isExpanded = false
        panelView?.visibility = View.GONE
        bubbleView?.visibility = View.VISIBLE
        updateOverlayViews()
    }

    fun updateOverlayViews() {
        val paused = KeyflowAccessibilityService.isPaused
        val a11yEnabled = isAccessibilityServiceEnabled(this)

        // Update bubble dot: green if active, amber if paused, red if accessibility is off at OS level
        val dot = bubbleView?.findViewWithTag<View>("statusDot")
        val dotColor = when {
            !a11yEnabled -> Color.parseColor("#EF4444")
            paused -> Color.parseColor("#F59E0B")
            else -> Color.parseColor("#10B981")
        }
        (dot?.background as? GradientDrawable)?.setColor(dotColor)

        // Update panel status summary text
        val summaryText = panelView?.findViewWithTag<TextView>("statusSummaryText")
        val summaryStatus = when {
            !a11yEnabled -> "OS Access: Disabled"
            paused -> "Capture: Paused (Banking Mode)"
            else -> "Capture: Active (Monitoring)"
        }
        val summaryColor = when {
            !a11yEnabled -> Color.parseColor("#EF4444")
            paused -> Color.parseColor("#F59E0B")
            else -> Color.parseColor("#34D399")
        }
        summaryText?.text = summaryStatus
        summaryText?.setTextColor(summaryColor)

        // Update pause switch
        val pauseSwitch = panelView?.findViewWithTag<Switch>("pauseSwitch")
        if (pauseSwitch?.isChecked != paused) {
            pauseSwitch?.isChecked = paused
        }

        // Update accessibility toggle & status label
        val a11yStatusText = panelView?.findViewWithTag<TextView>("a11yStatusText")
        a11yStatusText?.text = if (a11yEnabled) "Accessibility Access: ON" else "Accessibility Access: OFF"
        a11yStatusText?.setTextColor(if (a11yEnabled) Color.parseColor("#34D399") else Color.parseColor("#F59E0B"))

        val a11ySwitch = panelView?.findViewWithTag<Switch>("a11ySwitch")
        a11ySwitch?.isChecked = a11yEnabled
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        android.util.Log.i("KeyflowOverlay", "onTaskRemoved: maintaining active overlay view")
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        instance = null
        if (rootContainer != null) {
            try {
                windowManager.removeView(rootContainer)
            } catch (e: Exception) {
                android.util.Log.e("KeyflowOverlay", "Error removing overlay view: $e")
            }
        }
    }
}

