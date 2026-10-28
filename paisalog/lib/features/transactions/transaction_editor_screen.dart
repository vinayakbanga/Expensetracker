/// Transaction add/edit form.
/// All validation lives in TransactionInput.validate() — not in the widget.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../app/widgets/loading_state.dart';
import '../../domain/models/models.dart';

class TransactionEditorScreen extends ConsumerStatefulWidget {
  /// null = add mode; non-null = edit mode.
  final String? transactionId;

  const TransactionEditorScreen({super.key, required this.transactionId});

  @override
  ConsumerState<TransactionEditorScreen> createState() =>
      _TransactionEditorScreenState();
}

class _TransactionEditorScreenState
    extends ConsumerState<TransactionEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form field controllers
  final _amountCtrl = TextEditingController();
  final _merchantCtrl = TextEditingController();

  TransactionType _type = TransactionType.expense;
  TransactionDirection _direction = TransactionDirection.debit;
  DateTime _occurredAt = DateTime.now();
  bool _isSubmitting = false;
  bool _isLoadingExisting = false;

  bool get _isEditing => widget.transactionId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadExisting();
  }

  Future<void> _loadExisting() async {
    setState(() => _isLoadingExisting = true);
    final tx = await ref
        .read(transactionRepositoryProvider)
        .getTransaction(widget.transactionId!);
    if (!mounted) return;
    if (tx != null) {
      // Pre-fill form with existing data
      final rupees = tx.amountPaise ~/ 100;
      final paise = tx.amountPaise % 100;
      _amountCtrl.text = paise == 0
          ? rupees.toString()
          : '$rupees.${paise.toString().padLeft(2, '0')}';
      _merchantCtrl.text = tx.merchantOrCounterparty ?? '';
      _type = tx.type == TransactionType.needsReview
          ? TransactionType.expense
          : tx.type;
      _direction = tx.direction;
      _occurredAt = tx.occurredAt;
    }
    setState(() => _isLoadingExisting = false);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _merchantCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingExisting) {
      return Scaffold(
        appBar: AppBar(title: Text(_isEditing ? 'Edit Transaction' : 'Add Transaction')),
        body: const LoadingState(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Transaction' : 'Add Transaction'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(PaisaSpacing.md),
          children: [
            // ── Type selector ─────────────────────────────────────────────────
            Text(
              'TYPE',
              style: PaisaTextStyles.sectionHeader
                  .copyWith(color: PaisaColors.textSecondary),
            ),
            const SizedBox(height: PaisaSpacing.sm),
            _TypeSelector(
              selected: _type,
              onChanged: (t) {
                setState(() {
                  _type = t;
                  _direction = switch (t) {
                    TransactionType.income => TransactionDirection.credit,
                    TransactionType.expense => TransactionDirection.debit,
                    TransactionType.transfer => TransactionDirection.debit,
                    _ => _direction,
                  };
                });
              },
            ),
            const SizedBox(height: PaisaSpacing.lg),

            // ── Amount ────────────────────────────────────────────────────────
            Text(
              'AMOUNT (₹)',
              style: PaisaTextStyles.sectionHeader
                  .copyWith(color: PaisaColors.textSecondary),
            ),
            const SizedBox(height: PaisaSpacing.sm),
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                prefixText: '₹ ',
                hintText: '0.00',
              ),
              style: PaisaTextStyles.amountMedium,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Amount is required';
                final parsed = double.tryParse(v.replaceAll(',', ''));
                if (parsed == null || parsed <= 0) {
                  return 'Enter a valid amount greater than 0';
                }
                return null;
              },
            ),
            const SizedBox(height: PaisaSpacing.lg),

            // ── Merchant ──────────────────────────────────────────────────────
            Text(
              'MERCHANT / PAYEE',
              style: PaisaTextStyles.sectionHeader
                  .copyWith(color: PaisaColors.textSecondary),
            ),
            const SizedBox(height: PaisaSpacing.sm),
            TextFormField(
              controller: _merchantCtrl,
              decoration: const InputDecoration(hintText: 'e.g. Swiggy, Rent…'),
              textCapitalization: TextCapitalization.words,
              maxLength: 200,
            ),
            const SizedBox(height: PaisaSpacing.lg),

            // ── Date & Time ───────────────────────────────────────────────────
            Text(
              'DATE & TIME',
              style: PaisaTextStyles.sectionHeader
                  .copyWith(color: PaisaColors.textSecondary),
            ),
            const SizedBox(height: PaisaSpacing.sm),
            _DateTimePicker(
              value: _occurredAt,
              onChanged: (dt) => setState(() => _occurredAt = dt),
            ),
            const SizedBox(height: PaisaSpacing.xxl),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(PaisaSpacing.md),
          child: FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_isEditing ? 'Save Changes' : 'Add Transaction'),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    // Parse amount using integer arithmetic only (no double for final value)
    final rawAmount = _amountCtrl.text.replaceAll(',', '');
    final parts = rawAmount.split('.');
    final rupees = int.tryParse(parts[0]) ?? 0;
    int paise = rupees * 100;
    if (parts.length == 2 && parts[1].isNotEmpty) {
      final paiseStr = parts[1].padRight(2, '0').substring(0, 2);
      paise += int.tryParse(paiseStr) ?? 0;
    }

    final input = TransactionInput(
      amountPaise: paise,
      type: _type,
      direction: _direction,
      merchantOrCounterparty: _merchantCtrl.text.trim().isEmpty
          ? null
          : _merchantCtrl.text.trim(),
      occurredAt: _occurredAt,
    );

    final err = input.validate();
    if (err != null) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      }
      return;
    }

    final repo = ref.read(transactionRepositoryProvider);
    final result = _isEditing
        ? await repo.updateTransaction(widget.transactionId!, input)
        : await repo.addTransaction(input);

    setState(() => _isSubmitting = false);
    if (!mounted) return;

    switch (result) {
      case Success():
        context.pop();
      case Failure(error: final e):
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.userMessage)));
    }
  }
}

// ── Type selector chips ──────────────────────────────────────────────────────

class _TypeSelector extends StatelessWidget {
  final TransactionType selected;
  final ValueChanged<TransactionType> onChanged;

  const _TypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const types = [
      (TransactionType.expense, 'Expense', PaisaColors.expense),
      (TransactionType.income, 'Income', PaisaColors.income),
      (TransactionType.transfer, 'Transfer', PaisaColors.transfer),
    ];
    return Row(
      children: types.map((t) {
        final (type, label, color) = t;
        final isSelected = selected == type;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? color : Colors.grey.withOpacity(0.3),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: PaisaTextStyles.label.copyWith(
                  color: isSelected ? color : PaisaColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Date time picker ─────────────────────────────────────────────────────────

class _DateTimePicker extends StatelessWidget {
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  const _DateTimePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (date == null || !context.mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(value),
        );
        if (time == null) return;
        onChanged(DateTime(
          date.year, date.month, date.day, time.hour, time.minute,
        ));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: PaisaSpacing.md,
          vertical: PaisaSpacing.md,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 18, color: PaisaColors.textSecondary),
            const SizedBox(width: PaisaSpacing.sm),
            Text(
              _format(value),
              style: PaisaTextStyles.body.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  String _format(DateTime d) {
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '${d.day} ${months[d.month]} ${d.year}, $time';
  }
}

