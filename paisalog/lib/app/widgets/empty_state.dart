/// Empty / error state widget used across all screens.
library;
import 'package:flutter/material.dart';
import '../theme.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  factory EmptyState.noTransactions({VoidCallback? onAdd}) => EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No transactions yet',
        subtitle: 'Add one manually or import a bank statement.',
        actionLabel: 'Add transaction',
        onAction: onAdd,
      );

  factory EmptyState.error({String? message, VoidCallback? onRetry}) => EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Something went wrong',
        subtitle: message ?? 'Please try again.',
        actionLabel: onRetry != null ? 'Retry' : null,
        onAction: onRetry,
      );

  factory EmptyState.reviewQueueEmpty() => const EmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'All caught up!',
        subtitle: 'No transactions need your review.',
      );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PaisaSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: PaisaColors.textDisabled),
            const SizedBox(height: PaisaSpacing.md),
            Text(
              title,
              style: PaisaTextStyles.body.copyWith(
                fontWeight: FontWeight.w700,
                color: PaisaColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: PaisaSpacing.sm),
              Text(
                subtitle!,
                style: PaisaTextStyles.bodySmall.copyWith(
                  color: PaisaColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: PaisaSpacing.lg),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

