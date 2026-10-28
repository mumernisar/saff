package app.saff.saff_alarm

import android.content.Context
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/** Owns the pre-warmed Flutter engine that runs `wakeMain` for the alarm activity. */
object WakeEngine {
    const val ENGINE_ID = "saff_wake_engine"
    private const val LIBRARY = "package:saff_app/wake_main.dart"
    private const val ENTRYPOINT = "wakeMain"

    @Volatile
    var readyAtElapsedMs: Long = 0L

    /** Dart-side API instances, one per engine the plugin is attached to. */
    val flutterApis = java.util.concurrent.CopyOnWriteArrayList<AlarmFlutterApi>()

    val isReady: Boolean get() = readyAtElapsedMs > 0L

    /** Must run on the main thread. Starts the engine once; returns it. */
    fun ensure(context: Context): FlutterEngine? {
        FlutterEngineCache.getInstance().get(ENGINE_ID)?.let { return it }
        return try {
            val app = context.applicationContext
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(app)
            loader.ensureInitializationComplete(app, null)
            val engine = FlutterEngine(app)
            readyAtElapsedMs = 0L
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(loader.findAppBundlePath(), LIBRARY, ENTRYPOINT),
            )
            FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
            engine
        } catch (_: Throwable) {
            null
        }
    }

    /** Throws the engine away (after a crash) so the next ring builds a fresh one. */
    fun reset() {
        FlutterEngineCache.getInstance().get(ENGINE_ID)?.destroy()
        FlutterEngineCache.getInstance().remove(ENGINE_ID)
        readyAtElapsedMs = 0L
    }
}
