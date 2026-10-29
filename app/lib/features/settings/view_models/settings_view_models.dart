import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/features/auth/view_models/auth_view_model.dart';
import 'package:saff_core/saff_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeKey = 'theme_mode';

/// The user's theme choice (system / light / dark), kept on this phone.
class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final v = (await SharedPreferences.getInstance()).getString(_themeKey);
    return ThemeMode.values.firstWhere(
      (m) => m.name == v,
      orElse: () => ThemeMode.system,
    );
  }

  /// Saves [mode].
  Future<void> set(ThemeMode mode) async {
    await (await SharedPreferences.getInstance()).setString(
      _themeKey,
      mode.name,
    );
    state = AsyncData(mode);
  }
}

/// Provider of the theme mode.
final themeModeProvider = AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// Notification category switches.
final notificationSettingsProvider = StreamProvider<Map<String, bool>>((ref) {
  final uid = ref.watch(uidProvider).value;
  if (uid == null) return Stream.value(const {});
  return ref.watch(saffRepositoryProvider).watchNotificationSettings(uid);
});

/// Settings actions.
class SettingsActions extends Notifier<ActionState> {
  @override
  ActionState build() => const ActionState();

  /// Flips a notification category.
  Future<void> setNotification(String key, {required bool on}) async {
    final uid = ref.read(uidProvider).value;
    if (uid == null) return;
    final r = await ref
        .read(saffRepositoryProvider)
        .setNotification(uid, key, on: on);
    state = ActionState(failure: r is Err<void> ? r.failure : null);
  }

  /// Sends feedback.
  Future<bool> feedback(String text, {String? details}) async {
    final uid = ref.read(uidProvider).value;
    if (uid == null || text.trim().isEmpty) return false;
    state = const ActionState(running: true);
    final r = await ref
        .read(saffRepositoryProvider)
        .sendFeedback(uid, text.trim(), details: details);
    state = ActionState(failure: r is Err<void> ? r.failure : null);
    return r is Ok<void>;
  }
}

/// Provider of [SettingsActions].
final settingsActionsProvider = NotifierProvider<SettingsActions, ActionState>(
  SettingsActions.new,
);
