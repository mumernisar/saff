import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/features/alarms/view_models/schedule_sync_view_model.dart';
import 'package:saff_app/features/alarms/views/reliability_view.dart';
import 'package:saff_app/features/auth/views/profile_setup_view.dart';
import 'package:saff_app/features/auth/views/welcome_view.dart';
import 'package:saff_app/features/chat/views/chat_view.dart';
import 'package:saff_app/features/learn/views/learn_view.dart';
import 'package:saff_app/features/onboarding/view_models/onboarding_view_model.dart';
import 'package:saff_app/features/onboarding/views/onboarding_view.dart';
import 'package:saff_app/features/plant/views/plant_view.dart';
import 'package:saff_app/features/saff/view_models/selected_saff.dart';
import 'package:saff_app/features/saff/views/saff_detail_view.dart';
import 'package:saff_app/features/saff/views/saff_join_view.dart';
import 'package:saff_app/features/saff/views/saff_new_view.dart';
import 'package:saff_app/features/settings/view_models/device_registration.dart';
import 'package:saff_app/features/settings/views/settings_view.dart';
import 'package:saff_app/features/stats/views/stats_view.dart';
import 'package:saff_app/features/today/views/today_view.dart';
import 'package:saff_app/features/wake/views/wake_flow_view.dart';
import 'package:saff_app/l10n/app_localizations.dart';

/// Bridges Riverpod state changes to the router's redirect.
class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// The app router, with redirects for sign-in and profile
/// (`docs/ARCHITECTURE.md` §6).
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref
    ..listen(uidProvider, (_, _) => refresh.ping())
    ..listen(profileProvider, (_, _) => refresh.ping())
    ..listen(onboardedProvider, (_, _) => refresh.ping())
    ..onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/today',
    refreshListenable: refresh,
    redirect: (context, state) {
      final uid = ref.read(uidProvider);
      if (uid.isLoading) return null;
      final at = state.matchedLocation;
      if (uid.value == null) return at == '/welcome' ? null : '/welcome';
      final profile = ref.read(profileProvider);
      if (profile.isLoading) return null;
      if (profile.value == null) return at == '/profile' ? null : '/profile';
      final onboarded = ref.read(onboardedProvider);
      if (onboarded.isLoading) return null;
      if (onboarded.value != true) {
        return at == '/onboarding' ? null : '/onboarding';
      }
      if (at == '/welcome' || at == '/profile') return '/today';
      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeView(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) => ProfileSetupView(
            initialName: ref.watch(_testUserNameProvider),
          ),
        ),
      ),
      GoRoute(
        path: '/plant/:saffId',
        builder: (context, state) =>
            PlantView(saffId: state.pathParameters['saffId']!),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingView(),
      ),
      GoRoute(
        path: '/saff/new',
        builder: (context, state) => const SaffNewView(),
      ),
      GoRoute(
        path: '/saff/join',
        builder: (context, state) =>
            SaffJoinView(code: state.uri.queryParameters['code']),
      ),
      GoRoute(
        path: '/join/:code',
        builder: (context, state) =>
            SaffJoinView(code: state.pathParameters['code']),
      ),
      GoRoute(
        path: '/saff/:id',
        builder: (context, state) =>
            SaffDetailView(saffId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/wake/:saffId/:occId',
        builder: (context, state) => WakeFlowView(
          saffId: state.pathParameters['saffId']!,
          occurrenceId: state.pathParameters['occId']!,
          onExit: () => context.go('/chat/${state.pathParameters['saffId']}'),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _TabShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/today',
                builder: (context, state) => const TodayView(),
                routes: [
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsView(),
                    routes: [
                      GoRoute(
                        path: 'alarm',
                        builder: (context, state) => const ReliabilityView(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) => const ChatListView(),
                routes: [
                  GoRoute(
                    path: ':saffId',
                    builder: (context, state) =>
                        ChatView(saffId: state.pathParameters['saffId']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/learn',
                builder: (context, state) => const LearnView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stats',
                builder: (context, state) => const StatsView(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Dev test users arrive with their name pre-filled on the profile screen.
final _testUserNameProvider = Provider<String>((ref) {
  final email = ref.watch(authServiceProvider).email ?? '';
  final name = email.endsWith('@test.saff') ? email.split('@').first : '';
  return name.isEmpty ? '' : '${name[0].toUpperCase()}${name.substring(1)}';
});

class _TabShell extends ConsumerWidget {
  const _TabShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref
      ..watch(scheduleSyncProvider)
      ..watch(deviceRegistrationProvider)
      ..watch(selectedSaffProvider);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.wb_twilight),
            label: l10n.tabToday,
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            label: l10n.tabChat,
          ),
          NavigationDestination(
            icon: const Icon(Icons.school_outlined),
            label: l10n.tabLearn,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart),
            label: l10n.tabStats,
          ),
        ],
      ),
    );
  }
}
