/// PaisaLog Internal Service & Repository Contracts
///
/// These are typed Dart interfaces — NOT HTTP endpoints.
/// All implementations are injected via Riverpod.
/// Widgets MUST NOT depend on implementations directly.
library;

import '../models/models.dart';

// ─── Repository Interfaces ────────────────────────────────────────────────────

/// All transaction persistence operations.
/// Widgets call this via Riverpod providers, never raw SQL.
abstract class TransactionRepository {
  /// Returns transactions matching [filters], newest first.
  Future<List<Transaction>> getTransactions(TransactionFilters filters);

  /// Returns a single transaction by stable ID, or null if not found.
  Future<Transaction?> getTransaction(String id);

  /// Persists a new transaction from validated [input].
  /// Returns the created [Transaction] or a [Failure].
  Future<Result<Transaction>> addTransaction(TransactionInput input);

  /// Applies [changes] to an existing transaction.
  /// Returns the updated [Transaction] or a [Failure].
  Future<Result<Transaction>> updateTransaction(String id, TransactionInput changes);

  /// Hard-deletes a transaction after user confirmation.
  Future<Result<void>> deleteTransaction(String id);

  /// Returns the count of transactions in the pending-review queue.
  Future<int> getPendingReviewCount();

  /// Streams review-status changes for the pending count badge.
  Stream<int> watchPendingReviewCount();

  /// Streams all transactions matching [filters] (live updates).
  Stream<List<Transaction>> watchTransactions(TransactionFilters filters);
}

/// Account management.
abstract class AccountRepository {
  Future<List<Account>> listAccounts();

  Future<Account?> getAccount(String id);

  Future<Result<Account>> addAccount(AccountInput input);

  Future<Result<Account>> updateAccount(String id, AccountInput changes);

  /// Soft-deletes (archives) an account. Existing transactions are preserved.
  Future<Result<void>> archiveAccount(String id);

  Stream<List<Account>> watchAccounts();
}

/// Category management.
abstract class CategoryRepository {
  Future<List<Category>> listCategories();

  Future<Result<Category>> createCategory(CategoryInput input);

  Future<Result<Category>> updateCategory(String id, CategoryInput changes);

  /// System categories cannot be deleted. Archived categories remain on
  /// existing transactions.
  Future<Result<void>> archiveCategory(String id);

  Stream<List<Category>> watchCategories();
}

// ─── Service Interfaces ───────────────────────────────────────────────────────

/// SMS ingestion entry point.
/// NEVER logs or stores raw SMS text. Derived safe fields only.
abstract class SmsIngestionService {
  /// Process a single SMS message body plus metadata.
  ///
  /// Returns an [IngestionResult] describing what happened.
  /// On error, returns a typed [IngestionResult.failed] — never throws raw
  /// exceptions to the caller.
  Future<IngestionResult> processSms({
    required String text,
    required DateTime receivedAt,
    SmsSourceMetadata? sourceMetadata,
  });
}

/// Safe metadata about the SMS source. Does NOT include the raw body.
class SmsSourceMetadata {
  /// Sender address (e.g. 'HDFC-BK'). May be null.
  final String? sender;

  const SmsSourceMetadata({this.sender});
}

/// Result of attempting to ingest an SMS.
sealed class IngestionResult {
  const IngestionResult();
}

class IngestionAccepted extends IngestionResult {
  /// The created or existing (deduplicated) transaction.
  final Transaction transaction;
  final bool wasDuplicate;

  const IngestionAccepted({required this.transaction, this.wasDuplicate = false});
}

class IngestionRoutedToReview extends IngestionResult {
  final Transaction transaction;
  final String reason;

  const IngestionRoutedToReview({required this.transaction, required this.reason});
}

class IngestionIgnored extends IngestionResult {
  /// Why this message was ignored (OTP, promo, balance-only, etc.).
  final String reason;

  const IngestionIgnored({required this.reason});
}

class IngestionFailed extends IngestionResult {
  final AppError error;

  const IngestionFailed({required this.error});
}

// ─── Parser ──────────────────────────────────────────────────────────────────

/// Pure parsing contract. No I/O. Fully testable without Flutter.
abstract class TransactionParser {
  /// Parse [text] given optional [context] (sender, receive time).
  ///
  /// Returns:
  /// - [ParsedCandidate] when enough fields were extracted.
  /// - [ParseNeedsReview] when parsing succeeded partially but is ambiguous.
  /// - [ParseIgnored] when the message is not a transaction (OTP, promo, etc.)
  ParseResult parse(String text, ParseContext context);
}

class ParseContext {
  final String? sender;
  final DateTime receivedAt;

  const ParseContext({this.sender, required this.receivedAt});
}

sealed class ParseResult {
  const ParseResult();
}

class ParsedCandidate extends ParseResult {
  final int amountPaise;
  final TransactionType type;
  final TransactionDirection direction;
  final String? merchantOrCounterparty;
  final DateTime? occurredAt;
  final String? accountHint;
  final String? referenceId;
  final ParseConfidence confidence;
  final String? parserRuleId;

  const ParsedCandidate({
    required this.amountPaise,
    required this.type,
    required this.direction,
    this.merchantOrCounterparty,
    this.occurredAt,
    this.accountHint,
    this.referenceId,
    required this.confidence,
    this.parserRuleId,
  });
}

class ParseNeedsReview extends ParseResult {
  final String reason;

