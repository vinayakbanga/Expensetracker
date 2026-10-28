/// Banner shown when there are pending-review items.
library;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';

class ReviewBanner extends StatelessWidget {
  final int count;

  const ReviewBanner({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    final ext = Theme.of(context).extension<PaisaThemeExtension>()!;

    return GestureDetector(
      onTap: () => context.push('/review'),
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: PaisaSpacing.md,
          vertical: PaisaSpacing.sm,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: PaisaSpacing.md,
          vertical: PaisaSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: ext.reviewColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ext.reviewColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.pending_actions, color: ext.reviewColor, size: 20),
            const SizedBox(width: PaisaSpacing.sm),
            Expanded(
              child: Text(
                '$count transaction${count == 1 ? '' : 's'} ${count == 1 ? 'needs' : 'need'} your review',
                style: PaisaTextStyles.bodySmall.copyWith(
                  color: ext.reviewColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: ext.reviewColor, size: 18),
          ],
        ),
      ),
    );
  }
}

