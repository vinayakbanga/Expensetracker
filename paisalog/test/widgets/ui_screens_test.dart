/// Widget tests for PaisaLog screens using ProviderScope overrides.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paisalog/app/app.dart';
import 'package:paisalog/app/providers.dart';
import 'package:paisalog/app/theme.dart';
import 'package:paisalog/domain/models/models.dart';
import 'package:paisalog/domain/services/service_contracts.dart';
import 'package:paisalog/features/dashboard/dashboard_screen.dart';
import 'package:paisalog/features/transactions/transactions_screen.dart';
import 'package:paisalog/features/review_queue/review_queue_screen.dart';
import 'package:paisalog/app/widgets/review_banner.dart';

// ─── Test Fake Transaction Repository ─────────────────────────────────────────

class TestWidgetTransactionRepository implements TransactionRepository {
  final List<Transaction> _items;

  TestWidgetTransactionRepository(this._items);

  @override
  Future<List<Transaction>> getTransactions(TransactionFilters filters) async {
    return _filterList(filters);
  }

  @override
  Stream<List<Transaction>> watchTransactions(TransactionFilters filters) {
    return Stream.value(_filterList(filters));
  }

  @override
  Future<Transaction?> getTransaction(String id) async {
    return _items.where((t) => t.id == id).firstOrNull;
  }

  @override
  Future<Result<Transaction>> addTransaction(TransactionInput input) async {
    final tx = Transaction(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      amountPaise: input.amountPaise,
      type: input.type,
      direction: input.direction,
      merchantOrCounterparty: input.merchantOrCounterparty,
      occurredAt: input.occurredAt,
      source: TransactionSource.manual,
      confidence: ParseConfidence.high,
      reviewStatus: ReviewStatus.notRequired,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _items.add(tx);
    return Success(tx);
  }

  @override
  Future<Result<Transaction>> updateTransaction(String id, TransactionInput changes) async {
    final idx = _items.indexWhere((t) => t.id == id);
    if (idx < 0) return const Failure(AppError(AppErrorKind.notFound, 'Not found'));
    final updated = _items[idx].copyWith(
      type: changes.type,
      merchantOrCounterparty: changes.merchantOrCounterparty,
    );
    _items[idx] = updated;
    return Success(updated);
  }

  @override
  Future<Result<void>> deleteTransaction(String id) async {
    _items.removeWhere((t) => t.id == id);
    return const Success(null);
  }

  @override
  Future<int> getPendingReviewCount() async {
    return _items.where((t) => t.reviewStatus == ReviewStatus.pendingReview).length;
  }

  @override
  Stream<int> watchPendingReviewCount() {
    return Stream.value(
      _items.where((t) => t.reviewStatus == ReviewStatus.pendingReview).length,
    );
  }

  List<Transaction> _filterList(TransactionFilters filters) {
    var res = List<Transaction>.from(_items);
    if (filters.reviewStatus != null) {
      res = res.where((t) => t.reviewStatus == filters.reviewStatus).toList();
    }
    if (filters.type != null) {
      res = res.where((t) => t.type == filters.type).toList();
    }
    return res;
  }
}

void main() {
  Widget createTestApp(Widget child, {List<Transaction>? initialTransactions}) {
    final repo = TestWidgetTransactionRepository(
      initialTransactions ?? List.from(syntheticTransactions),
    );

    return ProviderScope(
      overrides: [
        transactionRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: PaisaTheme.light,
        home: child,
      ),
    );
  }

  group('DashboardScreen Widget Tests', () {
    testWidgets('renders header and summary cards', (tester) async {
      await tester.pumpWidget(createTestApp(const DashboardScreen()));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('PaisaLog'), findsOneWidget);
      expect(find.text('NET SAVINGS'), findsOneWidget);
      expect(find.text('INCOME'), findsOneWidget);
      expect(find.text('EXPENSES'), findsOneWidget);
      expect(find.text('RECENT TRANSACTIONS'), findsOneWidget);
    });

    testWidgets('shows review banner when pending items exist', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: PaisaTheme.light,
        home: const Scaffold(
          body: ReviewBanner(count: 1),
        ),
      ));
      await tester.pumpAndSettle();

      // Should find the review banner
      expect(find.byType(ReviewBanner), findsOneWidget);
      expect(find.textContaining('need'), findsOneWidget);
    });
  });

  group('TransactionsScreen Widget Tests', () {
    testWidgets('renders search bar and type filter chips', (tester) async {
      await tester.pumpWidget(createTestApp(const TransactionsScreen()));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Transactions'), findsOneWidget);
      expect(find.text('Search transactions…'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Transfers'), findsOneWidget);
      // Finding the filter chip with text 'Review' specifically
      expect(find.widgetWithText(GestureDetector, 'Review'), findsWidgets);
    });

    testWidgets('filters transactions by type when chip tapped', (tester) async {
      await tester.pumpWidget(createTestApp(const TransactionsScreen()));
      await tester.pumpAndSettle();

      // Tap Expenses filter
      await tester.tap(find.text('Expenses'));
      await tester.pumpAndSettle();

      // Should show expense items
      expect(find.text('MERCHANT_A'), findsOneWidget);
    });
  });

  group('ReviewQueueScreen Widget Tests', () {
    testWidgets('shows pending review cards and reason', (tester) async {
      await tester.pumpWidget(createTestApp(const ReviewQueueScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Review Queue'), findsOneWidget);
      expect(find.text('NEEDS REVIEW'), findsOneWidget);
      expect(find.textContaining('unsupported_template'), findsOneWidget);
      expect(find.text('Correct'), findsOneWidget);
    });

    testWidgets('shows empty state when no items need review', (tester) async {
      // Empty review queue
      await tester.pumpWidget(createTestApp(
        const ReviewQueueScreen(),
        initialTransactions: [],
      ));
      await tester.pumpAndSettle();

      expect(find.text('All caught up!'), findsOneWidget);
      expect(find.text('No transactions need your review.'), findsOneWidget);
    });
  });
}
