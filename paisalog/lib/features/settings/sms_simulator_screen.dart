/// SMS Simulator & Sandbox screen.
/// Allows testing real or synthetic SMS messages live against the ingestion pipeline.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/models/models.dart';
import '../../domain/services/service_contracts.dart';

class SmsSimulatorScreen extends ConsumerStatefulWidget {
  const SmsSimulatorScreen({super.key});

  @override
  ConsumerState<SmsSimulatorScreen> createState() => _SmsSimulatorScreenState();
}

class _SmsSimulatorScreenState extends ConsumerState<SmsSimulatorScreen> {
  final _smsTextController = TextEditingController();
  final _senderController = TextEditingController(text: 'VM-HDFCBK');
  IngestionResult? _lastResult;
  bool _isProcessing = false;

  final _presets = <String, Map<String, String>>{
    'HDFC Debit': {
      'sender': 'VM-HDFCBK',
      'text':
          'Rs.250.00 debited from A/C **1234 on 28-OCT-26 at SWIGGY. UPI Ref: 3049281729. Bal: Rs.45,210.00',
    },
    'SBI UPI Debit': {
      'sender': 'SBI-UPI',
      'text':
          'Paid Rs.149.00 to CHAI_POINT on 25-OCT-26 via UPI Ref 429817291. Avail Bal: Rs.12,300.00',
    },
    'Salary Credit': {
      'sender': 'VK-HDFCBK',
      'text':
          'INR 75,000.00 credited to A/C **1234 on 01-OCT-26 by TECH_CORP_PVT_LTD. Bal: INR 1,50,000.00',
    },
    'Credit Card Purchase': {
      'sender': 'ICICIB',
      'text':
          'Alert: INR 1,299.00 spent on your Credit Card ending 9876 at AMAZON INDIA on 26-OCT-26. Avail Limit: 98,701.00',
    },
    'CC Bill Payment': {
      'sender': 'ICICIB',
      'text':
          'Payment of Rs.8,000.00 received towards your Credit Card ending 9876 on 20-OCT-26. Thank you.',
    },
    'OTP (Should Ignore)': {
      'sender': 'AXISBK',
      'text':
          'Your OTP for NetBanking transaction is 482910. Valid for 10 minutes. Do not share with anyone.',
    },
    'Ambiguous (Needs Review)': {
      'sender': 'HDFCBK',
      'text':
          'Debit of INR 500 initiated for order. Transaction status failed or pending review.',
    },
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SMS Simulator')),
      body: ListView(
        padding: const EdgeInsets.all(PaisaSpacing.md),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(PaisaSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology_outlined,
                          color: PaisaColors.primary),
                      const SizedBox(width: PaisaSpacing.sm),
                      Text(
                        'Simulate SMS Ingestion',
                        style: PaisaTextStyles.body
                            .copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: PaisaSpacing.xs),
                  Text(
                    'PaisaLog runs completely offline. Select a preset template or paste an actual bank notification to test the deterministic parsing engine.',
                    style: PaisaTextStyles.bodySmall
                        .copyWith(color: PaisaColors.textSecondary),
                  ),
                  const SizedBox(height: PaisaSpacing.md),
                  Text('PRESETS', style: PaisaTextStyles.label),
                  const SizedBox(height: PaisaSpacing.xs),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _presets.entries.map((entry) {
                      return ActionChip(
                        label: Text(entry.key),
                        onPressed: () {
                          setState(() {
                            _senderController.text = entry.value['sender']!;
                            _smsTextController.text = entry.value['text']!;
                            _lastResult = null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: PaisaSpacing.md),
                  TextField(
                    controller: _senderController,
                    decoration: const InputDecoration(
                      labelText: 'Sender ID (Optional)',
                      hintText: 'e.g. HDFCBK, SBIUPI',
                    ),
                  ),
                  const SizedBox(height: PaisaSpacing.sm),
                  TextField(
                    controller: _smsTextController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'SMS Body',
                      hintText: 'Paste message text here…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: PaisaSpacing.md),
                  FilledButton.icon(
                    onPressed: _isProcessing ? null : _processSms,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Run Ingestion Pipeline'),
                  ),
                ],
              ),
            ),
          ),

          // ── Pipeline Result Display ─────────────────────────────────────────
          if (_lastResult != null) ...[
            const SizedBox(height: PaisaSpacing.lg),
            Card(
              color: _resultBgColor(_lastResult!),
              child: Padding(
                padding: const EdgeInsets.all(PaisaSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_resultIcon(_lastResult!),
                            color: _resultColor(_lastResult!)),
                        const SizedBox(width: PaisaSpacing.sm),
                        Text(
                          _resultTitle(_lastResult!),
                          style: PaisaTextStyles.body.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: _resultColor(_lastResult!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: PaisaSpacing.sm),
                    _buildResultDetails(_lastResult!),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _resultColor(IngestionResult res) {
    switch (res) {
      case IngestionAccepted(:final wasDuplicate):
        return wasDuplicate ? PaisaColors.review : PaisaColors.income;
      case IngestionIgnored():
        return PaisaColors.textSecondary;
      case IngestionRoutedToReview():
        return PaisaColors.review;
      case IngestionFailed():
        return PaisaColors.expense;
    }
  }

  Color _resultBgColor(IngestionResult res) {
    return _resultColor(res).withOpacity(0.08);
  }

  IconData _resultIcon(IngestionResult res) {
    switch (res) {
      case IngestionAccepted(:final wasDuplicate):
        return wasDuplicate ? Icons.copy_all_outlined : Icons.check_circle_outline;
      case IngestionIgnored():
        return Icons.block_outlined;
      case IngestionRoutedToReview():
        return Icons.rule_folder_outlined;
      case IngestionFailed():
        return Icons.error_outline;
    }
  }

  String _resultTitle(IngestionResult res) {
    switch (res) {
      case IngestionAccepted(:final wasDuplicate):
        return wasDuplicate
            ? 'Duplicate Detected (Skipped)'
            : 'Ingested & Stored in Ledger';
      case IngestionIgnored():
        return 'Ignored (Not Stored)';
      case IngestionRoutedToReview():
        return 'Routed to Review Queue';
      case IngestionFailed():
        return 'Ingestion Failed';
    }
  }

  Widget _buildResultDetails(IngestionResult res) {
    switch (res) {
      case IngestionAccepted(:final transaction, :final wasDuplicate):
        if (wasDuplicate) {
          return Text(
              'Matches existing transaction ID: ${transaction.id}\nDuplicate suppressed.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: ${transaction.amount.toDisplayString()}',
                style: PaisaTextStyles.body
                    .copyWith(fontWeight: FontWeight.bold)),
            Text('Type: ${transaction.type.name.toUpperCase()}'),
            Text('Direction: ${transaction.direction.name}'),
            if (transaction.merchantOrCounterparty != null)
              Text('Merchant: ${transaction.merchantOrCounterparty}'),
            if (transaction.accountHint != null)
              Text('Account Hint: •• ${transaction.accountHint}'),
            if (transaction.referenceId != null)
              Text('Reference ID: ${transaction.referenceId}'),
            if (transaction.parserRuleId != null)
              Text('Matched Rule: ${transaction.parserRuleId}'),
            const SizedBox(height: PaisaSpacing.xs),
            const Text(
              '✓ Successfully added to your Transactions tab.',
              style: TextStyle(color: PaisaColors.income, fontWeight: FontWeight.w600),
            ),
          ],
        );
      case IngestionIgnored(:final reason):
        return Text('Reason: $reason\nNo balance change recorded.');
      case IngestionRoutedToReview(:final reason):
        return Text(
            'Reason: $reason\nThis transaction was routed to the Review Queue for human confirmation.');
      case IngestionFailed(:final error):
        return Text('Error: ${error.userMessage}');
    }
  }

  Future<void> _processSms() async {
    final text = _smsTextController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isProcessing = true);
    final service = ref.read(smsIngestionServiceProvider);

    final res = await service.processSms(
      text: text,
      receivedAt: DateTime.now(),
      sourceMetadata: SmsSourceMetadata(
        sender: _senderController.text.trim().isEmpty
            ? null
            : _senderController.text.trim(),
      ),
    );

    setState(() {
      _lastResult = res;
      _isProcessing = false;
    });

    ref.invalidate(monthlySummaryProvider);
    ref.invalidate(recentTransactionsProvider);
  }
}
