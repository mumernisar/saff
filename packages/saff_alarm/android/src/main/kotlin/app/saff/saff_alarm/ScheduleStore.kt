package app.saff.saff_alarm

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/**
 * Everything the native side needs to ring without the app process: the schedule, snoozes, the
 * active ring and the ring log. Lives in device-protected storage so it is readable before the
 * first unlock after a reboot (direct boot).
 */
object ScheduleStore {
    private const val FILE = "saff_alarm_store"
    private const val KEY_SCHEDULE = "schedule"
    private const val KEY_SNOOZES = "snoozes"
    private const val KEY_LOG = "ring_log"
    private const val KEY_ACTIVE = "active_ring"
    private const val KEY_FORCE_FALLBACK = "force_fallback"
    private const val KEY_FIRED = "fired_ids"
    private const val LOG_CAP = 100

    private fun prefs(context: Context): SharedPreferences {
        val base = context.applicationContext
        val protected = base.createDeviceProtectedStorageContext()
        // Existing credential-protected data (none yet) would be migrated here.
        return protected.getSharedPreferences(FILE, Context.MODE_PRIVATE)
    }

    @Synchronized
    fun setSchedule(context: Context, list: List<NativeOccurrence>) {
        val fired = firedIds(context).toSet()
        prefs(context).edit()
            .putString(KEY_SCHEDULE, toJson(list.filter { it.id !in fired }).toString())
            .apply()
    }

    @Synchronized
    fun schedule(context: Context): List<NativeOccurrence> =
        fromJson(prefs(context).getString(KEY_SCHEDULE, null))

    @Synchronized
    fun snoozes(context: Context): List<NativeOccurrence> =
        fromJson(prefs(context).getString(KEY_SNOOZES, null))

    @Synchronized
    fun setSnoozes(context: Context, list: List<NativeOccurrence>) {
        prefs(context).edit().putString(KEY_SNOOZES, toJson(list).toString()).apply()
    }

    /** Looks an occurrence up in the schedule or the snoozes. */
    fun find(context: Context, id: String): NativeOccurrence? =
        (schedule(context) + snoozes(context)).firstOrNull { it.id == id }

    /** Remembers that [id] rang, so a schedule rewrite can never ring it twice. */
    @Synchronized
    fun markFired(context: Context, id: String) {
        val ids = firedIds(context).filter { it != id } + id
        prefs(context).edit().putString(KEY_FIRED, JSONArray(ids.takeLast(100)).toString()).apply()
    }

    /** Ids of occurrences that already rang (newest last). */
    @Synchronized
    fun firedIds(context: Context): List<String> = try {
        val arr = JSONArray(prefs(context).getString(KEY_FIRED, "[]"))
        (0 until arr.length()).map { arr.getString(it) }
    } catch (_: Exception) {
        emptyList()
    }

    @Synchronized
    fun setActive(context: Context, ring: ActiveRing?) {
        val e = prefs(context).edit()
        if (ring == null) e.remove(KEY_ACTIVE) else e.putString(KEY_ACTIVE, ringToJson(ring).toString())
        e.apply()
    }

    @Synchronized
    fun active(context: Context): ActiveRing? {
        val raw = prefs(context).getString(KEY_ACTIVE, null) ?: return null
        return try {
            val o = JSONObject(raw)
            ActiveRing(
                occurrenceId = o.getString("occurrenceId"),
                alarmName = o.getString("alarmName"),
                saffId = o.getString("saffId"),
                ringStartedElapsedMs = o.getLong("ringStartedElapsedMs"),
                rampMs = o.getLong("rampMs"),
                reason = RingReason.ofRaw(o.getInt("reason")) ?: RingReason.SCHEDULED,
                nowElapsedMs = android.os.SystemClock.elapsedRealtime(),
            )
        } catch (_: Exception) {
            null
        }
    }

    @Synchronized
    fun appendLog(context: Context, entry: RingLogEntry) {
        val arr = try {
            JSONArray(prefs(context).getString(KEY_LOG, "[]"))
        } catch (_: Exception) {
            JSONArray()
        }
        val o = JSONObject()
            .put("occurrenceId", entry.occurrenceId)
            .put("firedAtEpochMs", entry.firedAtEpochMs)
            .put("delayMs", entry.delayMs)
            .put("soundStartMs", entry.soundStartMs)
            .put("engineReadyMs", entry.engineReadyMs)
            .put("usedFallback", entry.usedFallback)
            .put("error", entry.error ?: JSONObject.NULL)
        arr.put(o)
        val trimmed = JSONArray()
        for (i in maxOf(0, arr.length() - LOG_CAP) until arr.length()) trimmed.put(arr.get(i))
        prefs(context).edit().putString(KEY_LOG, trimmed.toString()).apply()
    }

    @Synchronized
    fun drainLog(context: Context): List<RingLogEntry> {
        val raw = prefs(context).getString(KEY_LOG, "[]")
        prefs(context).edit().remove(KEY_LOG).apply()
        val arr = try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }
        return (0 until arr.length()).map {
            val o = arr.getJSONObject(it)
            RingLogEntry(
                occurrenceId = o.getString("occurrenceId"),
                firedAtEpochMs = o.getLong("firedAtEpochMs"),
                delayMs = o.getLong("delayMs"),
                soundStartMs = o.getLong("soundStartMs"),
                engineReadyMs = o.getLong("engineReadyMs"),
                usedFallback = o.getBoolean("usedFallback"),
                error = if (o.isNull("error")) null else o.getString("error"),
            )
        }
    }

    /** Debug switch (device checklist 8): makes the next ring skip the Flutter engine. */
    fun forceFallback(context: Context): Boolean =
        prefs(context).getBoolean(KEY_FORCE_FALLBACK, false)

    fun setForceFallback(context: Context, value: Boolean) {
        prefs(context).edit().putBoolean(KEY_FORCE_FALLBACK, value).apply()
    }

    private fun ringToJson(r: ActiveRing) = JSONObject()
        .put("occurrenceId", r.occurrenceId)
        .put("alarmName", r.alarmName)
        .put("saffId", r.saffId)
        .put("ringStartedElapsedMs", r.ringStartedElapsedMs)
        .put("rampMs", r.rampMs)
        .put("reason", r.reason.raw)

    private fun toJson(list: List<NativeOccurrence>): JSONArray {
        val arr = JSONArray()
        for (o in list) {
            arr.put(
                JSONObject()
                    .put("id", o.id)
                    .put("ringAtEpochMs", o.ringAtEpochMs)
                    .put("alarmName", o.alarmName)
                    .put("soundUri", o.soundUri ?: JSONObject.NULL)
                    .put("vibrate", o.vibrate)
                    .put("rampMs", o.rampMs)
                    .put("saffId", o.saffId),
            )
        }
        return arr
    }

    private fun fromJson(raw: String?): List<NativeOccurrence> {
        if (raw == null) return emptyList()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map {
                val o = arr.getJSONObject(it)
                NativeOccurrence(
                    id = o.getString("id"),
                    ringAtEpochMs = o.getLong("ringAtEpochMs"),
                    alarmName = o.getString("alarmName"),
                    soundUri = if (o.isNull("soundUri")) null else o.getString("soundUri"),
                    vibrate = o.getBoolean("vibrate"),
                    rampMs = o.getLong("rampMs"),
                    saffId = o.getString("saffId"),
                )
            }
        } catch (_: Exception) {
            emptyList()
        }
    }
}
