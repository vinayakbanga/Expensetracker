/// Transactions list screen with search, filters, and live updates.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../app/widgets/empty_state.dart';
import '../../app/widgets/loading_state.dart';
import '../../app/widgets/transaction_row.dart';
import '../../domain/models/models.dart';

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

          // ── Transaction list ────────────────────────────────────────────────
          Expanded(
            child: txAsync.when(
              data: (txs) {
                if (txs.isEmpty) {
                  return EmptyState.noTransactions(
                    onAdd: () => context.push('/transactions/add'),
                  );
                }
                return ListView.separated(
                  itemCount: txs.length,
                  separatorBuilder: (_, __) => const Divider(
                    indent: PaisaSpacing.md,
                    endIndent: PaisaSpacing.md,
                    height: 1,
                  ),
                  itemBuilder: (_, i) =>
                      TransactionRow(transaction: txs[i]),
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
