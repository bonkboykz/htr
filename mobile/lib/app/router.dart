import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'branch_pager.dart';
import '../features/today/presentation/today_page.dart';
import '../features/workout/presentation/workout_page.dart';
import '../features/workout/presentation/session_detail_page.dart';
import '../features/nutrition/presentation/nutrition_page.dart';
import '../features/progress/presentation/progress_page.dart';
import '../features/insights/presentation/insights_page.dart';
import '../features/program/presentation/program_page.dart';
import '../features/factors/presentation/factors_page.dart';
import '../features/settings/presentation/settings_page.dart';

final _rootKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/today',
  routes: [
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    StatefulShellRoute(
      builder: (context, state, shell) => shell,
      navigatorContainerBuilder: (context, shell, children) =>
          _Shell(shell: shell, children: children),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/today',
            builder: (context, state) => const TodayPage(),
            routes: [
              // Факторы — reached from Today.
              GoRoute(
                path: 'factors',
                builder: (context, state) => const FactorsPage(),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/workout',
            builder: (context, state) => const WorkoutPage(),
            routes: [
              // Программа — reached from the Workout section.
              GoRoute(
                path: 'program',
                builder: (context, state) => const ProgramPage(),
              ),
              // Детали тренировки из истории.
              GoRoute(
                path: 'session/:id',
                builder: (c, s) =>
                    SessionDetailPage(sessionId: s.pathParameters['id']!),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/nutrition', builder: (context, state) => const NutritionPage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/progress', builder: (context, state) => const ProgressPage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/insights', builder: (context, state) => const InsightsPage()),
        ]),
      ],
    ),
  ],
);

class _Shell extends StatelessWidget {
  final StatefulNavigationShell shell;
  final List<Widget> children;
  const _Shell({required this.shell, required this.children});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BranchPager(navigationShell: shell, children: children),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(LucideIcons.calendarDays, size: 22), label: 'Сегодня'),
          NavigationDestination(icon: Icon(LucideIcons.dumbbell, size: 22), label: 'Тренировка'),
          NavigationDestination(icon: Icon(LucideIcons.utensils, size: 22), label: 'Питание'),
          NavigationDestination(icon: Icon(LucideIcons.trendingUp, size: 22), label: 'Прогресс'),
          NavigationDestination(icon: Icon(LucideIcons.sparkles, size: 22), label: 'Insights'),
        ],
      ),
    );
  }
}
