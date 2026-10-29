/// Deduplication, Transfer Detection, Categorization service implementations.
library;

import 'dart:convert';
import 'dart:math';
import '../models/models.dart';
import 'service_contracts.dart';

// ─── Deduplication ────────────────────────────────────────────────────────────

class DefaultDeduplicationService implements DeduplicationService {
  final TransactionRepository repository;

  const DefaultDeduplicationService({required this.repository});

  @override
  Future<DuplicateEvaluation> evaluate(ParsedCandidate candidate) async {
    // 1. If we have a reliable reference ID, use it as primary key
    if (candidate.referenceId != null && candidate.referenceId!.isNotEmpty) {
      final filters = TransactionFilters.empty;
      final existing = await repository.getTransactions(filters);
      for (final tx in existing) {
        if (tx.referenceId == candidate.referenceId) {
          return DuplicateFound(existingTransaction: tx, confidence: 1.0);
        }
      }
    }

    // 2. Fallback: compare amount + direction + account + time window (±60 min)
    final windowStart = (candidate.occurredAt ?? DateTime.now())
        .subtract(const Duration(minutes: 60));
    final windowEnd = (candidate.occurredAt ?? DateTime.now())
        .add(const Duration(minutes: 60));

    final existing = await repository.getTransactions(
      TransactionFilters(fromDate: windowStart, toDate: windowEnd),
    );

    for (final tx in existing) {
      if (tx.amountPaise != candidate.amountPaise) continue;
      if (tx.direction != candidate.direction) continue;

      // If both have different explicit reference IDs, they are distinct transactions
      if (candidate.referenceId != null &&
          tx.referenceId != null &&
          candidate.referenceId!.isNotEmpty &&
          tx.referenceId!.isNotEmpty &&
          candidate.referenceId != tx.referenceId) {
        continue;
      }

      double score = 0.5;

      if (tx.accountHint != null &&
          candidate.accountHint != null &&
          tx.accountHint == candidate.accountHint) {
        score += 0.25;
      }

      if (tx.merchantOrCounterparty != null &&
          candidate.merchantOrCounterparty != null &&
          tx.merchantOrCounterparty == candidate.merchantOrCounterparty) {
        score += 0.2;
      }

      if (score >= 0.9) {
        return DuplicateFound(existingTransaction: tx, confidence: score);
      }
      if (score >= 0.6) {
        return DuplicateUncertain(
          candidate: _placeholderTransaction(candidate),
          reason: 'Possible duplicate: amount/direction/window match but fields differ',
        );
      }
    }

    return const DuplicateNotFound();
  }

