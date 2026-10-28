/// Single transaction row for lists.
library;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/models.dart';
import '../theme.dart';
import 'amount_display.dart';
import 'category_chip.dart';

class TransactionRow extends StatelessWidget {
  final Transaction transaction;
  final bool showReviewBadge;

  const TransactionRow({
    super.key,
    required this.transaction,
    this.showReviewBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<PaisaThemeExtension>()!;
    final isPending = transaction.reviewStatus == ReviewStatus.pendingReview;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/transactions/${transaction.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PaisaSpacing.md,
          vertical: PaisaSpacing.sm + 2,
        ),
        child: Row(
          children: [
            // Category icon circle
            _TypeIcon(type: transaction.type, ext: ext),
            const SizedBox(width: PaisaSpacing.md),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          transaction.merchantOrCounterparty ?? _typeLabel(transaction.type),
                          style: PaisaTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (showReviewBadge && isPending)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: ext.reviewColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Review',
                            style: PaisaTextStyles.caption.copyWith(
                              color: ext.reviewColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(transaction.occurredAt),
                    style: PaisaTextStyles.bodySmall.copyWith(
                      color: PaisaColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: PaisaSpacing.sm),
            AmountDisplay(paise: transaction.amountPaise, type: transaction.type),
          ],
        ),
      ),
    );
  }

  String _typeLabel(TransactionType t) => switch (t) {
        TransactionType.income => 'Income',
        TransactionType.expense => 'Expense',
        TransactionType.transfer => 'Transfer',
        TransactionType.needsReview => 'Pending Review',
      };

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Today ${_time(d)}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (d.year == yesterday.year && d.month == yesterday.month && d.day == yesterday.day) {
      return 'Yesterday ${_time(d)}';
    }
    return '${d.day} ${_monthName(d.month)} ${_time(d)}';
  }

  String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _monthName(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];
}

class _TypeIcon extends StatelessWidget {
  final TransactionType type;
  final PaisaThemeExtension ext;

  const _TypeIcon({required this.type, required this.ext});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      TransactionType.income => (Icons.arrow_downward_rounded, ext.incomeColor),
      TransactionType.expense => (Icons.arrow_upward_rounded, ext.expenseColor),
      TransactionType.transfer => (Icons.swap_horiz_rounded, ext.transferColor),
      TransactionType.needsReview => (Icons.help_outline_rounded, ext.reviewColor),
    };
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

