package app.saff.saff_alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent

/**
 * Sets exactly one `setAlarmClock` alarm: the next occurrence. When it fires, the receiver asks
 * for the following one. Works from the stored list, so it needs no Dart.
 */
object AlarmScheduler {
    /** An alarm up to this late (e.g. phone was off) still rings right away. */
    private const val LATE_GRACE_MS = 10 * 60 * 1000L
    private const val REQUEST_CODE = 4711

    /** Schedules the next upcoming occurrence from schedule + snoozes. */
    fun scheduleNext(context: Context, nowMs: Long = System.currentTimeMillis()) {
        val all = (ScheduleStore.schedule(context) + ScheduleStore.snoozes(context))
        val fired = ScheduleStore.firedIds(context).toSet()
        val next = all.filter { it.ringAtEpochMs >= nowMs - LATE_GRACE_MS && it.id !in fired }
            .minByOrNull { it.ringAtEpochMs }
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = ringIntent(context, next)
        if (next == null) {
            am.cancel(pi)
            return
        }
        val at = maxOf(next.ringAtEpochMs, nowMs + 500)
        am.setAlarmClock(AlarmManager.AlarmClockInfo(at, showIntent(context)), pi)
    }

    private fun ringIntent(context: Context, occ: NativeOccurrence?): PendingIntent {
        // The occurrence travels inside the intent, so ringing never depends on
        // the stored schedule still holding it (the app may rewrite it any time).
        val intent = Intent(context, AlarmReceiver::class.java)
            .setAction(AlarmReceiver.ACTION_FIRE)
            .putExtra(AlarmReceiver.EXTRA_OCCURRENCE_ID, occ?.id)
            .putExtra(AlarmReceiver.EXTRA_NAME, occ?.alarmName)
            .putExtra(AlarmReceiver.EXTRA_SAFF_ID, occ?.saffId)
            .putExtra(AlarmReceiver.EXTRA_RAMP_MS, occ?.rampMs ?: 30_000L)
            .putExtra(AlarmReceiver.EXTRA_SOUND, occ?.soundUri)
            .putExtra(AlarmReceiver.EXTRA_VIBRATE, occ?.vibrate ?: true)
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun showIntent(context: Context): PendingIntent {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent()
        return PendingIntent.getActivity(
            context,
            REQUEST_CODE + 1,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /** Drops snoozes and past occurrences that have rung. */
    fun prune(context: Context, firedId: String, nowMs: Long) {
        ScheduleStore.setSnoozes(
            context,
            ScheduleStore.snoozes(context).filter { it.id != firedId && it.ringAtEpochMs > nowMs },
        )
        ScheduleStore.setSchedule(
            context,
            ScheduleStore.schedule(context).filter { it.id != firedId && it.ringAtEpochMs > nowMs },
        )
    }
}
