/// Dashboard / Home screen.
///
/// Shows: [SYNTHETIC DATA] monthly summary, pending review banner, recent transactions.
/// Never displays real account balances or implies data is live.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../app/widgets/amount_display.dart';
import '../../app/widgets/empty_state.dart';
import '../../app/widgets/loading_state.dart';
import '../../app/widgets/review_banner.dart';
import '../../app/widgets/summary_card.dart';
import '../../app/widgets/transaction_row.dart';
import '../../domain/models/models.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = MonthlyPeriod.now();
    final summaryAsync = ref.watch(monthlySummaryProvider(period));
    final reviewCountAsync = ref.watch(pendingReviewCountProvider);
    final recentAsync = ref.watch(recentTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PaisaLog'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Add transaction',
            onPressed: () => context.push('/transactions/add'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: PaisaColors.primary,
        onRefresh: () async {
          ref.invalidate(monthlySummaryProvider);
          ref.invalidate(recentTransactionsProvider);
        },
        child: CustomScrollView(
          slivers: [
            // ── Month header ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  PaisaSpacing.md,
                  PaisaSpacing.md,
                  PaisaSpacing.md,
                  0,
                ),
                child: _MonthHeader(period: period),
              ),
            ),

            // ── Summary cards ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: summaryAsync.when(
                data: (s) => _SummarySection(summary: s),
                loading: () => _SummarySection(summary: null),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(PaisaSpacing.md),
                  child: EmptyState.error(
                    message: 'Could not load summary',
                    onRetry: () => ref.invalidate(monthlySummaryProvider),
                  ),
                ),
              ),
            ),

            // ── Review banner ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: reviewCountAsync.when(
                data: (n) => ReviewBanner(count: n),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            // ── Recent transactions header ────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  PaisaSpacing.md,
                  PaisaSpacing.lg,
                  PaisaSpacing.md,
                  PaisaSpacing.sm,
                ),
                child: Row(
                  children: [
                    Text(
                      'RECENT TRANSACTIONS',
                      style: PaisaTextStyles.sectionHeader.copyWith(
                        color: PaisaColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.go('/transactions'),
                      style: TextButton.styleFrom(
                        foregroundColor: PaisaColors.primary,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('See all'),
                    ),
                  ],
                ),
              ),
            ),

            // ── Recent transaction list ───────────────────────────────────────
            recentAsync.when(
              data: (txs) {
                final recent = txs.take(10).toList();
                if (recent.isEmpty) {
                  return SliverToBoxAdapter(
                    child: EmptyState.noTransactions(
                      onAdd: () => context.push('/transactions/add'),
                    ),
                  );
                }
                return SliverList.separated(
                  itemCount: recent.length,
                  separatorBuilder: (_, __) => const Divider(
                    indent: PaisaSpacing.md,
                    endIndent: PaisaSpacing.md,
                  ),
                  itemBuilder: (_, i) => TransactionRow(transaction: recent[i]),
                );
              },
              loading: () => const SliverToBoxAdapter(child: LoadingState()),
              error: (e, _) => SliverToBoxAdapter(
                child: EmptyState.error(
                  onRetry: () => ref.invalidate(recentTransactionsProvider),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: PaisaSpacing.xxl)),
          ],
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final MonthlyPeriod period;
  const _MonthHeader({required this.period});

  @override
  Widget build(BuildContext context) {
    final months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return Text(
      '${months[period.month]} ${period.year}',
      style: PaisaTextStyles.screenTitle.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  final MonthlySummary? summary;
  const _SummarySection({required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final isLoading = s == null;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PaisaSpacing.md,
        vertical: PaisaSpacing.md,
      ),
      child: Column(
        children: [
          // Net savings hero
          Card(
            child: Padding(
              padding: const EdgeInsets.all(PaisaSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NET SAVINGS',
                    style: PaisaTextStyles.sectionHeader.copyWith(
                      color: PaisaColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: PaisaSpacing.sm),
                  if (isLoading)
                    Container(
                      width: 160,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    )
                  else
                    AmountDisplay(
                      paise: s!.netSavingsPaise.abs(),
                      type: s.isDeficit
                          ? TransactionType.expense
                          : TransactionType.income,
                      style: PaisaTextStyles.amountLarge,
                      showSign: false,
                    ),
                  if (!isLoading && s!.isDeficit) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Spending exceeds income this month',
                      style: PaisaTextStyles.caption.copyWith(
                        color: PaisaColors.expense,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: PaisaSpacing.sm),
          Row(
            children: [
              Expanded(
                child: SummaryCard(
                  label: 'Income',
                  paise: s?.totalIncomePaise ?? 0,
                  type: TransactionType.income,
                  isLoading: isLoading,
                ),
              ),
              const SizedBox(width: PaisaSpacing.sm),
              Expanded(
                child: SummaryCard(
                  label: 'Expenses',
                  paise: s?.totalExpensePaise ?? 0,
                  type: TransactionType.expense,
                  isLoading: isLoading,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
