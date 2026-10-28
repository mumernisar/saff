package app.saff.saff_alarm

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

/**
 * Hosts the pre-warmed wake engine over the lock screen. If the engine is not ready within
 * [ENGINE_TIMEOUT_MS] (or was never started), the native fallback takes over.
 */
class AlarmActivity : FlutterActivity() {
    private val handler = Handler(Looper.getMainLooper())

    override fun getCachedEngineId(): String? =
        if (ScheduleStore.forceFallback(this)) null else WakeEngine.ENGINE_ID

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        usedFallback = false
        showOverLockScreen()
        if (ScheduleStore.forceFallback(this) || !engineAvailable()) {
            goFallback()
            super.onCreate(null)
            return
        }
        super.onCreate(savedInstanceState)
        handler.postDelayed({ if (!WakeEngine.isReady) goFallback() }, ENGINE_TIMEOUT_MS)
    }

    private fun engineAvailable(): Boolean =
        io.flutter.embedding.engine.FlutterEngineCache.getInstance().get(WakeEngine.ENGINE_ID) != null ||
            WakeEngine.ensure(this) != null

    private fun goFallback() {
        usedFallback = true
        startActivity(
            Intent(this, NativeFallbackActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
        )
        finish()
    }

    @Suppress("DEPRECATION")
    private fun showOverLockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            (getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager)
                ?.requestDismissKeyguard(this, null)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD,
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    companion object {
        private const val ENGINE_TIMEOUT_MS = 5000L

        @Volatile
        var usedFallback: Boolean = false
    }
}
