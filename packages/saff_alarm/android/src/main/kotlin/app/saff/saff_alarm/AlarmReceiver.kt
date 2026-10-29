package app.saff.saff_alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

/** Receives the alarm broadcast and starts the ringing service as fast as possible. */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_FIRE) return
        val now = System.currentTimeMillis()
        val id = intent.getStringExtra(EXTRA_OCCURRENCE_ID)
        if (id != null) {
            val svc = Intent(context, RingingService::class.java)
                .setAction(RingingService.ACTION_RING)
                .putExtra(RingingService.EXTRA_OCCURRENCE_ID, id)
                .putExtra(RingingService.EXTRA_REASON, RingReason.SCHEDULED.raw)
                .putExtra(RingingService.EXTRA_FIRED_AT, now)
                .putExtra(EXTRA_NAME, intent.getStringExtra(EXTRA_NAME))
                .putExtra(EXTRA_SAFF_ID, intent.getStringExtra(EXTRA_SAFF_ID))
                .putExtra(EXTRA_RAMP_MS, intent.getLongExtra(EXTRA_RAMP_MS, 30_000L))
                .putExtra(EXTRA_SOUND, intent.getStringExtra(EXTRA_SOUND))
                .putExtra(EXTRA_VIBRATE, intent.getBooleanExtra(EXTRA_VIBRATE, true))
            ContextCompat.startForegroundService(context, svc)
        }
        // The next occurrence is armed regardless of what happens to the ring.
        AlarmScheduler.scheduleNext(context, now + 1000)
    }

    companion object {
        const val ACTION_FIRE = "app.saff.saff_alarm.FIRE"
        const val EXTRA_OCCURRENCE_ID = "occurrenceId"
        const val EXTRA_NAME = "alarmName"
        const val EXTRA_SAFF_ID = "saffId"
        const val EXTRA_RAMP_MS = "rampMs"
        const val EXTRA_SOUND = "soundUri"
        const val EXTRA_VIBRATE = "vibrate"
    }
}
