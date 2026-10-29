/// Transactions list screen with search, filters, month grouping, and live updates.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../app/widgets/empty_state.dart';
import '../../app/widgets/loading_state.dart';
import '../../app/widgets/transaction_row.dart';
import '../../domain/models/models.dart';

// ─── Month grouping helpers ───────────────────────────────────────────────────

class _MonthGroup {
  final String label;     // e.g. "October 2026"
  final List<Transaction> transactions;
  _MonthGroup(this.label, this.transactions);
}

/// Groups a flat list of transactions by calendar month (most recent first).
List<_MonthGroup> _groupByMonth(List<Transaction> txs) {
  if (txs.isEmpty) return [];
  final map = <String, List<Transaction>>{};
  final labelOf = <String, String>{};
  final fmt = DateFormat('MMMM yyyy');

  for (final tx in txs) {
    final d = tx.occurredAt;
    final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
    labelOf.putIfAbsent(key, () => fmt.format(d));
    map.putIfAbsent(key, () => []).add(tx);
  }

  final sortedKeys = map.keys.toList()..sort((a, b) => b.compareTo(a));
  return sortedKeys
      .map((k) => _MonthGroup(labelOf[k]!, map[k]!))
      .toList();
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(filteredTransactionsProvider);
    final filters = ref.watch(transactionFiltersNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add transaction',
            onPressed: () => context.push('/transactions/add'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PaisaSpacing.md, 0, PaisaSpacing.md, PaisaSpacing.sm,
            ),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search transactions…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref
                              .read(transactionFiltersNotifierProvider.notifier)
                              .setSearch('');
                        },
                      )
                    : null,
              ),
              onChanged: (q) => ref
                  .read(transactionFiltersNotifierProvider.notifier)
                  .setSearch(q),
            ),
          ),

          // ── Type filter chips ───────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(
              left: PaisaSpacing.md,
              right: PaisaSpacing.md,
              bottom: PaisaSpacing.sm,
            ),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: filters.type == null,
                  onTap: () => ref
                      .read(transactionFiltersNotifierProvider.notifier)
                      .setType(null),
                ),
                const SizedBox(width: PaisaSpacing.sm),
                _FilterChip(
                  label: 'Expenses',
                  selected: filters.type == TransactionType.expense,
                  color: PaisaColors.expense,
                  onTap: () => ref
                      .read(transactionFiltersNotifierProvider.notifier)
                      .setType(TransactionType.expense),
                ),
                const SizedBox(width: PaisaSpacing.sm),
                _FilterChip(
                  label: 'Income',
                  selected: filters.type == TransactionType.income,
                  color: PaisaColors.income,
                  onTap: () => ref
                      .read(transactionFiltersNotifierProvider.notifier)
                      .setType(TransactionType.income),
                ),
                const SizedBox(width: PaisaSpacing.sm),
                _FilterChip(
                  label: 'Transfers',
                  selected: filters.type == TransactionType.transfer,
                  color: PaisaColors.transfer,
                  onTap: () => ref
                      .read(transactionFiltersNotifierProvider.notifier)
                      .setType(TransactionType.transfer),
                ),
                const SizedBox(width: PaisaSpacing.sm),
                _FilterChip(
                  label: 'Review',
                  selected: filters.type == TransactionType.needsReview,
                  color: PaisaColors.review,
                  onTap: () => ref
                      .read(transactionFiltersNotifierProvider.notifier)
                      .setType(TransactionType.needsReview),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Transaction list with month headers ─────────────────────────────
          Expanded(
            child: txAsync.when(
              data: (txs) {
                if (txs.isEmpty) {
                  return EmptyState.noTransactions(
                    onAdd: () => context.push('/transactions/add'),
                  );
                }
                final groups = _groupByMonth(txs);
                // Build a flat index list: each item is either a header or a tx row.
                // Header items are strings; tx items are Transactions.
                final items = <Object>[];
                for (final g in groups) {
                  items.add(g.label); // month header sentinel
                  items.addAll(g.transactions);
                }
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    if (item is String) {
                      return _MonthHeader(label: item);
                    }
                    final tx = item as Transaction;
                    final isLast = i == items.length - 1 ||
                        items[i + 1] is String;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TransactionRow(transaction: tx),
                        if (!isLast)
                          const Divider(
                            indent: PaisaSpacing.md,
                            endIndent: PaisaSpacing.md,
                            height: 1,
                          ),
                      ],
                    );
                  },
                );
              },
              loading: () => const LoadingState(message: 'Loading transactions…'),
              error: (e, _) => EmptyState.error(
                onRetry: () => ref.invalidate(filteredTransactionsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Month header widget ──────────────────────────────────────────────────────

class _MonthHeader extends StatelessWidget {
  final String label;
  const _MonthHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PaisaSpacing.md, PaisaSpacing.lg, PaisaSpacing.md, PaisaSpacing.xs,
      ),
      child: Text(
        label,
        style: PaisaTextStyles.label.copyWith(
          color: PaisaColors.textSecondary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Filter chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.color = PaisaColors.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.grey.withOpacity(0.3),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: PaisaTextStyles.label.copyWith(
            color: selected ? color : PaisaColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
