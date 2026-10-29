/// Drift-backed implementation of TransactionRepository.
library;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/models.dart';
import '../../domain/services/service_contracts.dart';
import '../database/app_database.dart';
import '../database/tables.dart';

class DriftTransactionRepository implements TransactionRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  DriftTransactionRepository(this._db);

  // ─── Mapping helpers ────────────────────────────────────────────────────────

  Transaction _rowToTransaction(TransactionsTableData row) {
    return Transaction(
      id: row.id,
      amountPaise: row.amountPaise,
      currency: row.currency,
      type: _parseType(row.type),
      direction: _parseDirection(row.direction),
      merchantOrCounterparty: row.merchantOrCounterparty,
      occurredAt: row.occurredAt,
      occurredAtIsParsed: row.occurredAtIsParsed,
      accountHint: row.accountHint,
      referenceId: row.referenceId,
      source: _parseSource(row.source),
      sourceFingerprint: row.sourceFingerprint,
      parserRuleId: row.parserRuleId,
      confidence: _parseConfidence(row.confidence),
      reviewReason: row.reviewReason,
      categoryId: row.categoryId,
      transferGroupId: row.transferGroupId,
      reviewStatus: _parseReviewStatus(row.reviewStatus),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  TransactionsTableCompanion _inputToCompanion(String id, TransactionInput input) {
    final now = DateTime.now();
    final effectiveReviewStatus = input.type == TransactionType.needsReview
        ? ReviewStatus.pendingReview
        : input.reviewStatus;

    return TransactionsTableCompanion.insert(
      id: id,
      amountPaise: input.amountPaise,
      type: input.type.name,
      direction: input.direction.name,
      merchantOrCounterparty: Value(input.merchantOrCounterparty),
      occurredAt: input.occurredAt,
      categoryId: Value(input.categoryId),
      accountHint: Value(input.accountHint),
      referenceId: Value(input.referenceId),
      source: input.source.name,
      confidence: input.confidence.name,
      reviewStatus: effectiveReviewStatus.name,
      reviewReason: Value(input.reviewReason),
      parserRuleId: Value(input.parserRuleId),
      createdAt: now,
      updatedAt: now,
    );
  }

  // ─── Public API ─────────────────────────────────────────────────────────────

  @override
  Future<List<Transaction>> getTransactions(TransactionFilters filters) async {
    var query = _db.select(_db.transactionsTable);
    _applyFilters(query, filters);
    final rows = await (query..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])).get();
    return rows.map(_rowToTransaction).toList();
  }

  @override
  Future<Transaction?> getTransaction(String id) async {
    final row = await (_db.select(_db.transactionsTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _rowToTransaction(row);
  }

  @override
  Future<Result<Transaction>> addTransaction(TransactionInput input) async {
    final err = input.validate();
    if (err != null) return Failure(AppError(AppErrorKind.validation, err));

    final id = _uuid.v4();
    try {
      final companion = _inputToCompanion(id, input);
      await _db.into(_db.transactionsTable).insert(companion);
      final created = await getTransaction(id);
      return Success(created!);
    } catch (e) {
      return Failure(AppError(AppErrorKind.persistence, 'Could not save transaction'));
    }
  }

  @override
  Future<Result<Transaction>> updateTransaction(
    String id,
    TransactionInput changes,
  ) async {
    final err = changes.validate();
    if (err != null) return Failure(AppError(AppErrorKind.validation, err));

    final existing = await getTransaction(id);
    if (existing == null) {
      return Failure(AppError(AppErrorKind.notFound, 'Transaction not found'));
    }

    try {
      final wasPending = existing.reviewStatus == ReviewStatus.pendingReview;
      final newStatus = (wasPending && changes.type != TransactionType.needsReview)
          ? ReviewStatus.corrected
          : changes.reviewStatus;

      await (_db.update(_db.transactionsTable)..where((t) => t.id.equals(id)))
          .write(
        TransactionsTableCompanion(
          amountPaise: Value(changes.amountPaise),
          type: Value(changes.type.name),
          direction: Value(changes.direction.name),
          merchantOrCounterparty: Value(changes.merchantOrCounterparty),
          occurredAt: Value(changes.occurredAt),
          categoryId: Value(changes.categoryId),
          reviewStatus: Value(newStatus.name),
          reviewReason: Value(
            newStatus == ReviewStatus.corrected
                ? null
                : changes.reviewReason ?? existing.reviewReason,
          ),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return Success((await getTransaction(id))!);
    } catch (e) {
      return Failure(AppError(AppErrorKind.persistence, 'Could not update transaction'));
    }
  }

  @override
  Future<Result<void>> deleteTransaction(String id) async {
    try {
      final count = await (_db.delete(_db.transactionsTable)
            ..where((t) => t.id.equals(id)))
          .go();
      if (count == 0) return Failure(AppError(AppErrorKind.notFound, 'Transaction not found'));
      return const Success(null);
    } catch (e) {
      return Failure(AppError(AppErrorKind.persistence, 'Could not delete transaction'));
    }
  }

  @override
  Future<int> getPendingReviewCount() async {
    final result = await (_db.select(_db.transactionsTable)
          ..where((t) => t.reviewStatus.equals(ReviewStatus.pendingReview.name)))
        .get();
    return result.length;
  }

  @override
  Stream<int> watchPendingReviewCount() {
    return (_db.select(_db.transactionsTable)
          ..where((t) => t.reviewStatus.equals(ReviewStatus.pendingReview.name)))
        .watch()
        .map((rows) => rows.length);
  }

  @override
  Stream<List<Transaction>> watchTransactions(TransactionFilters filters) {
    var query = _db.select(_db.transactionsTable);
    _applyFilters(query, filters);
    return (query..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]))
        .watch()
        .map((rows) => rows.map(_rowToTransaction).toList());
  }

  // ─── Filter application ─────────────────────────────────────────────────────

  void _applyFilters(
    SimpleSelectStatement<$TransactionsTableTable, TransactionsTableData> query,
    TransactionFilters filters,
  ) {
    query.where((t) {
      Expression<bool> condition = const Constant(true);

      if (filters.fromDate != null) {
        condition = condition & t.occurredAt.isBiggerOrEqualValue(filters.fromDate!);
      }
      if (filters.toDate != null) {
        condition = condition & t.occurredAt.isSmallerOrEqualValue(filters.toDate!);
      }
      if (filters.type != null) {
        condition = condition & t.type.equals(filters.type!.name);
      }
      if (filters.reviewStatus != null) {
        condition = condition & t.reviewStatus.equals(filters.reviewStatus!.name);
      }
      if (filters.categoryId != null) {
        condition = condition & t.categoryId.equals(filters.categoryId!);
      }
      if (filters.searchQuery != null && filters.searchQuery!.isNotEmpty) {
        condition = condition &
            t.merchantOrCounterparty.contains(filters.searchQuery!);
      }

      return condition;
    });
  }

  // ─── Enum parsers ───────────────────────────────────────────────────────────

  TransactionType _parseType(String v) =>
      TransactionType.values.firstWhere((e) => e.name == v,
          orElse: () => TransactionType.needsReview);

  TransactionDirection _parseDirection(String v) =>
      TransactionDirection.values.firstWhere((e) => e.name == v,
          orElse: () => TransactionDirection.unknown);

  TransactionSource _parseSource(String v) =>
      TransactionSource.values.firstWhere((e) => e.name == v,
          orElse: () => TransactionSource.manual);

  ParseConfidence _parseConfidence(String v) =>
      ParseConfidence.values.firstWhere((e) => e.name == v,
          orElse: () => ParseConfidence.low);

  ReviewStatus _parseReviewStatus(String v) =>
      ReviewStatus.values.firstWhere((e) => e.name == v,
          orElse: () => ReviewStatus.pendingReview);
}