  /// Partial fields that were successfully extracted (may be null).
  final int? amountPaise;
  final TransactionDirection? direction;
  final String? accountHint;

  const ParseNeedsReview({
    required this.reason,
    this.amountPaise,
    this.direction,
    this.accountHint,
  });
}

class ParseIgnored extends ParseResult {
  final String reason;

  const ParseIgnored({required this.reason});
}

// ─── Deduplication ───────────────────────────────────────────────────────────

abstract class DeduplicationService {
  /// Search for an existing transaction that may be a duplicate of [candidate].
  /// Returns null if no match found.
  Future<DuplicateEvaluation> evaluate(ParsedCandidate candidate);
}

sealed class DuplicateEvaluation {
  const DuplicateEvaluation();
}

class DuplicateNotFound extends DuplicateEvaluation {
  const DuplicateNotFound();
}

class DuplicateFound extends DuplicateEvaluation {
  final Transaction existingTransaction;
  final double confidence; // 0.0–1.0; > 0.95 treated as definite

  const DuplicateFound({
    required this.existingTransaction,
    required this.confidence,
  });
}

class DuplicateUncertain extends DuplicateEvaluation {
  final Transaction candidate;
  final String reason;

  const DuplicateUncertain({required this.candidate, required this.reason});
}

// ─── Transfer Detection ───────────────────────────────────────────────────────

abstract class TransferDetectionService {
  /// Classify whether [candidate] represents an own-account transfer or
  /// credit-card bill payment, given [knownAccounts].
  ///
  /// Credit-card purchases are [TransferClassification.ordinaryTransaction].
  /// Only the bill payment leg is a [TransferClassification.transfer].
  TransferClassification classify(
    ParsedCandidate candidate,
    List<Account> knownAccounts,
  );
}

sealed class TransferClassification {
  const TransferClassification();
}

class OrdinaryTransaction extends TransferClassification {
  const OrdinaryTransaction();
}

class DetectedTransfer extends TransferClassification {
  final String? relatedAccountId;

  const DetectedTransfer({this.relatedAccountId});
}

class TransferNeedsReview extends TransferClassification {
  final String reason;

  const TransferNeedsReview({required this.reason});
}

// ─── Categorization ──────────────────────────────────────────────────────────

abstract class CategorizationService {
  /// Suggest a category for [candidate] based on merchant name and local rules.
  ///
  /// Returns a [CategorySuggestion] with a reason. Never claims certainty
  /// for uncertain matches.
  Future<CategorySuggestion> suggestCategory(ParsedCandidate candidate);

  /// Record a user correction so future messages from the same merchant
  /// can be categorized correctly.
  Future<void> recordCorrection({
    required String transactionId,
    required String newCategoryId,
    required String? merchantKey,
  });
}

class CategorySuggestion {
  /// Null if no suitable category was found.
  final String? categoryId;
  final String reason;
  final double confidence; // 0.0–1.0

  const CategorySuggestion({
    this.categoryId,
    required this.reason,
    required this.confidence,
  });
}

// ─── Analytics ───────────────────────────────────────────────────────────────

abstract class AnalyticsService {
  Future<MonthlySummary> getMonthlySummary(MonthlyPeriod period);

  Future<List<CategoryBreakdownItem>> getCategoryBreakdown(MonthlyPeriod period);

  Future<List<SpendingTrendPoint>> getSpendingTrend({
    required MonthlyPeriod from,
    required MonthlyPeriod to,
  });
}

// ─── Import / Export ─────────────────────────────────────────────────────────

abstract class ImportExportService {
  /// Export all matching transactions to CSV.
  /// [exportPath] is chosen by the caller (via file picker / share sheet).
  Future<Result<ExportSummary>> exportCsv(ExportOptions options);

  /// Parse and preview a CSV file before import.
  Future<Result<ImportPreview>> previewCsvImport(String filePath);

  /// Commit an import after user confirmation of the preview.
  Future<Result<ImportSummary>> commitCsvImport(ImportPreview preview);
}

class ExportOptions {
  final TransactionFilters filters;

  const ExportOptions({this.filters = TransactionFilters.empty});
}

class ExportSummary {
  final int rowsExported;
  final String filePath;

  const ExportSummary({required this.rowsExported, required this.filePath});
}

class ImportPreview {
  final String sourceFilePath;
  final List<TransactionInput> validRows;
  final List<ImportRowError> invalidRows;
  final List<TransactionInput> potentialDuplicates;

  const ImportPreview({
    required this.sourceFilePath,
    required this.validRows,
    required this.invalidRows,
    required this.potentialDuplicates,
  });

  int get totalRows => validRows.length + invalidRows.length;
}

class ImportRowError {
  final int rowIndex;
  final String reason;

  const ImportRowError({required this.rowIndex, required this.reason});
}

class ImportSummary {
  final int imported;
  final int skippedDuplicates;
  final int failed;

  const ImportSummary({
    required this.imported,
    required this.skippedDuplicates,
    required this.failed,
  });
}

// ─── Security ────────────────────────────────────────────────────────────────

abstract class SecurityService {
  /// Returns whether biometric / device authentication is available.
  Future<bool> isBiometricAvailable();

  /// Prompt the user to authenticate. Returns true on success.
  Future<bool> requestUnlock({String? reason});

  /// Lock the app immediately (e.g. on background).
  void lockApp();

  /// Whether the app is currently in locked state.
  bool get isLocked;

  Stream<bool> watchLocked();
}

