/// Insights screen — monthly trend and category breakdown.
/// Uses integer paise throughout. No floating-point money.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../app/widgets/amount_display.dart';
import '../../app/widgets/empty_state.dart';
import '../../app/widgets/loading_state.dart';
import '../../domain/models/models.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  late MonthlyPeriod _period;

  @override
  void initState() {
    super.initState();
    _period = MonthlyPeriod.now();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(monthlySummaryProvider(_period));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        actions: [
          // Month navigation
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous month',
                onPressed: () => setState(() => _period = _period.previous()),
              ),
              Text(
                _monthLabel(_period),
                style: PaisaTextStyles.label,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next month',
                onPressed: _period == MonthlyPeriod.now()
                    ? null
                    : () => setState(() => _period = _nextPeriod(_period)),
              ),
            ],
          ),
        ],
      ),
      body: summaryAsync.when(
        data: (summary) => _InsightsBody(summary: summary, period: _period),
        loading: () => const LoadingState(message: 'Calculating insights…'),
        error: (e, _) => EmptyState.error(
          onRetry: () => ref.invalidate(monthlySummaryProvider(_period)),
        ),
      ),
    );
  }

  String _monthLabel(MonthlyPeriod p) {
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[p.month]} ${p.year}';
  }

  MonthlyPeriod _nextPeriod(MonthlyPeriod p) {
    if (p.month == 12) return MonthlyPeriod(p.year + 1, 1);
    return MonthlyPeriod(p.year, p.month + 1);
  }
}

class _InsightsBody extends ConsumerWidget {
  final MonthlySummary summary;
  final MonthlyPeriod period;

  const _InsightsBody({required this.summary, required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = summary;

    if (s.transactionCount == 0) {
      return const EmptyState(
        icon: Icons.insights_outlined,
        title: 'No data for this month',
        subtitle: 'Add transactions to see insights.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(PaisaSpacing.md),
      children: [
        // ── Income vs Expenses bar ────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(PaisaSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INCOME VS EXPENSES',
                  style: PaisaTextStyles.sectionHeader.copyWith(
                    color: PaisaColors.textSecondary,
                  ),
                ),
                const SizedBox(height: PaisaSpacing.md),
                _IncomeExpenseBar(summary: s),
                const SizedBox(height: PaisaSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _LegendItem(
                      color: PaisaColors.income,
                      label: 'Income',
                      paise: s.totalIncomePaise,
                    ),
                    _LegendItem(
                      color: PaisaColors.expense,
                      label: 'Expenses',
                      paise: s.totalExpensePaise,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: PaisaSpacing.md),

        // ── Net savings ───────────────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(PaisaSpacing.md),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NET SAVINGS',
                      style: PaisaTextStyles.sectionHeader
                          .copyWith(color: PaisaColors.textSecondary),
                    ),
                    const SizedBox(height: PaisaSpacing.xs),
                    AmountDisplay(
                      paise: s.netSavingsPaise.abs(),
                      type: s.isDeficit
                          ? TransactionType.expense
                          : TransactionType.income,
                      style: PaisaTextStyles.amountMedium,
                      showSign: false,
                    ),
                  ],
                ),
                const Spacer(),
                Icon(
                  s.isDeficit
                      ? Icons.trending_down_rounded
                      : Icons.trending_up_rounded,
                  size: 40,
                  color: s.isDeficit ? PaisaColors.expense : PaisaColors.income,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: PaisaSpacing.md),

        // ── Transactions count ────────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(PaisaSpacing.md),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_outlined,
                    color: PaisaColors.primary),
                const SizedBox(width: PaisaSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${s.transactionCount} transactions',
                      style: PaisaTextStyles.body
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'this month',
                      style: PaisaTextStyles.bodySmall
                          .copyWith(color: PaisaColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: PaisaSpacing.md),
        // ── Category breakdown ───────────────────────────────────────────
        _CategoryBreakdownCard(period: period),
      ],
    );
  }
}

class _CategoryBreakdownCard extends ConsumerWidget {
  final MonthlyPeriod period;
  const _CategoryBreakdownCard({required this.period});

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return PaisaColors.primary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakdownAsync = ref.watch(categoryBreakdownProvider(period));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PaisaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EXPENSE BY CATEGORY',
              style: PaisaTextStyles.sectionHeader
                  .copyWith(color: PaisaColors.textSecondary),
            ),
            const SizedBox(height: PaisaSpacing.md),
            breakdownAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(PaisaSpacing.md),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, __) => const Text('Could not load breakdown'),
              data: (items) {
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(PaisaSpacing.md),
                    child: Center(
                      child: Text(
                        'No expenses recorded for this month.',
                        style: PaisaTextStyles.bodySmall
                            .copyWith(color: PaisaColors.textSecondary),
                      ),
                    ),
                  );
                }

                final pieSections = items.map((item) {
                  final color = _parseColor(item.category.colorHex);
                  final pct = (item.percentage * 100).round();
                  return PieChartSectionData(
                    color: color,
                    value: item.totalPaise.toDouble(),
                    title: pct >= 5 ? '$pct%' : '',
                    radius: 40,
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList();

                return Column(
                  children: [
                    SizedBox(
                      height: 180,
                      child: PieChart(
                        PieChartData(
                          sections: pieSections,
                          centerSpaceRadius: 36,
                          sectionsSpace: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: PaisaSpacing.md),
                    const Divider(),
                    ...items.map((item) {
                      final color = _parseColor(item.category.colorHex);
                      final pct = (item.percentage * 100).toStringAsFixed(1);
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: PaisaSpacing.xs,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: PaisaSpacing.sm),
                            Expanded(
                              child: Text(
                                item.category.name,
                                style: PaisaTextStyles.body,
                              ),
                            ),
                            Text(
                              '$pct%  ',
                              style: PaisaTextStyles.bodySmall
                                  .copyWith(color: PaisaColors.textSecondary),
                            ),
                            AmountDisplay(
                              paise: item.totalPaise,
                              type: TransactionType.expense,
                              showSign: false,
                              style: PaisaTextStyles.body
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomeExpenseBar extends StatelessWidget {
  final MonthlySummary summary;
  const _IncomeExpenseBar({required this.summary});

  @override
  Widget build(BuildContext context) {
    final total = summary.totalIncomePaise + summary.totalExpensePaise;
    if (total == 0) return const SizedBox.shrink();

    // Compute percentages as integers to avoid float money errors
    final incomeWidth =
        (summary.totalIncomePaise / total).clamp(0.0, 1.0);
    final expenseWidth =
        (summary.totalExpensePaise / total).clamp(0.0, 1.0);

    return SizedBox(
      height: 12,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Row(
          children: [
            Expanded(
              flex: (incomeWidth * 1000).round(),
              child: Container(color: PaisaColors.income),
            ),
            Expanded(
              flex: (expenseWidth * 1000).round(),
              child: Container(color: PaisaColors.expense),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int paise;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.paise,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: PaisaTextStyles.caption
                    .copyWith(color: PaisaColors.textSecondary)),
            Text(
              Money(paise).toDisplayString(),
              style: PaisaTextStyles.label.copyWith(color: color),
            ),
          ],
        ),
      ],
    );
  }
}