  /// Build a placeholder Transaction for uncertain review routing.
  Transaction _placeholderTransaction(ParsedCandidate c) {
    return Transaction(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      amountPaise: c.amountPaise,
      type: c.type,
      direction: c.direction,
      merchantOrCounterparty: c.merchantOrCounterparty,
      occurredAt: c.occurredAt ?? DateTime.now(),
      accountHint: c.accountHint,
      referenceId: c.referenceId,
      source: TransactionSource.sms,
      confidence: c.confidence,
      reviewStatus: ReviewStatus.pendingReview,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

// ─── Transfer Detection ───────────────────────────────────────────────────────

class DefaultTransferDetectionService implements TransferDetectionService {
  @override
  TransferClassification classify(
    ParsedCandidate candidate,
    List<Account> knownAccounts,
  ) {
    // Credit-card bill payment already flagged by parser
    if (candidate.parserRuleId == 'CC_BILL_PAYMENT') {
      return const DetectedTransfer(relatedAccountId: null);
    }

    final merchant = candidate.merchantOrCounterparty?.toUpperCase() ?? '';

    // If parser did not identify a transfer and merchant does not mention inter-bank transfer words,
    // it is an ordinary transaction.
    final transferKeywords = RegExp(
      r'\b(?:TRANSFER|NEFT|RTGS|IMPS|OWN\s+ACCOUNT|INTERNAL)\b',
      caseSensitive: false,
    );

    final isTransferCandidate = candidate.type == TransactionType.transfer ||
        transferKeywords.hasMatch(merchant);

    if (!isTransferCandidate) {
      return const OrdinaryTransaction();
    }

    // Check if counterparty/account is a known user account
    final acctHint = candidate.accountHint;
    if (acctHint != null) {
      final related = knownAccounts.where(
        (a) => a.maskedIdentifier == acctHint,
      );
      if (related.isNotEmpty) {
        return DetectedTransfer(relatedAccountId: related.first.id);
      }
      return const TransferNeedsReview(
        reason: 'Transfer detected but counterparty account not in known accounts list',
      );
    }

    return const TransferNeedsReview(
      reason: 'Transfer keyword found but no account hint to verify',
    );
  }
}

// ─── Categorization ──────────────────────────────────────────────────────────

class DefaultCategorizationService implements CategorizationService {
  final CategoryRepository categoryRepository;

  /// In-memory merchant → category mapping built from user corrections.
  /// In production this is persisted in the database.
  final Map<String, String> _merchantCategoryMap;

  DefaultCategorizationService({
    required this.categoryRepository,
    Map<String, String>? merchantCategoryMap,
  }) : _merchantCategoryMap = merchantCategoryMap ?? {};

  static final _keywordRules = <RegExp, String>{
    RegExp(r'\b(?:swiggy|zomato|uber\s*eat|food|restaurant|cafe)\b', caseSensitive: false):
        'food_dining',
    RegExp(r'\b(?:amazon|flipkart|myntra|nykaa|shop|store|market)\b', caseSensitive: false):
        'shopping',
    RegExp(r'\b(?:uber|ola|rapido|cab|auto|metro|bus|train)\b', caseSensitive: false):
        'transport',
    RegExp(r'\b(?:netflix|spotify|youtube|prime|hotstar|subscription)\b', caseSensitive: false):
        'entertainment',
    RegExp(r'\b(?:salary|payroll|sal\b)\b', caseSensitive: false): 'income_salary',
    RegExp(r'\b(?:electricity|water|gas|internet|mobile\s+bill|recharge)\b', caseSensitive: false):
        'utilities',
    RegExp(r'\b(?:hospital|clinic|pharmacy|medicine|doctor|health)\b', caseSensitive: false):
        'healthcare',
    RegExp(r'\b(?:school|college|university|tuition|education|course)\b', caseSensitive: false):
        'education',
    RegExp(r'\b(?:rent|landlord|housing)\b', caseSensitive: false): 'housing',
  };

  @override
  Future<CategorySuggestion> suggestCategory(ParsedCandidate candidate) async {
    // 0. Income / Salary detection
    if (candidate.type == TransactionType.income) {
      return const CategorySuggestion(
        categoryId: 'income_salary',
        reason: 'Income transaction categorized as Salary',
        confidence: 0.9,
      );
    }

    final merchant = candidate.merchantOrCounterparty ?? '';

    // 1. User correction overrides
    final normalized = merchant.toUpperCase().trim();
    if (_merchantCategoryMap.containsKey(normalized)) {
      return CategorySuggestion(
        categoryId: _merchantCategoryMap[normalized],
        reason: 'User-defined rule for merchant "$merchant"',
        confidence: 0.95,
      );
    }

    // 2. Keyword matching
    for (final entry in _keywordRules.entries) {
      if (entry.key.hasMatch(merchant)) {
        return CategorySuggestion(
          categoryId: entry.value,
          reason: 'Keyword match for "$merchant"',
          confidence: 0.75,
        );
      }
    }

    // 3. No match
    return const CategorySuggestion(
      categoryId: null,
      reason: 'No category rule matched; user should assign',
      confidence: 0.0,
    );
  }

  @override
  Future<void> recordCorrection({
    required String transactionId,
    required String newCategoryId,
    required String? merchantKey,
  }) async {
    if (merchantKey != null && merchantKey.isNotEmpty) {
      _merchantCategoryMap[merchantKey.toUpperCase().trim()] = newCategoryId;
    }
    // In production: persist to user_corrections table via Drift
  }
}

// ─── Fingerprint helper ───────────────────────────────────────────────────────

/// Compute a SHA-256 fingerprint from safe, derived fields only.
/// Raw SMS text is NEVER included.
String computeSourceFingerprint({
  required int amountPaise,
  required String? referenceId,
  required String? accountHint,
  required DateTime receivedAt,
}) {
  final input = [
    amountPaise.toString(),
    referenceId ?? '',
    accountHint ?? '',
    receivedAt.toUtc().toIso8601String().substring(0, 16), // minute precision
  ].join('|');

  // Simple deterministic hash (SHA-256 via dart:convert not available;
  // in production use package:crypto)
  // For now: use a stable string hash as placeholder.
  return input.hashCode.toRadixString(16).padLeft(16, '0');
}

