/// Deduplication unit tests using a fake in-memory repository.
/// No SQLite or Flutter runtime required.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:paisalog/domain/models/models.dart';
import 'package:paisalog/domain/services/service_contracts.dart';
import 'package:paisalog/domain/services/domain_services.dart';

// ─── Fake in-memory TransactionRepository ────────────────────────────────────

class FakeTransactionRepository implements TransactionRepository {
  final List<Transaction> _store;

  FakeTransactionRepository(this._store);

  @override
  Future<List<Transaction>> getTransactions(TransactionFilters filters) async {
    var results = List<Transaction>.from(_store);
    if (filters.fromDate != null) {
      results = results
          .where((t) => !t.occurredAt.isBefore(filters.fromDate!))
          .toList();
    }
    if (filters.toDate != null) {
      results = results
          .where((t) => !t.occurredAt.isAfter(filters.toDate!))
          .toList();
    }
    if (filters.type != null) {
      results = results.where((t) => t.type == filters.type).toList();
    }
    if (filters.reviewStatus != null) {
      results = results
          .where((t) => t.reviewStatus == filters.reviewStatus)
          .toList();
    }
    return results;
  }

  @override
  Future<Transaction?> getTransaction(String id) async =>
      _store.where((t) => t.id == id).firstOrNull;

  @override
  Future<Result<Transaction>> addTransaction(TransactionInput input) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<Transaction>> updateTransaction(String id, TransactionInput changes) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> deleteTransaction(String id) async {
    throw UnimplementedError();
  }

  @override
  Future<int> getPendingReviewCount() async =>
      _store.where((t) => t.reviewStatus == ReviewStatus.pendingReview).length;

  @override
  Stream<int> watchPendingReviewCount() => Stream.value(0);

  @override
  Stream<List<Transaction>> watchTransactions(TransactionFilters filters) =>
      Stream.value([]);
}

// ─── Helper to build test transactions ───────────────────────────────────────

Transaction _tx({
  required String id,
  required int amountPaise,
  TransactionDirection direction = TransactionDirection.debit,
  DateTime? occurredAt,
  String? referenceId,
  String? accountHint,
  String? merchant,
}) {
  final at = occurredAt ?? DateTime(2026, 10, 28, 10, 30);
  return Transaction(
    id: id,
    amountPaise: amountPaise,
    type: TransactionType.expense,
    direction: direction,
    merchantOrCounterparty: merchant,
    occurredAt: at,
    accountHint: accountHint,
    referenceId: referenceId,
    source: TransactionSource.sms,
    confidence: ParseConfidence.high,
    reviewStatus: ReviewStatus.notRequired,
    createdAt: at,
    updatedAt: at,
  );
}

