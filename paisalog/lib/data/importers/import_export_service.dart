/// CSV import/export service implementation.
library;

import 'package:csv/csv.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/models.dart';
import '../../domain/services/service_contracts.dart';
import 'platform_file.dart';

class DefaultImportExportService implements ImportExportService {
  final TransactionRepository repository;
  static const _uuid = Uuid();

  static const _csvHeaders = [
    'id', 'date', 'type', 'direction', 'amount_paise',
    'merchant', 'account_hint', 'reference_id', 'category_id',
    'source', 'review_status',
  ];

  const DefaultImportExportService({required this.repository});

  @override
  Future<Result<ExportSummary>> exportCsv(ExportOptions options) async {
    try {
      final txs = await repository.getTransactions(options.filters);
      final rows = <List<dynamic>>[_csvHeaders];

      for (final tx in txs) {
        rows.add([
          tx.id,
          tx.occurredAt.toIso8601String(),
          tx.type.name,
          tx.direction.name,
          tx.amountPaise,
          tx.merchantOrCounterparty ?? '',
          tx.accountHint ?? '',
          tx.referenceId ?? '',
          tx.categoryId ?? '',
          tx.source.name,
          tx.reviewStatus.name,
        ]);
      }

      final csv = const ListToCsvConverter().convert(rows);

      final filePath = await PlatformFileHelper.writeTempCsv(csv);

      return Success(ExportSummary(
        rowsExported: txs.length,
        filePath: filePath,
      ));
    } catch (e) {
      return Failure(AppError(AppErrorKind.exportFailure, 'Export failed'));
    }
  }

  @override
  Future<Result<ImportPreview>> previewCsvImport(String filePath) async {
    try {
      final content = await PlatformFileHelper.readString(filePath);
      if (content == null) {
        return Failure(AppError(AppErrorKind.importFailure, 'File not found'));
      }
      final rows = const CsvToListConverter().convert(content);

      if (rows.isEmpty) {
        return Failure(AppError(AppErrorKind.importFailure, 'File is empty'));
      }

      final header = rows.first.map((e) => e.toString().trim()).toList();
      final amountIdx = header.indexOf('amount_paise');
      final typeIdx = header.indexOf('type');
      final dirIdx = header.indexOf('direction');
      final dateIdx = header.indexOf('date');
      final merchantIdx = header.indexOf('merchant');

      if (amountIdx < 0 || typeIdx < 0 || dateIdx < 0) {
        return Failure(AppError(
          AppErrorKind.importFailure,
          'CSV missing required columns: amount_paise, type, date',
        ));
      }

      final valid = <TransactionInput>[];
      final invalid = <ImportRowError>[];

      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        try {
          final amountPaise = int.tryParse(row[amountIdx].toString());
          if (amountPaise == null || amountPaise <= 0) {
            invalid.add(ImportRowError(rowIndex: i, reason: 'Invalid amount_paise'));
            continue;
          }

          final type = TransactionType.values.firstWhere(
            (e) => e.name == row[typeIdx].toString().trim(),
            orElse: () => TransactionType.needsReview,
          );

          final direction = dirIdx >= 0
              ? TransactionDirection.values.firstWhere(
                  (e) => e.name == row[dirIdx].toString().trim(),
                  orElse: () => TransactionDirection.unknown,
                )
              : TransactionDirection.unknown;

          final date = DateTime.tryParse(row[dateIdx].toString());
          if (date == null) {
            invalid.add(ImportRowError(rowIndex: i, reason: 'Invalid date format'));
            continue;
          }

          valid.add(TransactionInput(
            amountPaise: amountPaise,
            type: type,
            direction: direction,
            merchantOrCounterparty: merchantIdx >= 0
                ? row[merchantIdx].toString().trim().isEmpty
                    ? null
                    : row[merchantIdx].toString().trim()
                : null,
            occurredAt: date,
          ));
        } catch (_) {
          invalid.add(ImportRowError(rowIndex: i, reason: 'Could not parse row'));
        }
      }

      return Success(ImportPreview(
        sourceFilePath: filePath,
        validRows: valid,
        invalidRows: invalid,
        potentialDuplicates: const [], // TODO: run dedupe check on preview
      ));
    } catch (e) {
      return Failure(AppError(AppErrorKind.importFailure, 'Could not read file'));
    }
  }

  @override
  Future<Result<ImportSummary>> commitCsvImport(ImportPreview preview) async {
    int imported = 0;
    int failed = 0;

    for (final input in preview.validRows) {
      final result = await repository.addTransaction(input);
      switch (result) {
        case Success():
          imported++;
        case Failure():
          failed++;
      }
    }

    return Success(ImportSummary(
      imported: imported,
      skippedDuplicates: preview.potentialDuplicates.length,
      failed: failed,
    ));
  }
}

