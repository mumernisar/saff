package app.saff.saff_alarm

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * Foreground service that rings: sound on the alarm stream with a volume ramp, vibration, a
 * full-screen notification to [AlarmActivity] and the wake-engine pre-warm. Every step after the
 * sound starts is wrapped so a failure can't stop the sound.
 */
class RingingService : Service() {
    private val main = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var rampTask: Runnable? = null
    private var autoSilence: Runnable? = null
    private var session: Session? = null

    private class Session(
        val occurrenceId: String,
        val firedAt: Long,
        val delayMs: Long,
        val startElapsed: Long = SystemClock.elapsedRealtime(),
        var soundStartMs: Long = 0,
        var error: String? = null,
    )

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> stopRing(StopReason.ofRaw(intent.getIntExtra(EXTRA_STOP_REASON, 0)) ?: StopReason.DISMISSED)
            else -> ring(intent)
        }
        return START_NOT_STICKY
    }

    private fun ring(intent: Intent?) {
        val t0 = SystemClock.elapsedRealtime()
        val id = intent?.getStringExtra(EXTRA_OCCURRENCE_ID) ?: "unknown"
        val reason = RingReason.ofRaw(intent?.getIntExtra(EXTRA_REASON, 0) ?: 0) ?: RingReason.SCHEDULED
        val message = intent?.getStringExtra(EXTRA_MESSAGE)
        val firedAt = intent?.getLongExtra(EXTRA_FIRED_AT, System.currentTimeMillis())
            ?: System.currentTimeMillis()
        val occ = ScheduleStore.find(this, id)
        val name = occ?.alarmName ?: "Alarm"
        val saffId = occ?.saffId ?: ""
        val rampMs = occ?.rampMs ?: 30_000L
        finishSession()

        try {
            startForegroundCompat(buildNotification(name, message ?: "Time to wake up", loud = true))
        } catch (e: Throwable) {
            // Can't be a foreground service; keep going, the sound may still play.
            session?.error = "foreground:${e.javaClass.simpleName}"
        }
        val delay = maxOf(0L, System.currentTimeMillis() - (occ?.ringAtEpochMs ?: firedAt))
        session = Session(id, firedAt, delay)
        acquireWakeLock()
        runCatching { startSound(occ?.soundUri, rampMs) }.onFailure {
            session?.error = "sound:${it.javaClass.simpleName}"
            runCatching { startSound(null, rampMs) }
        }
        session?.soundStartMs = SystemClock.elapsedRealtime() - t0
        if (occ?.vibrate != false) runCatching { startVibration() }

        val active = ActiveRing(
            occurrenceId = id,
            alarmName = name,
            saffId = saffId,
            ringStartedElapsedMs = SystemClock.elapsedRealtime(),
            rampMs = rampMs,
            reason = reason,
        )
        ScheduleStore.setActive(this, active)
        if (occ != null && reason == RingReason.SCHEDULED) {
            runCatching { AlarmScheduler.prune(this, id, System.currentTimeMillis() - 60_000) }
        }

        runCatching {
            if (!ScheduleStore.forceFallback(this)) WakeEngine.ensure(this)
        }
        runCatching { WakeEngine.flutterApis.forEach { it.onRingStarted(active) {} } }
        runCatching { launchActivity() }

        autoSilence = Runnable { stopRing(StopReason.DISMISSED, auto = true) }
        main.postDelayed(autoSilence!!, AUTO_SILENCE_MS)
    }

    private fun startSound(uriString: String?, rampMs: Long) {
        stopSound()
        val uri: Uri = uriString?.let { Uri.parse(it) }
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        val mp = MediaPlayer()
        mp.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build(),
        )
        mp.setDataSource(this, uri)
        mp.isLooping = true
        mp.setVolume(START_VOLUME, START_VOLUME)
        mp.prepare()
        mp.start()
        player = mp
        val begun = SystemClock.elapsedRealtime()
        val task = object : Runnable {
            override fun run() {
                val p = player ?: return
                val f = ((SystemClock.elapsedRealtime() - begun).toFloat() / rampMs.coerceAtLeast(1)).coerceIn(0f, 1f)
                val v = START_VOLUME + (1f - START_VOLUME) * f
                runCatching { p.setVolume(v, v) }
                if (f < 1f) main.postDelayed(this, 250)
            }
        }
        rampTask = task
        main.post(task)
    }

    private fun stopSound() {
        rampTask?.let { main.removeCallbacks(it) }
        rampTask = null
        player?.let { runCatching { it.stop() }; runCatching { it.release() } }
        player = null
    }

    @Suppress("DEPRECATION")
    private fun vibrator(): Vibrator? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
        } else {
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }

    @Suppress("DEPRECATION")
    private fun startVibration() {
        val v = vibrator() ?: return
        if (!v.hasVibrator()) return
        val pattern = longArrayOf(0, 600, 500)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            v.vibrate(VibrationEffect.createWaveform(pattern, 0), alarmAttributes())
        } else {
            v.vibrate(pattern, 0)
        }
    }

    private fun alarmAttributes() = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ALARM)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    private fun stopVibration() {
        runCatching { vibrator()?.cancel() }
    }

    private fun acquireWakeLock() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "saff:ring").apply {
            acquire(WAKE_LOCK_MS)
        }
    }

    private fun launchActivity() {
        val i = activityIntent()
        startActivity(i)
    }

    private fun activityIntent() = Intent(this, AlarmActivity::class.java).addFlags(
        Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP,
    )

    private fun channel(loud: Boolean): String {
        val id = if (loud) CHANNEL_RING else CHANNEL_QUIET
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java)
            if (nm.getNotificationChannel(id) == null) {
                val c = NotificationChannel(
                    id,
                    if (loud) "Alarm" else "Round in progress",
                    if (loud) NotificationManager.IMPORTANCE_HIGH else NotificationManager.IMPORTANCE_LOW,
                )
                c.setSound(null, null)
                c.enableVibration(false)
                c.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                nm.createNotificationChannel(c)
            }
        }
        return id
    }

    @Suppress("DEPRECATION")
    private fun buildNotification(title: String, text: String, loud: Boolean): Notification {
        val content = PendingIntent.getActivity(
            this, 1, activityIntent(),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channel(loud))
        } else {
            Notification.Builder(this)
        }
        b.setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_ALARM)
            .setContentIntent(content)
        if (loud) b.setFullScreenIntent(content, true)
        return b.build()
    }

    private fun startForegroundCompat(n: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED)
        } else {
            startForeground(NOTIFICATION_ID, n)
        }
    }

    private fun stopRing(reason: StopReason, auto: Boolean = false) {
        stopSound()
        stopVibration()
        autoSilence?.let { main.removeCallbacks(it) }
        autoSilence = null
        runCatching { WakeEngine.flutterApis.forEach { it.onRingStopped(reason) {} } }
        if (reason == StopReason.STARTED && !auto) {
            // Round in progress: keep a quiet foreground notification so the idle guard can re-ring.
            runCatching {
                val nm = getSystemService(NotificationManager::class.java)
                nm.notify(NOTIFICATION_ID, buildNotification("Saff", "Round in progress", loud = false))
            }
            wakeLock?.let { if (it.isHeld) it.release() }
            finishSession()
            return
        }
        if (reason != StopReason.STARTED) ScheduleStore.setActive(this, null)
        finishSession()
        wakeLock?.let { if (it.isHeld) it.release() }
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun finishSession() {
        val s = session ?: return
        session = null
        val ready = WakeEngine.readyAtElapsedMs
        runCatching {
            ScheduleStore.appendLog(
                this,
                RingLogEntry(
                    occurrenceId = s.occurrenceId,
                    firedAtEpochMs = s.firedAt,
                    delayMs = s.delayMs,
                    soundStartMs = s.soundStartMs,
                    engineReadyMs = if (ready >= s.startElapsed) ready - s.startElapsed else -1,
                    usedFallback = AlarmActivity.usedFallback,
                    error = s.error,
                ),
            )
        }
    }

    override fun onDestroy() {
        stopSound()
        stopVibration()
        wakeLock?.let { if (it.isHeld) it.release() }
        super.onDestroy()
    }

    companion object {
        const val ACTION_RING = "app.saff.saff_alarm.RING"
        const val ACTION_STOP = "app.saff.saff_alarm.STOP"
        const val EXTRA_OCCURRENCE_ID = "occurrenceId"
        const val EXTRA_REASON = "reason"
        const val EXTRA_MESSAGE = "message"
        const val EXTRA_FIRED_AT = "firedAt"
        const val EXTRA_STOP_REASON = "stopReason"
        private const val CHANNEL_RING = "saff_alarm_ring"
        private const val CHANNEL_QUIET = "saff_alarm_quiet"
        private const val NOTIFICATION_ID = 7001
        private const val START_VOLUME = 0.1f
        private const val AUTO_SILENCE_MS = 30 * 60 * 1000L
        private const val WAKE_LOCK_MS = 10 * 60 * 1000L

        fun stop(context: Context, reason: StopReason) {
            context.startService(
                Intent(context, RingingService::class.java)
                    .setAction(ACTION_STOP)
                    .putExtra(EXTRA_STOP_REASON, reason.raw),
            )
        }
    }
}