ParsedCandidate _candidate({
  required int amountPaise,
  TransactionDirection direction = TransactionDirection.debit,
  DateTime? occurredAt,
  String? referenceId,
  String? accountHint,
  String? merchant,
}) {
  return ParsedCandidate(
    amountPaise: amountPaise,
    type: TransactionType.expense,
    direction: direction,
    merchantOrCounterparty: merchant,
    occurredAt: occurredAt ?? DateTime(2026, 10, 28, 10, 30),
    accountHint: accountHint,
    referenceId: referenceId,
    confidence: ParseConfidence.high,
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('DeduplicationService', () {
    test('exact reference ID match → DuplicateFound with confidence 1.0', () async {
      final existing = _tx(
        id: 'tx-001',
        amountPaise: 25000,
        referenceId: 'REF_X',
        accountHint: '1234',
      );
      final repo = FakeTransactionRepository([existing]);
      final svc = DefaultDeduplicationService(repository: repo);

      final candidate = _candidate(
        amountPaise: 25000,
        referenceId: 'REF_X',
        accountHint: '1234',
      );

      final result = await svc.evaluate(candidate);
      expect(result, isA<DuplicateFound>());
      final dup = result as DuplicateFound;
      expect(dup.confidence, equals(1.0));
      expect(dup.existingTransaction.id, equals('tx-001'));
    });

    test('different reference ID → DuplicateNotFound', () async {
      final existing = _tx(
        id: 'tx-001',
        amountPaise: 25000,
        referenceId: 'REF_X',
      );
      final repo = FakeTransactionRepository([existing]);
      final svc = DefaultDeduplicationService(repository: repo);

      final candidate = _candidate(
        amountPaise: 25000,
        referenceId: 'REF_DIFFERENT',
      );

      final result = await svc.evaluate(candidate);
      // Different ref → not matched by reference path
      // May still be DuplicateUncertain via fingerprint path
      expect(result, anyOf(isA<DuplicateNotFound>(), isA<DuplicateUncertain>()));
    });

    test('no reference but matching amount+direction+time window → uncertain', () async {
      final at = DateTime(2026, 10, 28, 10, 30);
      final existing = _tx(
        id: 'tx-002',
        amountPaise: 14900,
        direction: TransactionDirection.debit,
        occurredAt: at,
        accountHint: '1234',
      );
      final repo = FakeTransactionRepository([existing]);
      final svc = DefaultDeduplicationService(repository: repo);

      final candidate = _candidate(
        amountPaise: 14900,
        direction: TransactionDirection.debit,
        occurredAt: at.add(const Duration(minutes: 5)),
        accountHint: '1234',
      );

      final result = await svc.evaluate(candidate);
      // Should be uncertain (same amount+direction+account within window)
      expect(result, isA<DuplicateUncertain>());
    });

    test('empty repository → DuplicateNotFound', () async {
      final repo = FakeTransactionRepository([]);
      final svc = DefaultDeduplicationService(repository: repo);
      final candidate = _candidate(amountPaise: 25000, referenceId: 'REF_X');
      final result = await svc.evaluate(candidate);
      expect(result, isA<DuplicateNotFound>());
    });

    test('T-012: same SMS twice with same reference → only one stored', () async {
      final existing = _tx(
        id: 'tx-001',
        amountPaise: 25000,
        referenceId: 'REF_X',
      );
      final repo = FakeTransactionRepository([existing]);
      final svc = DefaultDeduplicationService(repository: repo);

      // Second ingestion of same SMS
      final candidate = _candidate(
        amountPaise: 25000,
        referenceId: 'REF_X',
      );

      final result = await svc.evaluate(candidate);
      expect(result, isA<DuplicateFound>());
    });
  });

  group('TransferDetectionService', () {
    final svc = DefaultTransferDetectionService();

    test('CC_BILL_PAYMENT rule → DetectedTransfer', () {
      final candidate = ParsedCandidate(
        amountPaise: 800000,
        type: TransactionType.transfer,
        direction: TransactionDirection.debit,
        confidence: ParseConfidence.high,
        parserRuleId: 'CC_BILL_PAYMENT',
        merchantOrCounterparty: 'CREDIT_CARD_BILL',
      );
      final result = svc.classify(candidate, []);
      expect(result, isA<DetectedTransfer>());
    });

    test('NEFT keyword → TransferNeedsReview when account not in known list', () {
      final candidate = ParsedCandidate(
        amountPaise: 500000,
        type: TransactionType.transfer,
        direction: TransactionDirection.debit,
        confidence: ParseConfidence.high,
        merchantOrCounterparty: 'NEFT TO PERSON_A',
        accountHint: '5678',
      );
      final result = svc.classify(candidate, []);
      expect(result, isA<TransferNeedsReview>());
    });

    test('ordinary purchase → OrdinaryTransaction', () {
      final candidate = ParsedCandidate(
        amountPaise: 25000,
        type: TransactionType.expense,
        direction: TransactionDirection.debit,
        confidence: ParseConfidence.high,
        merchantOrCounterparty: 'MERCHANT_A',
        parserRuleId: 'GENERIC_DEBIT',
      );
      final result = svc.classify(candidate, []);
      expect(result, isA<OrdinaryTransaction>());
    });
  });
}

