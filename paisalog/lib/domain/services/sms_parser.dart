/// PaisaLog SMS Parser — Pure Dart, no I/O, fully testable.
///
/// Rules are deterministic regex + classification logic.
/// Ambiguous cases return [ParseNeedsReview]; junk returns [ParseIgnored].
/// NEVER uses double for money arithmetic.
library;

import '../models/models.dart';
import 'service_contracts.dart';

// ─── Rule Registry ────────────────────────────────────────────────────────────

/// A named regex-based rule for a specific bank/sender family.
class SmsParserRule {
  final String id;
  final String description;

  /// Regex matching the sender name (case-insensitive).
  final RegExp senderPattern;

  /// Regex to extract amount from the body.
  final RegExp amountPattern;

  /// Regex to determine debit/credit direction.
  final RegExp? debitPattern;
  final RegExp? creditPattern;

  /// Regex to extract merchant or counterparty name.
  final RegExp? merchantPattern;

  /// Regex to extract bank/UPI reference ID.
  final RegExp? referencePattern;

  /// Regex to extract masked account hint (last 4 digits).
  final RegExp? accountHintPattern;

  /// Regexes that, if matched, indicate this message should be ignored.
  final List<RegExp> ignorePatterns;

  const SmsParserRule({
    required this.id,
    required this.description,
    required this.senderPattern,
    required this.amountPattern,
    this.debitPattern,
    this.creditPattern,
    this.merchantPattern,
    this.referencePattern,
    this.accountHintPattern,
    this.ignorePatterns = const [],
  });
}

// ─── Built-in Rules ───────────────────────────────────────────────────────────

