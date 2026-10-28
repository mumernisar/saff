package app.saff.saff_alarm

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextClock
import android.widget.TextView

/**
 * Plain native alarm screen used only when Flutter fails: time, alarm name, a hold-to-stop
 * button and "Open Saff". No Flutter, no network.
 */
class NativeFallbackActivity : Activity() {
    private var holdStarted = 0L

    @Suppress("DEPRECATION")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        val name = ScheduleStore.active(this)?.alarmName ?: "Alarm"
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#0F1524"))
            setPadding(48, 48, 48, 48)
        }
        root.addView(TextClock(this).apply {
            format12Hour = "h:mm"
            format24Hour = "HH:mm"
            textSize = 72f
            setTextColor(Color.parseColor("#EEF1F6"))
            setTypeface(typeface, Typeface.BOLD)
            gravity = Gravity.CENTER
        })
        root.addView(TextView(this).apply {
            text = name
            textSize = 22f
            setTextColor(Color.parseColor("#F2B33D"))
            gravity = Gravity.CENTER
            setPadding(0, 8, 0, 64)
        })
        val stop = Button(this).apply {
            text = "Hold to stop alarm"
            textSize = 18f
            setOnTouchListener { v, e ->
                when (e.action) {
                    MotionEvent.ACTION_DOWN -> {
                        holdStarted = e.eventTime
                        v.postDelayed(holdCheck, HOLD_MS)
                    }
                    MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> v.removeCallbacks(holdCheck)
                }
                true
            }
        }
        holdView = stop
        root.addView(stop, LinearLayout.LayoutParams(-1, 160))
        root.addView(Button(this).apply {
            text = "Open Saff"
            setOnClickListener { openApp() }
        }, LinearLayout.LayoutParams(-1, -2).apply { topMargin = 32 })
        setContentView(root)
    }

    private var holdView: View? = null

    private val holdCheck = Runnable {
        RingingService.stop(this, StopReason.DISMISSED)
        finish()
    }

    private fun openApp() {
        RingingService.stop(this, StopReason.DISMISSED)
        packageManager.getLaunchIntentForPackage(packageName)?.let {
            startActivity(it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
        finish()
    }

    companion object {
        private const val HOLD_MS = 600L
    }
}
