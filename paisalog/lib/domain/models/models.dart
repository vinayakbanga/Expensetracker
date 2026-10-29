/// PaisaLog Domain Models
///
/// All monetary values are stored as integer paise (1 INR = 100 paise).
/// NEVER use double/float for financial calculations.
library;

// ─── Money ──────────────────────────────────────────────────────────────────

/// Immutable money value in Indian Paise (1 INR = 100 paise).
/// All arithmetic stays in integer domain.
class Money {
  final int paise;

  const Money(this.paise) : assert(paise >= 0, 'Paise must be non-negative');

  /// Parse a decimal rupee string (e.g. "1,234.56") into Money.
  /// Throws [MoneyParseException] on failure. Never uses double arithmetic.
  static Money fromRupeeString(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'[₹\s]|Rs\.?|,', caseSensitive: false), '')
        .trim();
    final parts = cleaned.split('.');
    if (parts.isEmpty || parts[0].isEmpty) {
      throw MoneyParseException('Cannot parse amount from: "$raw"');
    }
    final rupees = int.tryParse(parts[0]);
    if (rupees == null) throw MoneyParseException('Invalid rupee part in: "$raw"');
    int paise = rupees * 100;
    if (parts.length == 2 && parts[1].isNotEmpty) {
      final paiseStr = parts[1].padRight(2, '0').substring(0, 2);
      final paiseVal = int.tryParse(paiseStr);
      if (paiseVal == null) throw MoneyParseException('Invalid paise part in: "$raw"');
      paise += paiseVal;
    } else if (parts.length > 2) {
      throw MoneyParseException('Multiple decimal points in: "$raw"');
    }
    return Money(paise);
  }

  /// Format for display: ₹1,234.56
  String toDisplayString() {
    final rupees = paise ~/ 100;
    final cents = paise % 100;
    final formatted = rupees.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '₹$formatted.${cents.toString().padLeft(2, '0')}';
  }

  Money operator +(Money other) => Money(paise + other.paise);
  Money operator -(Money other) => Money(paise - other.paise);
  bool operator >(Money other) => paise > other.paise;
  bool operator <(Money other) => paise < other.paise;
  bool operator >=(Money other) => paise >= other.paise;
  bool operator <=(Money other) => paise <= other.paise;

  @override
  bool operator ==(Object other) => other is Money && other.paise == paise;

  @override
  int get hashCode => paise.hashCode;

  @override
  String toString() => toDisplayString();

  static const zero = Money(0);
}

class MoneyParseException implements Exception {
  final String message;
  const MoneyParseException(this.message);
  @override
  String toString() => 'MoneyParseException: $message';
}

// ─── Enums ──────────────────────────────────────────────────────────────────

/// The canonical classification of a ledger transaction.
/// - [income]: money received from an external source (salary, refund, etc.)
/// - [expense]: money paid to an external party (purchase, bill, etc.)
/// - [transfer]: movement between user's own accounts (own-account transfer,
///   credit-card bill payment). Does NOT inflate income or expense totals.
/// - [needsReview]: parsing was ambiguous or required fields are missing.
///   Never silently guess; always surface to the review queue.
enum TransactionType {
  income,
  expense,
  transfer,
  needsReview;

  bool get countsAsSpending => this == expense;
  bool get countsAsIncome => this == income;
}

/// Raw directional signal extracted from the SMS.
enum TransactionDirection { debit, credit, unknown }

/// Where the transaction record originated.
enum TransactionSource { sms, manual, csv, pdf }

/// Review queue status for a transaction.
enum ReviewStatus { notRequired, pendingReview, corrected }

// ─── Transaction ─────────────────────────────────────────────────────────────

/// Immutable domain model for a ledger transaction.
/// Widgets must NOT construct these directly from raw SQL or parser output.
/// Always go through a [TransactionRepository].
class Transaction {
  final String id;

  /// Amount in paise. Positive integer. Never double.
  final int amountPaise;

  /// ISO 4217 currency code. Default: 'INR'.
  final String currency;

  final TransactionType type;
  final TransactionDirection direction;

  /// Merchant name, payee, or transfer counterparty. Null when unavailable.
  /// Normalized conservatively; original SMS text NOT stored here.
  final String? merchantOrCounterparty;

  /// When the transaction occurred. May differ from SMS receipt time.
  final DateTime occurredAt;

  /// Whether [occurredAt] was parsed from the message (sms) or is the SMS
  /// receipt timestamp (fallback).
  final bool occurredAtIsParsed;

  /// Masked last 4 digits or user-assigned account nickname. Never full number.
  final String? accountHint;

  /// UPI Ref / RRN / UTR / bank reference. Used for deduplication.
  final String? referenceId;

  final TransactionSource source;

