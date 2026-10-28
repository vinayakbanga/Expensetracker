/// Drift database schema for PaisaLog.
///
/// All monetary columns are INTEGER (paise). Never REAL for money.
/// Run: dart run build_runner build --delete-conflicting-outputs
/// to generate the .g.dart companion file.
library;

import 'package:drift/drift.dart';

// ─── Tables ────────────────────────────────────────────────────────────────────

class AccountsTable extends Table {
  @override
  String get tableName => 'accounts';

  TextColumn get id => text()();
  TextColumn get nickname => text().withLength(min: 1, max: 100)();
  TextColumn get type => text()(); // AccountType enum value
  TextColumn get maskedIdentifier => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class CategoriesTable extends Table {
  @override
  String get tableName => 'categories';

  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get iconKey => text()();
  TextColumn get colorHex => text()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class TransactionsTable extends Table {
  @override
  String get tableName => 'transactions';

  TextColumn get id => text()();

  /// Paise — INTEGER ONLY. Enforced at Dart layer via Money class.
  IntColumn get amountPaise => integer()();

  TextColumn get currency =>
      text().withDefault(const Constant('INR')).withLength(min: 3, max: 3)();

  /// TransactionType enum value: income | expense | transfer | needsReview
  TextColumn get type => text()();

  /// TransactionDirection enum value: debit | credit | unknown
  TextColumn get direction => text()();

  TextColumn get merchantOrCounterparty => text().nullable()();

  DateTimeColumn get occurredAt => dateTime()();
  BoolColumn get occurredAtIsParsed => boolean().withDefault(const Constant(false))();

  /// Masked last 4 digits only. Never full account number.
  TextColumn get accountHint => text().nullable()();

  /// UPI ref / RRN / UTR for deduplication.
  TextColumn get referenceId => text().nullable()();

  /// TransactionSource enum value
  TextColumn get source => text()();

  /// SHA-256 fingerprint from derived safe fields. Not the raw SMS.
  TextColumn get sourceFingerprint => text().nullable()();

  TextColumn get parserRuleId => text().nullable()();

  /// ParseConfidence enum value
  TextColumn get confidence => text()();

  TextColumn get reviewReason => text().nullable()();

  TextColumn get categoryId => text().nullable()();
  TextColumn get transferGroupId => text().nullable()();

  /// ReviewStatus enum value
  TextColumn get reviewStatus => text()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class IngestionQueueTable extends Table {
  @override
  String get tableName => 'ingestion_queue';

  TextColumn get id => text()();

  /// SHA-256 fingerprint — NOT the raw SMS. Prevents reprocessing.
  TextColumn get fingerprint => text()();

  TextColumn get sender => text().nullable()();
  DateTimeColumn get receivedAt => dateTime()();

  /// processing_status: pending | processed | failed
  TextColumn get processingStatus =>
      text().withDefault(const Constant('pending'))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get processedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class UserCorrectionsTable extends Table {
  @override
  String get tableName => 'user_corrections';

  TextColumn get id => text()();
  TextColumn get transactionId => text()();
  TextColumn get fieldCorrected => text()(); // 'category', 'type', 'merchant'
  TextColumn get priorValue => text().nullable()();
  TextColumn get chosenValue => text()();

  /// Normalized merchant key used for future auto-categorization.
  TextColumn get merchantKey => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

