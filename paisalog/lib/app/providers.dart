/// Riverpod providers for PaisaLog.
///
/// Providers wire together: database → repositories → services → UI.
/// Widgets depend ONLY on these providers, never on implementations directly.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/database/app_database.dart';
import '../data/repositories/transaction_repository.dart';
import '../domain/models/models.dart';
import '../domain/services/service_contracts.dart';
import '../domain/services/sms_parser.dart';
import '../domain/services/domain_services.dart';

part 'providers.g.dart';

// ─── Database ────────────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) => AppDatabase();

// ─── Repositories ────────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
TransactionRepository transactionRepository(Ref ref) {
  return DriftTransactionRepository(ref.watch(appDatabaseProvider));
}

// ─── Services ────────────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
TransactionParser transactionParser(Ref ref) {
  return DefaultTransactionParser.withDefaults();
}

@Riverpod(keepAlive: true)
DeduplicationService deduplicationService(Ref ref) {
  return DefaultDeduplicationService(
    repository: ref.watch(transactionRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
TransferDetectionService transferDetectionService(Ref ref) {
  return DefaultTransferDetectionService();
}

// ─── Dashboard / Analytics ────────────────────────────────────────────────────

@riverpod
Future<MonthlySummary> monthlySummary(Ref ref, MonthlyPeriod period) async {
  final repo = ref.watch(transactionRepositoryProvider);
  final from = DateTime(period.year, period.month, 1);
  final to = DateTime(period.year, period.month + 1, 0, 23, 59, 59);

  final txs = await repo.getTransactions(
    TransactionFilters(fromDate: from, toDate: to),
  );

  int totalIncome = 0;
  int totalExpense = 0;
  for (final tx in txs) {
    if (tx.type == TransactionType.income) totalIncome += tx.amountPaise;
    if (tx.type == TransactionType.expense) totalExpense += tx.amountPaise;
  }

  return MonthlySummary(
    period: period,
    totalIncomePaise: totalIncome,
    totalExpensePaise: totalExpense,
    transactionCount: txs.length,
  );
}

@riverpod
Stream<int> pendingReviewCount(Ref ref) {
  return ref.watch(transactionRepositoryProvider).watchPendingReviewCount();
}

@riverpod
Stream<List<Transaction>> recentTransactions(Ref ref) {
  // Most recent 10 for the Home screen
  return ref.watch(transactionRepositoryProvider).watchTransactions(
    TransactionFilters.empty,
  );
}

// ─── Transactions screen ─────────────────────────────────────────────────────

@riverpod
class TransactionFiltersNotifier extends _$TransactionFiltersNotifier {
  @override
  TransactionFilters build() => TransactionFilters.empty;

  void update(TransactionFilters filters) => state = filters;
  void reset() => state = TransactionFilters.empty;
  void setSearch(String q) => state = state.copyWith(searchQuery: q);
  void setType(TransactionType? t) => state = state.copyWith(type: t);
  void setDateRange(DateTime? from, DateTime? to) =>
      state = state.copyWith(fromDate: from, toDate: to);
}

@riverpod
Stream<List<Transaction>> filteredTransactions(Ref ref) {
  final filters = ref.watch(transactionFiltersNotifierProvider);
  return ref.watch(transactionRepositoryProvider).watchTransactions(filters);
}

@riverpod
Future<Transaction?> transactionDetail(Ref ref, String id) {
  return ref.watch(transactionRepositoryProvider).getTransaction(id);
}

// ─── Review queue ─────────────────────────────────────────────────────────────

@riverpod
Stream<List<Transaction>> pendingReviewTransactions(Ref ref) {
  return ref.watch(transactionRepositoryProvider).watchTransactions(
    const TransactionFilters(reviewStatus: ReviewStatus.pendingReview),
  );
}

// ─── Synthetic data for UI preview ───────────────────────────────────────────
// IMPORTANT: This is clearly labelled synthetic data. Never implies real balances.

final syntheticTransactions = <Transaction>[
  Transaction(
    id: 'syn-001',
    amountPaise: 25000, // ₹250.00
    type: TransactionType.expense,
    direction: TransactionDirection.debit,
    merchantOrCounterparty: 'MERCHANT_A',
    occurredAt: DateTime(2026, 10, 28, 10, 30),
    accountHint: '1234',
    referenceId: 'REF_X',
    source: TransactionSource.sms,
    confidence: ParseConfidence.high,
    reviewStatus: ReviewStatus.notRequired,
    parserRuleId: 'GENERIC_DEBIT',
    createdAt: DateTime(2026, 10, 28),
    updatedAt: DateTime(2026, 10, 28),
  ),
  Transaction(
    id: 'syn-002',
    amountPaise: 7500000, // ₹75,000.00 salary
    type: TransactionType.income,
    direction: TransactionDirection.credit,
    merchantOrCounterparty: 'EMPLOYER_A',
    occurredAt: DateTime(2026, 10, 1, 9, 0),
    accountHint: '1234',
    source: TransactionSource.sms,
    confidence: ParseConfidence.high,
    reviewStatus: ReviewStatus.notRequired,
    createdAt: DateTime(2026, 10, 1),
    updatedAt: DateTime(2026, 10, 1),
  ),
  Transaction(
    id: 'syn-003',
    amountPaise: 14900, // ₹149.00 UPI
    type: TransactionType.expense,
    direction: TransactionDirection.debit,
    merchantOrCounterparty: 'MERCHANT_B',
    occurredAt: DateTime(2026, 10, 25, 14, 15),
    referenceId: 'UPI_REF_Y',
    source: TransactionSource.sms,
    confidence: ParseConfidence.high,
    reviewStatus: ReviewStatus.notRequired,
    parserRuleId: 'UPI_PAYMENT',
    createdAt: DateTime(2026, 10, 25),
    updatedAt: DateTime(2026, 10, 25),
  ),
  Transaction(
    id: 'syn-004',
    amountPaise: 800000, // ₹8,000.00 CC bill = transfer
    type: TransactionType.transfer,
    direction: TransactionDirection.debit,
    merchantOrCounterparty: 'CREDIT_CARD_BILL',
    occurredAt: DateTime(2026, 10, 20, 11, 0),
    accountHint: '4321',
    source: TransactionSource.sms,
    confidence: ParseConfidence.high,
    reviewStatus: ReviewStatus.notRequired,
    parserRuleId: 'CC_BILL_PAYMENT',
    createdAt: DateTime(2026, 10, 20),
    updatedAt: DateTime(2026, 10, 20),
  ),
  Transaction(
    id: 'syn-005',
    amountPaise: 49900, // ₹499.00 unknown merchant
    type: TransactionType.needsReview,
    direction: TransactionDirection.debit,
    merchantOrCounterparty: null,
    occurredAt: DateTime(2026, 10, 27, 19, 42),
    source: TransactionSource.sms,
    confidence: ParseConfidence.low,
    reviewReason: 'unsupported_template',
    reviewStatus: ReviewStatus.pendingReview,
    createdAt: DateTime(2026, 10, 27),
    updatedAt: DateTime(2026, 10, 27),
  ),
];

/// [SYNTHETIC DATA] Summary for October 2026 demo.
/// Clearly labelled — never implies real account balance.
final syntheticOctoberSummary = MonthlySummary(
  period: MonthlyPeriod(2026, 10),
  totalIncomePaise: 7500000, // ₹75,000
  totalExpensePaise: 88800,  // ₹888
  transactionCount: 5,
);
