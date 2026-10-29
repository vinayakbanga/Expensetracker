/// CSV Import and Export screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/models/models.dart';
import '../../domain/services/service_contracts.dart';
import '../../data/importers/platform_file.dart';

class ImportExportScreen extends ConsumerStatefulWidget {
  const ImportExportScreen({super.key});

  @override
  ConsumerState<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends ConsumerState<ImportExportScreen> {
  final _csvPasteController = TextEditingController();
  ImportPreview? _preview;
  bool _isLoading = false;
  String? _exportPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import & Export')),
      body: ListView(
        padding: const EdgeInsets.all(PaisaSpacing.md),
        children: [
          // ── Export Section ──────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(PaisaSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.download_outlined,
                          color: PaisaColors.primary),
                      const SizedBox(width: PaisaSpacing.sm),
                      Text(
                        'Export Transactions',
                        style: PaisaTextStyles.body
                            .copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: PaisaSpacing.xs),
                  Text(
                    'Export all transactions to a CSV file. Warning: the exported file will contain plaintext amounts and merchant names.',
                    style: PaisaTextStyles.bodySmall
                        .copyWith(color: PaisaColors.textSecondary),
                  ),
                  const SizedBox(height: PaisaSpacing.md),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _handleExport,
                    icon: const Icon(Icons.file_download),
                    label: const Text('Export to CSV'),
                  ),
                  if (_exportPath != null) ...[
                    const SizedBox(height: PaisaSpacing.sm),
                    Text(
                      'Exported to: $_exportPath',
                      style: PaisaTextStyles.bodySmall
                          .copyWith(color: PaisaColors.income),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: PaisaSpacing.lg),

          // ── Import Section ──────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(PaisaSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.upload_file_outlined,
                          color: PaisaColors.primary),
                      const SizedBox(width: PaisaSpacing.sm),
                      Text(
                        'Import CSV',
                        style: PaisaTextStyles.body
                            .copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: PaisaSpacing.xs),
                  Text(
                    'Paste CSV content with columns: date, type, direction, amount_paise, merchant',
                    style: PaisaTextStyles.bodySmall
                        .copyWith(color: PaisaColors.textSecondary),
                  ),
                  const SizedBox(height: PaisaSpacing.md),
                  TextField(
                    controller: _csvPasteController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText:
                          'date,type,direction,amount_paise,merchant\n2026-10-28T10:00:00.000,expense,debit,25000,SWIGGY',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: PaisaSpacing.md),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: _isLoading ? null : _previewPastedCsv,
                        child: const Text('Preview Import'),
                      ),
                      const SizedBox(width: PaisaSpacing.sm),
                      TextButton(
                        onPressed: _insertSampleCsv,
                        child: const Text('Sample Data'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Preview & Commit ────────────────────────────────────────
          if (_preview != null) ...[
            const SizedBox(height: PaisaSpacing.lg),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(PaisaSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Import Preview',
                      style: PaisaTextStyles.body
                          .copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: PaisaSpacing.xs),
                    Text(
                      'Valid: ${_preview!.validRows.length} rows | Invalid: ${_preview!.invalidRows.length} rows',
                      style: PaisaTextStyles.bodySmall.copyWith(
                        color: _preview!.invalidRows.isEmpty
                            ? PaisaColors.income
                            : PaisaColors.review,
                      ),
                    ),
                    const SizedBox(height: PaisaSpacing.md),
                    ..._preview!.validRows.take(5).map((row) {
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          row.type == TransactionType.income
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color: row.type == TransactionType.income
                              ? PaisaColors.income
                              : PaisaColors.expense,
                        ),
                        title: Text(row.merchantOrCounterparty ?? 'Unknown'),
                        subtitle: Text(row.occurredAt.toLocal().toString().split('.').first),
                        trailing: Text(Money(row.amountPaise).toDisplayString()),
                      );
                    }),
                    if (_preview!.validRows.length > 5)
                      Text('… and ${_preview!.validRows.length - 5} more rows',
                          style: PaisaTextStyles.bodySmall),
                    const SizedBox(height: PaisaSpacing.md),
                    FilledButton.icon(
                      onPressed: _isLoading || _preview!.validRows.isEmpty
                          ? null
                          : _commitImport,
                      icon: const Icon(Icons.check),
                      label: Text('Commit ${_preview!.validRows.length} Transactions'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _insertSampleCsv() {
    _csvPasteController.text =
        'date,type,direction,amount_paise,merchant\n'
        '2026-10-25T12:00:00.000,expense,debit,45000,ZOMATO\n'
        '2026-10-26T18:30:00.000,expense,debit,12000,UBER\n'
        '2026-10-27T09:15:00.000,income,credit,5000000,SALARY\n';
  }

  Future<void> _handleExport() async {
    setState(() => _isLoading = true);
    final svc = ref.read(importExportServiceProvider);
    final res = await svc.exportCsv(const ExportOptions());
    setState(() => _isLoading = false);

    switch (res) {
      case Success(:final value):
        setState(() => _exportPath = value.filePath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Exported ${value.rowsExported} rows to ${value.filePath}'),
            ),
          );
        }
      case Failure(:final error):
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.userMessage)),
          );
        }
    }
  }

  Future<void> _previewPastedCsv() async {
    final text = _csvPasteController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);
    final tempPath = await PlatformFileHelper.writeTempCsv(text);
    final svc = ref.read(importExportServiceProvider);
    final res = await svc.previewCsvImport(tempPath);
    setState(() => _isLoading = false);

    switch (res) {
      case Success(:final value):
        setState(() => _preview = value);
      case Failure(:final error):
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.userMessage)),
          );
        }
    }
  }

  Future<void> _commitImport() async {
    if (_preview == null) return;
    setState(() => _isLoading = true);
    final svc = ref.read(importExportServiceProvider);
    final res = await svc.commitCsvImport(_preview!);
    setState(() => _isLoading = false);

    switch (res) {
      case Success(:final value):
        setState(() => _preview = null);
        _csvPasteController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully imported ${value.imported} transactions!'),
            ),
          );
        }
      case Failure(:final error):
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.userMessage)),
          );
        }
    }
  }
}
