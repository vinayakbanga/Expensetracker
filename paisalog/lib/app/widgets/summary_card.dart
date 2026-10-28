/// Summary stat card used on the Home screen.
library;
import 'package:flutter/material.dart';
import '../../domain/models/models.dart';
import '../theme.dart';
import 'amount_display.dart';

class SummaryCard extends StatelessWidget {
  final String label;
  final int paise;
  final TransactionType type;
  final bool isLoading;

  const SummaryCard({
    super.key,
    required this.label,
    required this.paise,
    required this.type,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PaisaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: PaisaTextStyles.sectionHeader.copyWith(
                color: PaisaColors.textSecondary,
              ),
            ),
            const SizedBox(height: PaisaSpacing.sm),
            if (isLoading)
              const _ShimmerBox(width: 100, height: 28)
            else
              AmountDisplay(
                paise: paise,
                type: type,
                style: PaisaTextStyles.amountLarge,
              ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;

  const _ShimmerBox({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

