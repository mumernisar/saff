import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_alarm/saff_alarm.dart';
import 'package:saff_app/di/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _doneKey = 'onboarding_done';

/// Whether the user finished (or skipped) onboarding on this phone.
class OnboardedNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async =>
      (await SharedPreferences.getInstance()).getBool(_doneKey) ?? false;

  /// Marks onboarding done.
  Future<void> finish() async {
    await (await SharedPreferences.getInstance()).setBool(_doneKey, true);
    state = const AsyncData(true);
  }
}

/// Provider of [OnboardedNotifier].
final onboardedProvider = AsyncNotifierProvider<OnboardedNotifier, bool>(
  OnboardedNotifier.new,
);

/// One brand's guide from `assets/oem_guides.json`.
class OemGuide {
  /// Creates a guide.
  const OemGuide(this.title, this.steps);

  /// Heading.
  final String title;

  /// Ordered steps.
  final List<String> steps;
}

/// State of the permissions walkthrough.
class OnboardingState {
  /// Creates the state.
  const OnboardingState({this.readiness, this.guide});

  /// Latest readiness.
  final ReadinessReport? readiness;

  /// The guide for this phone's brand.
  final OemGuide? guide;
}

/// Permissions walkthrough (`docs/PRODUCT.md` §13, `docs/ALARM.md` §7).
class OnboardingViewModel extends AsyncNotifier<OnboardingState> {
  @override
  Future<OnboardingState> build() => _load();

  Future<OnboardingState> _load() async {
    final readiness = (await ref.read(alarmRepositoryProvider).readiness())
        .getOrNull();
    final raw = await rootBundle.loadString('assets/oem_guides.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final brand = readiness?.manufacturer ?? '';
    final key = json.keys.firstWhere(
      (k) => !k.startsWith('_') && k != 'default' && brand.contains(k),
      orElse: () => brand.contains('realme') || brand.contains('oneplus')
          ? 'oppo'
          : brand.contains('poco') || brand.contains('redmi')
          ? 'xiaomi'
          : 'default',
    );
    final g = json[key] as Map<String, dynamic>;
    return OnboardingState(
      readiness: readiness,
      guide: OemGuide(
        g['title'] as String,
        (g['steps'] as List).cast<String>(),
      ),
    );
  }

  /// Re-reads permissions (after returning from system settings).
  Future<void> refresh() async => state = AsyncData(await _load());

  /// Asks for notifications (runtime prompt on Android 13+).
  Future<void> allowNotifications() async {
    await FirebaseMessaging.instance.requestPermission();
    await refresh();
  }

  /// Opens the system screen for [item].
  Future<void> open(ReadinessItem item) async {
    await ref.read(alarmRepositoryProvider).openSettings(item);
  }

  /// Rings the real alarm in 10 s.
  Future<void> testAlarm() =>
      ref.read(alarmRepositoryProvider).scheduleTest(10);
}

/// Provider of [OnboardingViewModel].
final onboardingProvider =
    AsyncNotifierProvider.autoDispose<OnboardingViewModel, OnboardingState>(
      OnboardingViewModel.new,
    );
