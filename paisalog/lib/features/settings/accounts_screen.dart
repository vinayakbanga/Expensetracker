/// Accounts management screen — list and add payment/bank accounts.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../app/widgets/empty_state.dart';
import '../../app/widgets/loading_state.dart';
import '../../domain/models/models.dart';

extension AccountTypeDisplay on AccountType {
  String get displayName {
    switch (this) {
      case AccountType.bank:
        return 'Bank Account';
      case AccountType.creditCard:
        return 'Credit Card';
      case AccountType.cash:
        return 'Cash';
      case AccountType.upi:
        return 'UPI';
      case AccountType.other:
        return 'Other';
    }
  }
}

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  IconData _iconForType(AccountType type) {
    switch (type) {
      case AccountType.bank:
        return Icons.account_balance;
      case AccountType.creditCard:
        return Icons.credit_card;
      case AccountType.upi:
        return Icons.account_balance_wallet;
      case AccountType.cash:
        return Icons.payments_outlined;
      case AccountType.other:
        return Icons.savings_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Account',
            onPressed: () => _showAddAccountDialog(context, ref),
          ),
        ],
      ),
      body: accountsAsync.when(
        loading: () => const LoadingState(message: 'Loading accounts…'),
        error: (err, _) => EmptyState.error(
          onRetry: () => ref.invalidate(accountsStreamProvider),
        ),
        data: (accounts) {
          if (accounts.isEmpty) {
            return EmptyState(
              icon: Icons.account_balance_outlined,
              title: 'No accounts added',
              subtitle:
                  'Add your bank accounts and credit cards to automatically match SMS account hints.',
              actionLabel: 'Add Account',
              onAction: () => _showAddAccountDialog(context, ref),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(PaisaSpacing.md),
            itemCount: accounts.length,
            separatorBuilder: (_, __) => const SizedBox(height: PaisaSpacing.sm),
            itemBuilder: (context, index) {
              final account = accounts[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey.shade200,
                    child: Icon(
                      _iconForType(account.type),
                      color: PaisaColors.primary,
                    ),
                  ),
                  title: Text(
                    account.nickname,
                    style: PaisaTextStyles.body
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    account.maskedIdentifier != null
                        ? '${account.type.displayName} (•• ${account.maskedIdentifier})'
                        : account.type.displayName,
                    style: PaisaTextStyles.bodySmall
                        .copyWith(color: PaisaColors.textSecondary),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.archive_outlined, size: 20),
                    tooltip: 'Archive',
                    onPressed: () => _confirmArchive(context, ref, account),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAccountDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Account'),
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final maskCtrl = TextEditingController();
    var selectedType = AccountType.bank;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: PaisaSpacing.lg,
            right: PaisaSpacing.lg,
            top: PaisaSpacing.lg,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + PaisaSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add Account',
                style: PaisaTextStyles.body
                    .copyWith(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: PaisaSpacing.md),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Account Nickname',
                  hintText: 'e.g. HDFC Salary, ICICI Amazon Pay',
                ),
                autofocus: true,
              ),
              const SizedBox(height: PaisaSpacing.md),
              DropdownButtonFormField<AccountType>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Account Type'),
                items: AccountType.values.map((t) {
                  return DropdownMenuItem(
                    value: t,
                    child: Text(t.displayName),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setSheetState(() => selectedType = val);
                },
              ),
              const SizedBox(height: PaisaSpacing.md),
              TextField(
                controller: maskCtrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'Last 4 Digits (Optional)',
                  hintText: 'e.g. 1234',
                ),
              ),
              const SizedBox(height: PaisaSpacing.lg),
              FilledButton(
                onPressed: () async {
                  final input = AccountInput(
                    nickname: nameCtrl.text.trim(),
                    type: selectedType,
                    maskedIdentifier: maskCtrl.text.trim().isEmpty
                        ? null
                        : maskCtrl.text.trim(),
                  );
                  final repo = ref.read(accountRepositoryProvider);
                  final result = await repo.addAccount(input);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    switch (result) {
                      case Success():
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added account "${input.nickname}"'),
                          ),
                        );
                      case Failure(:final error):
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.userMessage)),
                        );
                    }
                  }
                },
                child: const Text('Save Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmArchive(
      BuildContext context, WidgetRef ref, Account account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Account?'),
        content: Text(
          'Transactions associated with "${account.nickname}" will remain in your ledger.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(accountRepositoryProvider);
      await repo.archiveAccount(account.id);
    }
  }
}
