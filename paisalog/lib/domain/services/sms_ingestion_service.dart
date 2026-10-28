/// SmsIngestionService — wires parser → dedupe → transfer → categorize → persist.
library;

import '../models/models.dart';
import 'service_contracts.dart';
import 'domain_services.dart';

class DefaultSmsIngestionService implements SmsIngestionService {
  final TransactionParser parser;
  final DeduplicationService deduplicationService;
  final TransferDetectionService transferDetectionService;
  final CategorizationService categorizationService;
  final TransactionRepository repository;
  final AccountRepository accountRepository;

  const DefaultSmsIngestionService({
    required this.parser,
    required this.deduplicationService,
    required this.transferDetectionService,
    required this.categorizationService,
    required this.repository,
    required this.accountRepository,
  });

  @override
  Future<IngestionResult> processSms({
    required String text,
    required DateTime receivedAt,
    SmsSourceMetadata? sourceMetadata,
  }) async {
    // 1. Parse
    final context = ParseContext(
      sender: sourceMetadata?.sender,
      receivedAt: receivedAt,
    );

    final parseResult = parser.parse(text, context);

    switch (parseResult) {
      case ParseIgnored(:final reason):
        return IngestionIgnored(reason: reason);

      case ParseNeedsReview(:final reason, :final amountPaise, :final direction, :final accountHint):
        // Build a partial transaction for the review queue
        final tx = await _buildReviewTransaction(
          amountPaise: amountPaise,
          direction: direction,
          accountHint: accountHint,
          reason: reason,
          receivedAt: receivedAt,
        );
        final saveResult = await repository.addTransaction(
          TransactionInput(
            amountPaise: amountPaise ?? 0,
            type: TransactionType.needsReview,
            direction: direction ?? TransactionDirection.unknown,
            occurredAt: receivedAt,
          ),
        );
        switch (saveResult) {
          case Success(:final value):
            return IngestionRoutedToReview(transaction: value, reason: reason);
          case Failure(:final error):
            return IngestionFailed(error: error);
        }

      case ParsedCandidate():
        final candidate = parseResult;

        // 2. Deduplication check
        final dupeResult = await deduplicationService.evaluate(candidate);
        switch (dupeResult) {
          case DuplicateFound(:final existingTransaction):
            return IngestionAccepted(
              transaction: existingTransaction,
              wasDuplicate: true,
            );
          case DuplicateUncertain():
            // Route uncertain duplicates to review — never silently merge
            final tx = await _saveFromCandidate(
              candidate,
              receivedAt: receivedAt,
              overrideType: TransactionType.needsReview,
              reviewReason: 'possible_duplicate',
            );
            switch (tx) {
              case Success(:final value):
                return IngestionRoutedToReview(
                  transaction: value,
                  reason: 'possible_duplicate',
                );
              case Failure(:final error):
                return IngestionFailed(error: error);
            }
          case DuplicateNotFound():
            break; // proceed
        }

        // 3. Transfer detection
        final accounts = await accountRepository.listAccounts();
        final transferResult =
            transferDetectionService.classify(candidate, accounts);

        TransactionType resolvedType = candidate.type;
        switch (transferResult) {
          case DetectedTransfer():
            resolvedType = TransactionType.transfer;
          case TransferNeedsReview(:final reason):
            final tx = await _saveFromCandidate(
              candidate,
              receivedAt: receivedAt,
              overrideType: TransactionType.needsReview,
              reviewReason: reason,
            );
            switch (tx) {
              case Success(:final value):
                return IngestionRoutedToReview(transaction: value, reason: reason);
              case Failure(:final error):
                return IngestionFailed(error: error);
            }
          case OrdinaryTransaction():
            break; // use candidate.type
        }

        // 4. Categorization
        final suggestion = await categorizationService.suggestCategory(candidate);

        // 5. Save
        final saveResult = await _saveFromCandidate(
          candidate,
          receivedAt: receivedAt,
          overrideType: resolvedType,
          categoryId: suggestion.categoryId,
        );

        switch (saveResult) {
          case Success(:final value):
            return IngestionAccepted(transaction: value);
          case Failure(:final error):
            return IngestionFailed(error: error);
        }
    }
  }

  Future<Result<Transaction>> _saveFromCandidate(
    ParsedCandidate candidate, {
    required DateTime receivedAt,
    TransactionType? overrideType,
    String? reviewReason,
    String? categoryId,
  }) {
    final type = overrideType ?? candidate.type;
    final input = TransactionInput(
      amountPaise: candidate.amountPaise,
      type: type,
      direction: candidate.direction,
      merchantOrCounterparty: candidate.merchantOrCounterparty,
      occurredAt: candidate.occurredAt ?? receivedAt,
      categoryId: categoryId,
    );
    return repository.addTransaction(input);
  }

  Future<Transaction> _buildReviewTransaction({
    int? amountPaise,
    TransactionDirection? direction,
    String? accountHint,
    required String reason,
    required DateTime receivedAt,
  }) async {
    return Transaction(
      id: 'review_${receivedAt.millisecondsSinceEpoch}',
      amountPaise: amountPaise ?? 0,
      type: TransactionType.needsReview,
      direction: direction ?? TransactionDirection.unknown,
      occurredAt: receivedAt,
      accountHint: accountHint,
      source: TransactionSource.sms,
      confidence: ParseConfidence.low,
      reviewReason: reason,
      reviewStatus: ReviewStatus.pendingReview,
      createdAt: receivedAt,
      updatedAt: receivedAt,
    );
  }
}

