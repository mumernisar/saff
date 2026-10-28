import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:saff_app/features/alarms/views/reliability_view.dart';
import 'package:saff_app/features/chat/views/chat_view.dart';
import 'package:saff_app/features/learn/views/learn_view.dart';
import 'package:saff_app/features/settings/views/settings_view.dart';
import 'package:saff_app/features/stats/views/stats_view.dart';
import 'package:saff_app/features/today/views/today_view.dart';
import 'package:saff_app/l10n/app_localizations.dart';

/// Builds the app router: four tabs and a pushed Settings route.
GoRouter buildRouter() => GoRouter(
  initialLocation: '/today',
  routes: [
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
              builder: (context, state) => const ChatView(),
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

class _TabShell extends StatelessWidget {
  const _TabShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
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
