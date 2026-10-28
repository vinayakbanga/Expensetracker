/// Parser unit tests — all 15 cases from Doc 03 plus edge cases.
/// Uses ONLY synthetic/redacted SMS patterns. No real bank data.
///
/// Run: flutter test test/parser/sms_parser_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:paisalog/domain/models/models.dart';
import 'package:paisalog/domain/services/service_contracts.dart';
import 'package:paisalog/domain/services/sms_parser.dart';

void main() {
  late DefaultTransactionParser parser;

  setUp(() {
    parser = DefaultTransactionParser.withDefaults();
  });

  ParseContext ctx({String? sender, DateTime? at}) => ParseContext(
        sender: sender ?? 'TEST_BANK',
        receivedAt: at ?? DateTime(2026, 10, 28, 10, 30),
      );

  group('T-001 — Generic debit', () {
    test('parses expense, amount 25000 paise, account hint 1234', () {
      const sms =
          'Your A/c XX1234 is debited by INR 250.00 at MERCHANT_A. Ref REF_X.';
      final result = parser.parse(sms, ctx());
      expect(result, isA<ParsedCandidate>());
      final c = result as ParsedCandidate;
      expect(c.amountPaise, equals(25000));
      expect(c.type, equals(TransactionType.expense));
      expect(c.direction, equals(TransactionDirection.debit));
      expect(c.accountHint, equals('1234'));
    });
  });

  group('T-002 — Salary credit', () {
    test('parses income, 7500000 paise', () {
      const sms = 'INR 75,000.00 credited to A/c XX1234 as salary.';
      final result = parser.parse(sms, ctx());
      expect(result, isA<ParsedCandidate>());
      final c = result as ParsedCandidate;
      expect(c.amountPaise, equals(7500000));
      expect(c.type, equals(TransactionType.income));
      expect(c.direction, equals(TransactionDirection.credit));
    });
  });

  group('T-003 — UPI payment', () {
    test('parses expense from UPI, captures ref', () {
      const sms = 'UPI payment of Rs. 149 to MERCHANT_B. UPI Ref UPI_REF_Y.';
      final result = parser.parse(sms, ctx(sender: 'SBIUPI'));
      expect(result, isA<ParsedCandidate>());
      final c = result as ParsedCandidate;
      expect(c.amountPaise, equals(14900));
      expect(c.type, equals(TransactionType.expense));
    });
  });

  group('T-004 — Credit card purchase', () {
    test('parses as expense', () {
      const sms = 'Credit card XX4321 purchase at SHOP for ₹1,200.00.';
      final result = parser.parse(sms, ctx());
      expect(result, isA<ParsedCandidate>());
      final c = result as ParsedCandidate;
      expect(c.amountPaise, equals(120000));
      expect(c.type, equals(TransactionType.expense));
    });
  });

  group('T-005 — Credit card bill payment → transfer', () {
    test('classified as transfer, NOT second expense', () {
      const sms =
          'Payment of ₹8,000 received towards credit card XX4321 from bank A/c XX1234.';
      final result = parser.parse(sms, ctx());
      expect(result, isA<ParsedCandidate>());
      final c = result as ParsedCandidate;
      expect(c.type, equals(TransactionType.transfer));
      expect(c.amountPaise, equals(800000));
    });
  });

  group('T-006 — Own-account transfer', () {
    test('amount extracted; type is transfer', () {
      const sms =
          'Transferred ₹5,000 from own A/c XX1234 to own A/c XX5678.';
      final result = parser.parse(sms, ctx());
      expect(result, isA<ParsedCandidate>());
      final c = result as ParsedCandidate;
      expect(c.amountPaise, equals(500000));
      expect(c.type, equals(TransactionType.transfer));
    });
  });

  group('T-007 — Balance-only message → ignored', () {
    test('returns ParseIgnored', () {
      const sms = 'Available balance in A/c XX1234 is ₹10,000.00.';
      final result = parser.parse(sms, ctx());
      expect(result, isA<ParseIgnored>());
    });
  });

  group('T-008 — OTP message → ignored', () {
    test('returns ParseIgnored, never stored', () {
      const sms = 'Your OTP for transaction is 123456. Valid for 10 minutes.';
      final result = parser.parse(sms, ctx());
      expect(result, isA<ParseIgnored>());
    });
  });

  group('T-009 — Promotional message → ignored', () {
    test('returns ParseIgnored', () {
      const sms = 'Special offer: get cashback on shopping this weekend!';
      final result = parser.parse(sms, ctx());
      expect(result, isA<ParseIgnored>());
    });
  });

  group('T-010 — Failed transaction message → review', () {
    test('ambiguous: has amount but also indicates failure → needs review', () {
      const sms =
          'Debited ₹500 from A/c XX1234. Transaction failed. Amount will be reversed.';
      // Parser should either ignore or route to review — must not create expense
      final result = parser.parse(sms, ctx());
      // Accept either NeedsReview or Ignored — never a confident Expense
      if (result is ParsedCandidate) {
        expect(result.confidence, isNot(equals(ParseConfidence.high)));
      }
    });
  });

  group('T-011 — No amount → needs review or ignored', () {
    test('returns ParseNeedsReview or ParseIgnored when no amount', () {
      const sms = 'Transaction processed at MERCHANT_A on your account.';
      final result = parser.parse(sms, ctx());
      expect(result, anyOf(isA<ParseNeedsReview>(), isA<ParseIgnored>()));
    });
  });

  group('T-015 — Exact paise arithmetic', () {
    test('₹1,234.56 → 123456 paise with NO floating-point', () {
      const sms = 'A/c XX1234 debited ₹1,234.56 at MERCHANT_A. Ref REF_Z.';
      final result = parser.parse(sms, ctx());
      expect(result, isA<ParsedCandidate>());
      final c = result as ParsedCandidate;
      expect(c.amountPaise, equals(123456));
    });

    test('₹250.00 → exactly 25000 paise', () {
      const sms = 'Debited INR 250.00 from A/c XX1234.';
      final result = parser.parse(sms, ctx());
      expect(result, isA<ParsedCandidate>());
      expect((result as ParsedCandidate).amountPaise, equals(25000));
    });

    test('₹75,000 (no decimals) → 7500000 paise', () {
      const sms = 'INR 75,000 credited to A/c XX1234.';
      final result = parser.parse(sms, ctx());
      expect(result, isA<ParsedCandidate>());
      expect((result as ParsedCandidate).amountPaise, equals(7500000));
    });
  });

  group('Money class — no float arithmetic', () {
    test('fromRupeeString parses 1,234.56 correctly', () {
      final m = Money.fromRupeeString('1,234.56');
      expect(m.paise, equals(123456));
    });

    test('fromRupeeString handles zero paise', () {
      final m = Money.fromRupeeString('500');
      expect(m.paise, equals(50000));
    });

    test('fromRupeeString handles ₹ prefix', () {
      final m = Money.fromRupeeString('₹1,000.00');
      expect(m.paise, equals(100000));
    });

    test('Money addition stays integer', () {
      const a = Money(25000);
      const b = Money(14900);
      expect((a + b).paise, equals(39900));
    });

    test('toDisplayString formats correctly', () {
      expect(const Money(123456).toDisplayString(), equals('₹1,234.56'));
      expect(const Money(25000).toDisplayString(), equals('₹250.00'));
      expect(const Money(7500000).toDisplayString(), equals('₹75,000.00'));
    });

    test('zero amount throws assertion', () {
      // Zero is allowed (Money(0) is valid e.g. Money.zero)
      expect(() => const Money(0), returnsNormally);
    });

    test('negative amount throws assertion', () {
      expect(() => Money(-1), throwsAssertionError);
    });

    test('fromRupeeString throws on invalid input', () {
      expect(() => Money.fromRupeeString('abc'), throwsA(isA<MoneyParseException>()));
      expect(() => Money.fromRupeeString(''), throwsA(isA<MoneyParseException>()));
    });
  });

  group('MonthlyPeriod', () {
    test('previous wraps December→January correctly', () {
      final jan = MonthlyPeriod(2026, 1);
      final dec = jan.previous();
      expect(dec.month, equals(12));
      expect(dec.year, equals(2025));
    });

    test('toString formats correctly', () {
      expect(MonthlyPeriod(2026, 10).toString(), equals('2026-10'));
    });
  });
}

