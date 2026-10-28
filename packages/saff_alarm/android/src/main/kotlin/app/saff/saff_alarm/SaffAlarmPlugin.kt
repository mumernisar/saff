package app.saff.saff_alarm

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Plugin shell. The alarm implementation and its Pigeon API arrive in the alarm stage
 * (docs/ALARM.md); nothing here may depend on the Flutter engine for ringing.
 */
class SaffAlarmPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) = Unit

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) = Unit
}
