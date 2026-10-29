package app.saff.saff_alarm

import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Bridges Dart to the native alarm. Everything that rings runs without this class; it only feeds
 * the schedule and reads state. Errors use the catalog codes from `contracts/errors.json`.
 */
class SaffAlarmPlugin : FlutterPlugin, AlarmHostApi {
    private var context: Context? = null
    private var flutterApi: AlarmFlutterApi? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        AlarmHostApi.setUp(binding.binaryMessenger, this)
        flutterApi = AlarmFlutterApi(binding.binaryMessenger).also { WakeEngine.flutterApis.add(it) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        AlarmHostApi.setUp(binding.binaryMessenger, null)
        flutterApi?.let { WakeEngine.flutterApis.remove(it) }
        flutterApi = null
        context = null
    }

    private val ctx: Context get() = context ?: throw FlutterError("UNKNOWN", "Plugin detached", null)

    override fun setSchedule(occurrences: List<NativeOccurrence>) {
        ScheduleStore.setSchedule(ctx, occurrences)
        AlarmScheduler.scheduleNext(ctx)
    }

    override fun getSchedule(): List<NativeOccurrence> = ScheduleStore.schedule(ctx)

    override fun ringNow(reason: RingReason, occurrenceId: String?, message: String?) {
        if (reason == RingReason.TEST && message == "force-fallback") {
            ScheduleStore.setForceFallback(ctx, true)
        } else if (reason == RingReason.TEST && message == "clear-fallback") {
            ScheduleStore.setForceFallback(ctx, false)
            return
        }
        val i = Intent(ctx, RingingService::class.java)
            .setAction(RingingService.ACTION_RING)
            .putExtra(RingingService.EXTRA_OCCURRENCE_ID, occurrenceId ?: "manual")
            .putExtra(RingingService.EXTRA_REASON, reason.raw)
            .putExtra(RingingService.EXTRA_MESSAGE, message)
            .putExtra(RingingService.EXTRA_FIRED_AT, System.currentTimeMillis())
        try {
            ContextCompat.startForegroundService(ctx, i)
        } catch (e: Exception) {
            throw FlutterError("ALARM_PERMISSION_MISSING", e.message, null)
        }
    }

    override fun stopRinging(reason: StopReason) {
        RingingService.stop(ctx, reason)
    }

    override fun snooze(minutes: Long) {
        val active = ScheduleStore.active(ctx)
        val base = active?.let { ScheduleStore.find(ctx, it.occurrenceId) }
        val at = System.currentTimeMillis() + minutes * 60_000L
        val snoozeOcc = NativeOccurrence(
            id = "snooze:" + (active?.occurrenceId ?: "manual"),
            ringAtEpochMs = at,
            alarmName = active?.alarmName ?: "Alarm",
            soundUri = base?.soundUri,
            vibrate = base?.vibrate ?: true,
            rampMs = base?.rampMs ?: 30_000L,
            saffId = active?.saffId ?: "",
        )
        ScheduleStore.setSnoozes(
            ctx,
            ScheduleStore.snoozes(ctx).filter { it.id != snoozeOcc.id } + snoozeOcc,
        )
        RingingService.stop(ctx, StopReason.SNOOZED)
        AlarmScheduler.scheduleNext(ctx)
    }

    override fun getReadiness(): ReadinessReport {
        val c = ctx
        val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val nm = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val pm = c.getSystemService(Context.POWER_SERVICE) as PowerManager
        val exact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) am.canScheduleExactAlarms() else true
        val fsi = if (Build.VERSION.SDK_INT >= 34) nm.canUseFullScreenIntent() else true
        return ReadinessReport(
            exactAlarmAllowed = exact,
            fullScreenIntentAllowed = fsi,
            notificationsAllowed = nm.areNotificationsEnabled(),
            batteryOptimisationIgnored = pm.isIgnoringBatteryOptimizations(c.packageName),
            manufacturer = Build.MANUFACTURER.lowercase(),
        )
    }

    override fun openSettings(item: ReadinessItem) {
        val c = ctx
        val pkg = Uri.parse("package:${c.packageName}")
        val intent = when (item) {
            ReadinessItem.EXACT_ALARM ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, pkg)
                } else {
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkg)
                }
            ReadinessItem.FULL_SCREEN_INTENT ->
                if (Build.VERSION.SDK_INT >= 34) {
                    Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, pkg)
                } else {
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkg)
                }
            ReadinessItem.NOTIFICATIONS ->
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, c.packageName)
            ReadinessItem.BATTERY_OPTIMISATION ->
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, pkg)
        }.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            c.startActivity(intent)
        } catch (_: Exception) {
            c.startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkg).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }

    override fun scheduleTestAlarm(secondsFromNow: Long) {
        val at = System.currentTimeMillis() + secondsFromNow * 1000L
        val occ = NativeOccurrence(
            id = "test:$at",
            ringAtEpochMs = at,
            alarmName = "Test alarm",
            soundUri = null,
            vibrate = true,
            rampMs = 10_000L,
            saffId = "",
        )
        ScheduleStore.setSnoozes(ctx, ScheduleStore.snoozes(ctx) + occ)
        AlarmScheduler.scheduleNext(ctx)
    }

    override fun drainRingLog(): List<RingLogEntry> = ScheduleStore.drainLog(ctx)

    override fun getActiveRing(): ActiveRing? = ScheduleStore.active(ctx)

    override fun getTimezone(): String = java.util.TimeZone.getDefault().id

    override fun reportWakeReady() {
        if (WakeEngine.readyAtElapsedMs == 0L) {
            WakeEngine.readyAtElapsedMs = android.os.SystemClock.elapsedRealtime()
        }
    }
}
