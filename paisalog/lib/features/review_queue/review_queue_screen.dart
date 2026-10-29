/// Review queue screen — shows all pending-review transactions.
/// Never silently guesses; user must confirm every resolution.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../app/widgets/amount_display.dart';
import '../../app/widgets/empty_state.dart';
import '../../app/widgets/loading_state.dart';
import '../../domain/models/models.dart';

class ReviewQueueScreen extends ConsumerWidget {
  const ReviewQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewAsync = ref.watch(pendingReviewTransactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Review Queue')),
      body: reviewAsync.when(
        data: (txs) {
          if (txs.isEmpty) return EmptyState.reviewQueueEmpty();
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: PaisaSpacing.sm),
            itemCount: txs.length,
            separatorBuilder: (_, __) => const SizedBox(height: PaisaSpacing.sm),
            itemBuilder: (_, i) => _ReviewCard(transaction: txs[i]),
          );
        },
        loading: () => const LoadingState(message: 'Loading review queue…'),
        error: (e, _) => EmptyState.error(
          onRetry: () => ref.invalidate(pendingReviewTransactionsProvider),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Transaction transaction;
  const _ReviewCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<PaisaThemeExtension>()!;
    final tx = transaction;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PaisaSpacing.md),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ext.reviewColor.withOpacity(0.4), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(PaisaSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ext.reviewColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'NEEDS REVIEW',
                      style: PaisaTextStyles.caption.copyWith(
                        color: ext.reviewColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(tx.occurredAt),
                    style: PaisaTextStyles.bodySmall.copyWith(
                      color: PaisaColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PaisaSpacing.md),

              // Amount
              AmountDisplay(
                paise: tx.amountPaise,
                type: tx.type,
                style: PaisaTextStyles.amountMedium,
              ),
              const SizedBox(height: PaisaSpacing.xs),

              // Reason
              Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: ext.reviewColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Reason: ${tx.reviewReason ?? 'unspecified'}',
                      style: PaisaTextStyles.bodySmall.copyWith(
                        color: ext.reviewColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: PaisaSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: PaisaSpacing.sm),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showQuickResolveSheet(context),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Resolve'),
                    ),
                  ),
                  const SizedBox(width: PaisaSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          context.push('/transactions/${tx.id}/edit'),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickResolveSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(PaisaSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Resolve Transaction',
                  style: PaisaTextStyles.headingSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: PaisaSpacing.xs),
                Text(
                  'Classify this transaction to update your ledger',
                  style: PaisaTextStyles.bodySmall.copyWith(
                    color: PaisaColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: PaisaSpacing.md),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0x22EF4444),
                    child: Icon(Icons.arrow_upward_rounded, color: PaisaColors.expense),
                  ),
                  title: const Text('Expense'),
                  subtitle: const Text('Outgoing payment / purchase'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _resolveAs(ref, TransactionType.expense, TransactionDirection.debit);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0x2222C55E),
                    child: Icon(Icons.arrow_downward_rounded, color: PaisaColors.income),
                  ),
                  title: const Text('Income'),
                  subtitle: const Text('Salary, refund or deposit'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _resolveAs(ref, TransactionType.income, TransactionDirection.credit);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0x2294A3B8),
                    child: Icon(Icons.swap_horiz_rounded, color: PaisaColors.transfer),
                  ),
                  title: const Text('Transfer'),
                  subtitle: const Text('Credit card bill or self account transfer'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _resolveAs(ref, TransactionType.transfer, TransactionDirection.debit);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _resolveAs(
    WidgetRef ref,
    TransactionType type,
    TransactionDirection direction,
  ) async {
    final repo = ref.read(transactionRepositoryProvider);
    final input = TransactionInput(
      amountPaise: transaction.amountPaise,
      type: type,
      direction: direction,
      merchantOrCounterparty: transaction.merchantOrCounterparty,
      occurredAt: transaction.occurredAt,
      categoryId: transaction.categoryId,
      accountHint: transaction.accountHint,
      referenceId: transaction.referenceId,
      source: transaction.source,
      confidence: ParseConfidence.high,
      reviewStatus: ReviewStatus.corrected,
      parserRuleId: transaction.parserRuleId,
    );
    await repo.updateTransaction(transaction.id, input);
  }

  String _formatDate(DateTime d) {
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month]}';
  }
}

