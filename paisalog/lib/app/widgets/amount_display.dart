/// Reusable amount display widget. Always shows integer paise, never double.
library;
import 'package:flutter/material.dart';
import '../../domain/models/models.dart';
import '../theme.dart';

/// Displays a monetary amount with correct sign and color.
/// [paise] — integer paise value (always positive; sign comes from [type]).
class AmountDisplay extends StatelessWidget {
  final int paise;
  final TransactionType type;
  final TextStyle? style;
  final bool showSign;

  const AmountDisplay({
    super.key,
    required this.paise,
    required this.type,
    this.style,
    this.showSign = true,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<PaisaThemeExtension>()!;
    final color = switch (type) {
      TransactionType.income => ext.incomeColor,
      TransactionType.expense => ext.expenseColor,
      TransactionType.transfer => ext.transferColor,
      TransactionType.needsReview => ext.reviewColor,
    };
    final sign = showSign
        ? switch (type) {
            TransactionType.income => '+',
            TransactionType.expense => '−',
            _ => '',
          }
        : '';
    final text = '$sign${Money(paise).toDisplayString()}';
    return Text(
      text,
      style: (style ?? PaisaTextStyles.amountMedium).copyWith(color: color),
    );
  }
}