/// Synthetic-safe rule set. Replace redacted patterns with actual bank
/// templates after testing on real (non-sensitive) messages.
final List<SmsParserRule> defaultParserRules = [
  // ── OTP / ignore guard (highest priority) ──
  SmsParserRule(
    id: 'IGNORE_OTP',
    description: 'One-time passwords — ignore',
    senderPattern: RegExp(r'.*', caseSensitive: false),
    amountPattern: RegExp(r'^\b$'), // impossible match
    ignorePatterns: [
      RegExp(r'\bOTP\b', caseSensitive: false),
      RegExp(r'\bone.?time.?pass', caseSensitive: false),
      RegExp(r'\bverification code\b', caseSensitive: false),
    ],
  ),

  // ── Promotional / ignore ──
  SmsParserRule(
    id: 'IGNORE_PROMO',
    description: 'Promotional messages — ignore',
    senderPattern: RegExp(r'.*', caseSensitive: false),
    amountPattern: RegExp(r'^\b$'),
    ignorePatterns: [
      RegExp(r'\boffer\b', caseSensitive: false),
      RegExp(r'\bcashback on shopping\b', caseSensitive: false),
      RegExp(r'\bcongratulations.*won\b', caseSensitive: false),
    ],
  ),

  // ── Balance-only ──
  SmsParserRule(
    id: 'IGNORE_BALANCE',
    description: 'Balance-only messages — ignore',
    senderPattern: RegExp(r'.*', caseSensitive: false),
    amountPattern: RegExp(r'^\b$'),
    ignorePatterns: [
      RegExp(
        r'(?:available|avl|bal(?:ance)?) (?:in|of) (?:a/c|acct|account) .{0,30} is (?:INR|Rs\.?|₹)',
        caseSensitive: false,
      ),
    ],
  ),

  // ── UPI payment (before generic debit) ──
  SmsParserRule(
    id: 'UPI_PAYMENT',
    description: 'UPI payment',
    senderPattern: RegExp(
      r'\b(?:SBIUPI|ICICIB|HDFCBK|AXISBK|KOTAKB|PAYTM|GPAY|PHONEPE|BHIM|SBI-UPI)\b',
      caseSensitive: false,
    ),
    amountPattern: RegExp(
      r'(?:INR|Rs\.?|₹)\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ),
    debitPattern: RegExp(
      r'\b(?:paid|payment|debited?|sent|spent|used|withdrawn|transferred?|transfer)\b',
      caseSensitive: false,
    ),
    creditPattern: RegExp(r'\b(?:received|credited?)\b', caseSensitive: false),
    referencePattern: RegExp(
      r'UPI\s*[Rr]ef(?:erence)?\s*(?:No\.?)?\s*[:\s]?([A-Z0-9_]{6,30})',
      caseSensitive: false,
    ),
    merchantPattern: RegExp(
      r'(?:to|at|towards)\s+([A-Z0-9][A-Z0-9 _\-&]{1,60}?)(?:\.|,|;|\s+on|\s+ref|\s+VPA|\s+UPI)',
      caseSensitive: false,
    ),
    accountHintPattern: RegExp(
      r'(?:a/c|acct|account|card)\s*(?:no\.?\s*)?[xX*]{0,8}(\d{4})',
      caseSensitive: false,
    ),
    ignorePatterns: [],
  ),

  // ── Generic debit rule ──
  SmsParserRule(
    id: 'GENERIC_DEBIT',
    description: 'Generic bank debit',
    senderPattern: RegExp(r'.*', caseSensitive: false),
    amountPattern: RegExp(
      r'(?:INR|Rs\.?|₹)\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ),
    debitPattern: RegExp(
      r'\b(?:debited?|withdrawn?|spent|paid|payment|purchase|debit|transferred?|transfer)\b',
      caseSensitive: false,
    ),
    creditPattern: RegExp(
      r'\b(?:credited?|received|deposited?|refund)\b',
      caseSensitive: false,
    ),
    merchantPattern: RegExp(
      r'(?:at|to|towards)\s+([A-Z0-9][A-Z0-9 _\-&]{1,60}?)(?:\.|,|;|\s+(?:on|ref|txn|upi|amt))',
      caseSensitive: false,
    ),
    referencePattern: RegExp(
      r'(?:ref(?:erence)?(?:\s*no\.?)?|rrn|utr|txn\s*id)[:\s#]*([A-Z0-9_]{6,30})',
      caseSensitive: false,
    ),
    accountHintPattern: RegExp(
      r'(?:a/c|acct|account|card)\s*(?:no\.?\s*)?[xX*]{0,8}(\d{4})',
      caseSensitive: false,
    ),
  ),

  // ── Credit-card purchase ──
  SmsParserRule(
    id: 'CC_PURCHASE',
    description: 'Credit card purchase — expense',
    senderPattern: RegExp(r'.*', caseSensitive: false),
    amountPattern: RegExp(
      r'(?:INR|Rs\.?|₹)\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ),
    debitPattern: RegExp(
      r'\b(?:spent|purchase(?:d)?|used\s+(?:at|for)|debited?|charged|swiped)\b',
      caseSensitive: false,
    ),
    merchantPattern: RegExp(
      r'(?:at|for|towards)\s+([A-Z0-9][A-Z0-9 _\-&]{1,60}?)(?:\.|,|\s+on|\s+ref)',
      caseSensitive: false,
    ),
    referencePattern: RegExp(
      r'(?:ref|txn)[:\s]([A-Z0-9]{6,30})',
      caseSensitive: false,
    ),
    accountHintPattern: RegExp(
      r'[Cc]ard\s*[xX*]{0,8}(\d{4})',
      caseSensitive: false,
    ),
    ignorePatterns: [
      // Bill payment towards OWN card is a transfer, handled separately
      RegExp(
        r'(?:payment.*(?:towards|to|for|received).*credit\s*card|credit\s*card.*bill.*payment)',
        caseSensitive: false,
      ),
    ],
  ),

  // ── Credit-card bill payment (transfer) ──
  SmsParserRule(
    id: 'CC_BILL_PAYMENT',
    description: 'Credit card bill payment — transfer, not expense',
    senderPattern: RegExp(r'.*', caseSensitive: false),
    amountPattern: RegExp(
      r'(?:INR|Rs\.?|₹)\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ),
    debitPattern: RegExp(r'.*', caseSensitive: false), // match any
    ignorePatterns: [],
    // Note: parser sets type=transfer for this rule; no further debit/credit needed.
  ),
];

// ─── Parser Implementation ────────────────────────────────────────────────────

class DefaultTransactionParser implements TransactionParser {
  final List<SmsParserRule> rules;

  const DefaultTransactionParser({List<SmsParserRule>? rules})
      : rules = rules ?? const [];

  factory DefaultTransactionParser.withDefaults() {
    return DefaultTransactionParser(rules: defaultParserRules);
  }

  @override
  ParseResult parse(String text, ParseContext context) {
    final normalised = _normalise(text);
    final sender = context.sender ?? '';

    // 1. Check ignore rules first (OTP, promo, balance-only)
    for (final ignoreId in ['IGNORE_OTP', 'IGNORE_PROMO', 'IGNORE_BALANCE']) {
      final rule = _ruleById(ignoreId);
      if (rule == null) continue;
      for (final pattern in rule.ignorePatterns) {
        if (pattern.hasMatch(normalised)) {
          return ParseIgnored(reason: rule.description);
        }
      }
    }

    // 2. Credit-card bill payment (must be before generic debit)
    final ccBillRule = _ruleById('CC_BILL_PAYMENT');
    if (ccBillRule != null && _isCcBillPayment(normalised)) {
      final amount = _extractAmount(normalised, ccBillRule);
      if (amount == null) {
        return const ParseNeedsReview(reason: 'CC bill payment detected but no_amount');
      }
      return ParsedCandidate(
        amountPaise: amount,
        type: TransactionType.transfer,
        direction: TransactionDirection.debit,
        confidence: ParseConfidence.high,
        parserRuleId: 'CC_BILL_PAYMENT',
        accountHint: _extractGroup(normalised, ccBillRule.accountHintPattern),
        referenceId: _extractGroup(normalised, ccBillRule.referencePattern),
        merchantOrCounterparty: 'CREDIT_CARD_BILL',
      );
    }

    // 3. Apply remaining rules in order
    final candidateRules = rules.where((r) =>
        r.id != 'IGNORE_OTP' &&
        r.id != 'IGNORE_PROMO' &&
        r.id != 'IGNORE_BALANCE' &&
        r.id != 'CC_BILL_PAYMENT' &&
        (r.senderPattern.hasMatch(sender) ||
            r.senderPattern.pattern == '.*'));

    for (final rule in candidateRules) {
      // Check rule-specific ignore patterns
      final shouldIgnore = rule.ignorePatterns.any((p) => p.hasMatch(normalised));
      if (shouldIgnore) continue;

      final amount = _extractAmount(normalised, rule);
      if (amount == null) continue;

      final direction = _extractDirection(normalised, rule);
      if (direction == TransactionDirection.unknown) {
        // Try other rules before concluding direction is unknown
        continue;
      }

      final merchant = _extractGroup(normalised, rule.merchantPattern);
      final ref = _extractGroup(normalised, rule.referencePattern);
      final acct = _extractGroup(normalised, rule.accountHintPattern);

      final type = _classifyType(rule.id, direction, normalised);

      return ParsedCandidate(
        amountPaise: amount,
        type: type,
        direction: direction,
        merchantOrCounterparty: merchant,
        occurredAt: null, // TODO: date extraction in v2
        accountHint: acct,
        referenceId: ref,
        confidence: _confidence(amount, direction, merchant),
        parserRuleId: rule.id,
      );
    }

    // 4. Fallback: check if an amount was detected but no rule could fully classify
    final fallbackAmount = _extractFallbackAmount(normalised);
    if (fallbackAmount != null) {
      final acctMatch = RegExp(
        r'(?:a/c|acct|account|card)\s*(?:no\.?\s*)?[xX*]{0,8}(\d{4})',
        caseSensitive: false,
      ).firstMatch(normalised);

      return ParseNeedsReview(
        reason: 'unsupported_template',
        amountPaise: fallbackAmount,
        accountHint: acctMatch?.group(1),
      );
    }

    return const ParseIgnored(reason: 'no_financial_content');
  }

  int? _extractFallbackAmount(String text) {
    final match = RegExp(
      r'(?:INR|Rs\.?|₹)\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null || match.groupCount < 1) return null;
    final raw = match.group(1)!.replaceAll(',', '');
    final parts = raw.split('.');
    final rupees = int.tryParse(parts[0]);
    if (rupees == null) return null;
    int paise = rupees * 100;
    if (parts.length == 2 && parts[1].isNotEmpty) {
      final paiseStr = parts[1].padRight(2, '0').substring(0, 2);
      final paiseVal = int.tryParse(paiseStr);
      if (paiseVal != null) paise += paiseVal;
    }
    return paise > 0 ? paise : null;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _normalise(String text) =>
      text.replaceAll(RegExp(r'[\u00A0\u200B]'), ' ').trim();

  SmsParserRule? _ruleById(String id) {
    try {
      return rules.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  bool _isCcBillPayment(String text) {
    return RegExp(
      r'(?:payment.*(?:towards|to|for|received).*credit\s*card|credit\s*card.*bill.*payment)',
      caseSensitive: false,
    ).hasMatch(text);
  }

  /// Extract amount in paise without using double arithmetic.
  /// Parse rupees and paise separately as integers.
  int? _extractAmount(String text, SmsParserRule rule) {
    final match = rule.amountPattern.firstMatch(text);
    if (match == null || match.groupCount < 1) return null;
    final raw = match.group(1)!.replaceAll(',', '');
    final parts = raw.split('.');
    final rupees = int.tryParse(parts[0]);
    if (rupees == null) return null;
    int paise = rupees * 100;
    if (parts.length == 2 && parts[1].isNotEmpty) {
      final paiseStr = parts[1].padRight(2, '0').substring(0, 2);
      final paiseVal = int.tryParse(paiseStr);
      if (paiseVal == null) return null;
      paise += paiseVal;
    }
    return paise > 0 ? paise : null;
  }

  TransactionDirection _extractDirection(String text, SmsParserRule rule) {
    if (rule.debitPattern != null && rule.debitPattern!.hasMatch(text)) {
      return TransactionDirection.debit;
    }
    if (rule.creditPattern != null && rule.creditPattern!.hasMatch(text)) {
      return TransactionDirection.credit;
    }
    return TransactionDirection.unknown;
  }

  String? _extractGroup(String text, RegExp? pattern) {
    if (pattern == null) return null;
    final match = pattern.firstMatch(text);
    if (match == null || match.groupCount < 1) return null;
    return match.group(1)?.trim();
  }

  TransactionType _classifyType(
    String ruleId,
    TransactionDirection direction,
    String text,
  ) {
    if (ruleId == 'CC_BILL_PAYMENT') return TransactionType.transfer;
    if (RegExp(
      r'\b(?:own\s+account|self\s+transfer|between\s+(?:own\s+)?accounts|transfer\s+to\s+own|transferred.*own|transfer.*own)\b',
      caseSensitive: false,
    ).hasMatch(text)) {
      return TransactionType.transfer;
    }
    if (direction == TransactionDirection.credit) {
      if (RegExp(r'\b(?:salary|sal|payroll)\b', caseSensitive: false).hasMatch(text)) {
        return TransactionType.income;
      }
      if (RegExp(r'\b(?:refund|reversal|cashback)\b', caseSensitive: false).hasMatch(text)) {
        return TransactionType.income;
      }
      return TransactionType.income;
    }
    return TransactionType.expense;
  }

  ParseConfidence _confidence(int amount, TransactionDirection dir, String? merchant) {
    if (dir == TransactionDirection.unknown) return ParseConfidence.low;
    if (merchant == null) return ParseConfidence.medium;
    return ParseConfidence.high;
  }
}