  /// SHA-256 fingerprint of safe derived fields for deduplication.
  /// Raw SMS text is NOT stored here.
  final String? sourceFingerprint;

  /// Which parser rule produced this record. Aids rule quality diagnostics.
  final String? parserRuleId;

  /// Deduplication confidence band.
  final ParseConfidence confidence;

  /// Human-readable reason why confidence < high or why this is in review.
  final String? reviewReason;

  /// Local category ID.
  final String? categoryId;

  /// Links both sides of a transfer (e.g., debit and credit legs).
  final String? transferGroupId;

  final ReviewStatus reviewStatus;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Transaction({
    required this.id,
    required this.amountPaise,
    this.currency = 'INR',
    required this.type,
    required this.direction,
    this.merchantOrCounterparty,
    required this.occurredAt,
    this.occurredAtIsParsed = false,
    this.accountHint,
    this.referenceId,
    required this.source,
    this.sourceFingerprint,
    this.parserRuleId,
    this.confidence = ParseConfidence.high,
    this.reviewReason,
    this.categoryId,
    this.transferGroupId,
    this.reviewStatus = ReviewStatus.notRequired,
    required this.createdAt,
    required this.updatedAt,
  });

  Money get amount => Money(amountPaise);

  bool get needsReview => reviewStatus == ReviewStatus.pendingReview;

