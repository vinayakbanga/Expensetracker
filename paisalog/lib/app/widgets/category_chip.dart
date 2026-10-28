/// Category chip / badge widget.
library;
import 'package:flutter/material.dart';
import '../../domain/models/models.dart';
import '../theme.dart';

class CategoryChip extends StatelessWidget {
  final Category? category;
  final bool compact;

  const CategoryChip({super.key, required this.category, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final cat = category;
    if (cat == null) {
      return _buildChip(
        context,
        icon: Icons.label_outline,
        label: 'Uncategorised',
        color: PaisaColors.textDisabled,
      );
    }
    final color = _hexColor(cat.colorHex);
    return _buildChip(
      context,
      icon: _iconData(cat.iconKey),
      label: cat.name,
      color: color,
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: (compact ? PaisaTextStyles.caption : PaisaTextStyles.label)
                .copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return PaisaColors.textSecondary;
    }
  }

  IconData _iconData(String key) => switch (key) {
        'restaurant' => Icons.restaurant,
        'shopping_bag' => Icons.shopping_bag,
        'directions_car' => Icons.directions_car,
        'movie' => Icons.movie,
        'bolt' => Icons.bolt,
        'local_hospital' => Icons.local_hospital,
        'school' => Icons.school,
        'home' => Icons.home,
        'payments' => Icons.payments,
        'swap_horiz' => Icons.swap_horiz,
        _ => Icons.label_outline,
      };
}

