/// go_router routing configuration for PaisaLog.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/dashboard/dashboard_screen.dart';
import '../features/transactions/transactions_screen.dart';
import '../features/transactions/transaction_detail_screen.dart';
import '../features/transactions/transaction_editor_screen.dart';
import '../features/review_queue/review_queue_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/settings/settings_screen.dart';

final class AppRoutes {
  static const home = '/';
  static const transactions = '/transactions';
  static const transactionDetail = '/transactions/:id';
  static const transactionAdd = '/transactions/add';
  static const transactionEdit = '/transactions/:id/edit';
  static const reviewQueue = '/review';
  static const insights = '/insights';
  static const settings = '/settings';
  static const settingsAccounts = '/settings/accounts';
  static const settingsCategories = '/settings/categories';
  static const settingsPrivacy = '/settings/privacy';
  static const settingsImportExport = '/settings/import-export';
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  debugLogDiagnostics: false,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _ScaffoldWithNavBar(shell: shell),
      branches: [
        // Tab 0: Home
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (ctx, s) => const DashboardScreen(),
            ),
          ],
        ),

        // Tab 1: Transactions
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.transactions,
              builder: (ctx, s) => const TransactionsScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (ctx, s) =>
                      const TransactionEditorScreen(transactionId: null),
                ),
                GoRoute(
                  path: ':id',
                  builder: (ctx, s) =>
                      TransactionDetailScreen(id: s.pathParameters['id']!),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (ctx, s) => TransactionEditorScreen(
                        transactionId: s.pathParameters['id']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // Tab 2: Insights
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.insights,
              builder: (ctx, s) => const InsightsScreen(),
            ),
          ],
        ),

        // Tab 3: Settings
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.settings,
              builder: (ctx, s) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),

    // Review queue — accessible from Home and Transactions badges
    GoRoute(
      path: AppRoutes.reviewQueue,
      builder: (ctx, s) => const ReviewQueueScreen(),
    ),
  ],
);

class _ScaffoldWithNavBar extends StatelessWidget {
  final StatefulNavigationShell shell;

  const _ScaffoldWithNavBar({required this.shell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(
          i,
          initialLocation: i == shell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