  Transaction copyWith({
    TransactionType? type,
    String? merchantOrCounterparty,
    String? categoryId,
    ReviewStatus? reviewStatus,
    String? reviewReason,
    DateTime? updatedAt,
  }) {
    return Transaction(
      id: id,
      amountPaise: amountPaise,
      currency: currency,
      type: type ?? this.type,
      direction: direction,
      merchantOrCounterparty: merchantOrCounterparty ?? this.merchantOrCounterparty,
      occurredAt: occurredAt,
      occurredAtIsParsed: occurredAtIsParsed,
      accountHint: accountHint,
      referenceId: referenceId,
      source: source,
      sourceFingerprint: sourceFingerprint,
      parserRuleId: parserRuleId,
      confidence: confidence,
      reviewReason: reviewReason ?? this.reviewReason,
      categoryId: categoryId ?? this.categoryId,
      transferGroupId: transferGroupId,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  String toString() =>
      'Transaction($id, ${amount.toDisplayString()}, $type, $reviewStatus)';
}

/// Confidence band for parser output.
enum ParseConfidence {
  /// All required fields extracted unambiguously.
  high,

  /// Core fields extracted; some optional fields missing.
  medium,

  /// Critical ambiguity; must go to review queue.
  low,
}

// ─── TransactionInput (for create / update) ──────────────────────────────────

/// Validated input for creating or updating a transaction.
/// All validation lives here, not in widgets.
class TransactionInput {
  final int amountPaise;
  final TransactionType type;
  final TransactionDirection direction;
  final String? merchantOrCounterparty;
  final DateTime occurredAt;
  final String? accountId;
  final String? categoryId;
  final String? notes;
  final String? accountHint;
  final String? referenceId;
  final TransactionSource source;
  final ParseConfidence confidence;
  final ReviewStatus reviewStatus;
  final String? reviewReason;
  final String? parserRuleId;

  const TransactionInput({
    required this.amountPaise,
    required this.type,
    required this.direction,
    this.merchantOrCounterparty,
    required this.occurredAt,
    this.accountId,
    this.categoryId,
    this.notes,
    this.accountHint,
    this.referenceId,
    this.source = TransactionSource.manual,
    this.confidence = ParseConfidence.high,
    this.reviewStatus = ReviewStatus.notRequired,
    this.reviewReason,
    this.parserRuleId,
  });

  /// Returns null if valid, or an error message string.
  String? validate() {
    if (amountPaise <= 0) return 'Amount must be greater than zero';
    if (merchantOrCounterparty != null && merchantOrCounterparty!.length > 200) {
      return 'Merchant/counterparty name too long';
    }
    return null;
  }
}

// ─── Account ────────────────────────────────────────────────────────────────

enum AccountType { bank, creditCard, cash, upi, other }

class Account {
  final String id;
  final String nickname;
  final AccountType type;

  /// Masked last 4 digits only. Never full account number.
  final String? maskedIdentifier;

  final bool isActive;
  final DateTime createdAt;

  const Account({
    required this.id,
    required this.nickname,
    required this.type,
    this.maskedIdentifier,
    this.isActive = true,
    required this.createdAt,
  });

  Account copyWith({String? nickname, AccountType? type, bool? isActive}) {
    return Account(
      id: id,
      nickname: nickname ?? this.nickname,
      type: type ?? this.type,
      maskedIdentifier: maskedIdentifier,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
}

class AccountInput {
  final String nickname;
  final AccountType type;
  final String? maskedIdentifier;

  const AccountInput({
    required this.nickname,
    required this.type,
    this.maskedIdentifier,
  });

  String? validate() {
    if (nickname.trim().isEmpty) return 'Account nickname is required';
    if (nickname.length > 100) return 'Nickname too long';
    if (maskedIdentifier != null && maskedIdentifier!.length > 4) {
      return 'Use at most 4 masked digits';
    }
    return null;
  }
}

// ─── Category ────────────────────────────────────────────────────────────────

class Category {
  final String id;
  final String name;
  final String iconKey; // maps to a local icon/emoji
  final String colorHex;
  final bool isArchived;
  final bool isSystem; // built-in categories cannot be deleted

  const Category({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorHex,
    this.isArchived = false,
    this.isSystem = false,
  });

  Category copyWith({
    String? name,
    String? iconKey,
    String? colorHex,
    bool? isArchived,
  }) {
    return Category(
      id: id,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      colorHex: colorHex ?? this.colorHex,
      isArchived: isArchived ?? this.isArchived,
      isSystem: isSystem,
    );
  }
}

class CategoryInput {
  final String name;
  final String iconKey;
  final String colorHex;

  const CategoryInput({
    required this.name,
    required this.iconKey,
    required this.colorHex,
  });

  String? validate() {
    if (name.trim().isEmpty) return 'Category name is required';
    if (name.length > 50) return 'Name too long';
    return null;
  }
}

// ─── Filters ────────────────────────────────────────────────────────────────

class TransactionFilters {
  final String? searchQuery;
  final DateTime? fromDate;
  final DateTime? toDate;
  final String? accountId;
  final String? categoryId;
  final TransactionType? type;
  final ReviewStatus? reviewStatus;

  const TransactionFilters({
    this.searchQuery,
    this.fromDate,
    this.toDate,
    this.accountId,
    this.categoryId,
    this.type,
    this.reviewStatus,
  });

  TransactionFilters copyWith({
    String? searchQuery,
    DateTime? fromDate,
    DateTime? toDate,
    String? accountId,
    String? categoryId,
    TransactionType? type,
    ReviewStatus? reviewStatus,
  }) {
    return TransactionFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      reviewStatus: reviewStatus ?? this.reviewStatus,
    );
  }

  static const empty = TransactionFilters();
}

// ─── Analytics ───────────────────────────────────────────────────────────────

class MonthlyPeriod {
  final int year;
  final int month; // 1–12

  const MonthlyPeriod(this.year, this.month);

  factory MonthlyPeriod.now() {
    final d = DateTime.now();
    return MonthlyPeriod(d.year, d.month);
  }

  MonthlyPeriod previous() {
    if (month == 1) return MonthlyPeriod(year - 1, 12);
    return MonthlyPeriod(year, month - 1);
  }

  @override
  String toString() => '$year-${month.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is MonthlyPeriod && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

class MonthlySummary {
  final MonthlyPeriod period;
  final int totalIncomePaise;
  final int totalExpensePaise;
  final int transactionCount;

  const MonthlySummary({
    required this.period,
    required this.totalIncomePaise,
    required this.totalExpensePaise,
    required this.transactionCount,
  });

  int get netSavingsPaise => totalIncomePaise - totalExpensePaise;

  Money get totalIncome => Money(totalIncomePaise);
  Money get totalExpenses => Money(totalExpensePaise);
  Money get netSavings => Money(netSavingsPaise.abs());
  bool get isDeficit => netSavingsPaise < 0;
}

class CategoryBreakdownItem {
  final Category category;
  final int totalPaise;
  final int transactionCount;
  final double percentage; // 0.0–1.0

  const CategoryBreakdownItem({
    required this.category,
    required this.totalPaise,
    required this.transactionCount,
    required this.percentage,
  });

  Money get total => Money(totalPaise);
}

class SpendingTrendPoint {
  final MonthlyPeriod period;
  final int totalExpensePaise;

  const SpendingTrendPoint({
    required this.period,
    required this.totalExpensePaise,
  });

  Money get totalExpenses => Money(totalExpensePaise);
}

// ─── Result types ─────────────────────────────────────────────────────────────

/// Generic typed result; prevents raw exceptions reaching the UI.
sealed class Result<T> {
  const Result();
}

class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

class Failure<T> extends Result<T> {
  final AppError error;
  const Failure(this.error);
}

/// Typed error categories. Raw exception text never reaches the UI.
enum AppErrorKind {
  validation,
  notFound,
  duplicate,
  persistence,
  importFailure,
  exportFailure,
  unsupportedOperation,
  unknown,
}

class AppError {
  final AppErrorKind kind;
  final String userMessage;

  const AppError(this.kind, this.userMessage);

  static const unknown = AppError(AppErrorKind.unknown, 'An unexpected error occurred');

  @override
  String toString() => 'AppError($kind, $userMessage)';
}

