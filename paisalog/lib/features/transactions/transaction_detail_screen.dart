/// Transaction detail screen — shows all safe metadata for one transaction.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../app/widgets/amount_display.dart';
import '../../app/widgets/confirmation_dialog.dart';
import '../../app/widgets/empty_state.dart';
import '../../app/widgets/loading_state.dart';
import '../../domain/models/models.dart';

class TransactionDetailScreen extends ConsumerWidget {
  final String id;
  const TransactionDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(transactionDetailProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction'),
        actions: [
          txAsync.when(
            data: (tx) => tx == null
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit',
                    onPressed: () => context.push('/transactions/$id/edit'),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: txAsync.when(
        data: (tx) {
          if (tx == null) {
            return EmptyState.error(message: 'Transaction not found');
          }
          return _TransactionDetailBody(transaction: tx);
        },
        loading: () => const LoadingState(),
        error: (e, _) => EmptyState.error(
          onRetry: () => ref.invalidate(transactionDetailProvider(id)),
        ),
      ),
      bottomNavigationBar: txAsync.when(
        data: (tx) => tx == null
            ? null
            : _DeleteBar(
                onDelete: () async {
                  final confirmed = await showConfirmationDialog(
                    context,
                    title: 'Delete transaction?',
                    message: 'This action cannot be undone.',
                    confirmLabel: 'Delete',
                    isDestructive: true,
                  );
                  if (!confirmed || !context.mounted) return;
                  final result = await ref
                      .read(transactionRepositoryProvider)
                      .deleteTransaction(id);
                  if (!context.mounted) return;
                  switch (result) {
                    case Success():
                      context.pop();
                    case Failure(error: final e):
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.userMessage)),
                      );
                  }
                },
              ),
        loading: () => null,
        error: (_, __) => null,
      ),
    );
  }
}

class _TransactionDetailBody extends StatelessWidget {
  final Transaction transaction;
  const _TransactionDetailBody({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final isPending = tx.reviewStatus == ReviewStatus.pendingReview;

    return ListView(
      padding: const EdgeInsets.all(PaisaSpacing.md),
      children: [
        // Amount hero
        Card(
          child: Padding(
            padding: const EdgeInsets.all(PaisaSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AmountDisplay(
                  paise: tx.amountPaise,
                  type: tx.type,
                  style: PaisaTextStyles.amountLarge,
                ),
                const SizedBox(height: PaisaSpacing.sm),
                _TypeBadge(type: tx.type),
                if (isPending) ...[
                  const SizedBox(height: PaisaSpacing.sm),
                  _ReviewWarning(reason: tx.reviewReason),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: PaisaSpacing.md),

        // Details
        Card(
          child: Column(
            children: [
              _DetailRow(
                label: 'Merchant / Payee',
                value: tx.merchantOrCounterparty ?? '—',
              ),
              _DetailRow(
                label: 'Date & Time',
                value: _formatDateTime(tx.occurredAt),
              ),
              _DetailRow(
                label: 'Account',
                value: tx.accountHint != null ? '••••${tx.accountHint}' : '—',
              ),
              _DetailRow(
                label: 'Reference',
                value: tx.referenceId ?? '—',
              ),
              _DetailRow(
                label: 'Source',
                value: tx.source.name.toUpperCase(),
                isLast: true,
              ),
            ],
          ),
        ),

        // Review action button
        if (isPending) ...[
          const SizedBox(height: PaisaSpacing.md),
          FilledButton.icon(
            onPressed: () => context.push('/transactions/$tx.id/edit'),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Resolve & Categorise'),
          ),
        ],
      ],
    );
  }

  String _formatDateTime(DateTime d) {
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '${d.day} ${months[d.month]} ${d.year}, $time';
  }
}

class _TypeBadge extends StatelessWidget {
  final TransactionType type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<PaisaThemeExtension>()!;
    final color = switch (type) {
      TransactionType.income => ext.incomeColor,
      TransactionType.expense => ext.expenseColor,
      TransactionType.transfer => ext.transferColor,
      TransactionType.needsReview => ext.reviewColor,
    };
    final label = switch (type) {
      TransactionType.income => 'INCOME',
      TransactionType.expense => 'EXPENSE',
      TransactionType.transfer => 'TRANSFER',
      TransactionType.needsReview => 'NEEDS REVIEW',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: PaisaTextStyles.label.copyWith(color: color),
      ),
    );
  }
}

class _ReviewWarning extends StatelessWidget {
  final String? reason;
  const _ReviewWarning({this.reason});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<PaisaThemeExtension>()!;
    return Row(
      children: [
        Icon(Icons.warning_amber_rounded, color: ext.reviewColor, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Reason: ${reason ?? 'unknown_reason'}',
            style: PaisaTextStyles.bodySmall.copyWith(color: ext.reviewColor),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PaisaSpacing.md,
            vertical: PaisaSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  label,
                  style: PaisaTextStyles.bodySmall.copyWith(
                    color: PaisaColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: PaisaTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            indent: PaisaSpacing.md,
            endIndent: PaisaSpacing.md,
          ),
      ],
    );
  }
}

class _DeleteBar extends StatelessWidget {
  final VoidCallback onDelete;
  const _DeleteBar({required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(PaisaSpacing.md),
        child: OutlinedButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, color: PaisaColors.expense),
          label: const Text('Delete transaction'),
          style: OutlinedButton.styleFrom(
            foregroundColor: PaisaColors.expense,
            side: const BorderSide(color: PaisaColors.expense),
          ),
        ),
      ),
    );
  }
}
