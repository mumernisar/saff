package app.saff.saff_alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Re-arms the next alarm after boot, update, or time / timezone changes. */
class RescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        AlarmScheduler.scheduleNext(context)
    }
}
