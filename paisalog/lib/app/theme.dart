/// PaisaLog design tokens and theme.
library;

import 'package:flutter/material.dart';

// ─── Color Palette ──────────────────────────────────────────────────────────

class PaisaColors {
  // Brand
  static const primary = Color(0xFF1E6B5A); // Deep teal
  static const primaryLight = Color(0xFF2ECC9C);
  static const accent = Color(0xFFF59E0B); // Amber

  // Semantic
  static const income = Color(0xFF22C55E);
  static const expense = Color(0xFFEF4444);
  static const transfer = Color(0xFF94A3B8);
  static const review = Color(0xFFF59E0B);

  // Backgrounds (light)
  static const surfaceLight = Color(0xFFF8FAF9);
  static const cardLight = Color(0xFFFFFFFF);

  // Backgrounds (dark)
  static const surfaceDark = Color(0xFF0F1A16);
  static const cardDark = Color(0xFF1A2920);

  // Text
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textDisabled = Color(0xFFCBD5E1);

  // Category colors
  static const catFoodDining = Color(0xFFFF6B35);
  static const catShopping = Color(0xFFA855F7);
  static const catTransport = Color(0xFF3B82F6);
  static const catEntertainment = Color(0xFFEC4899);
  static const catUtilities = Color(0xFFF59E0B);
  static const catHealthcare = Color(0xFF10B981);
  static const catEducation = Color(0xFF06B6D4);
  static const catHousing = Color(0xFF8B5CF6);
}

// ─── Spacing ────────────────────────────────────────────────────────────────

class PaisaSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

// ─── Typography ─────────────────────────────────────────────────────────────

class PaisaTextStyles {
  static const _base = TextStyle(fontFamily: 'SF Pro Display');

  /// Large amount display: ₹1,234.56
  static const amountLarge = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.1,
  );

  static const amountMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );

  static const amountSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const screenTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static const sectionHeader = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static const body = TextStyle(fontSize: 15, fontWeight: FontWeight.w400);
  static const bodySmall = TextStyle(fontSize: 13, fontWeight: FontWeight.w400);
  static const caption = TextStyle(fontSize: 11, fontWeight: FontWeight.w400);

  static const label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );
}

// ─── Theme ──────────────────────────────────────────────────────────────────

class PaisaTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: PaisaColors.primary,
      brightness: brightness,
      surface: isDark ? PaisaColors.surfaceDark : PaisaColors.surfaceLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          isDark ? PaisaColors.surfaceDark : PaisaColors.surfaceLight,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: isDark ? PaisaColors.cardDark : PaisaColors.cardLight,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor:
            isDark ? PaisaColors.surfaceDark : PaisaColors.surfaceLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: PaisaTextStyles.screenTitle.copyWith(
          color: isDark ? Colors.white : PaisaColors.textPrimary,
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : PaisaColors.textPrimary,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:
            isDark ? PaisaColors.cardDark : PaisaColors.cardLight,
        indicatorColor: PaisaColors.primary.withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.all(
          PaisaTextStyles.label.copyWith(color: PaisaColors.primary),
        ),
        height: 72,
        elevation: 4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? PaisaColors.cardDark.withOpacity(0.5)
            : PaisaColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PaisaColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PaisaColors.expense, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: PaisaSpacing.md,
          vertical: PaisaSpacing.md,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PaisaColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: PaisaTextStyles.label.copyWith(fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PaisaColors.primary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: PaisaColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        showCheckmark: false,
      ),
      dividerTheme: const DividerThemeData(space: 1, thickness: 1),
      extensions: const [PaisaThemeExtension()],
    );
  }
}

/// Custom theme extension for PaisaLog-specific semantic colors.
class PaisaThemeExtension extends ThemeExtension<PaisaThemeExtension> {
  final Color incomeColor;
  final Color expenseColor;
  final Color transferColor;
  final Color reviewColor;

  const PaisaThemeExtension({
    this.incomeColor = PaisaColors.income,
    this.expenseColor = PaisaColors.expense,
    this.transferColor = PaisaColors.transfer,
    this.reviewColor = PaisaColors.review,
  });

  @override
  ThemeExtension<PaisaThemeExtension> copyWith({
    Color? incomeColor,
    Color? expenseColor,
    Color? transferColor,
    Color? reviewColor,
  }) {
    return PaisaThemeExtension(
      incomeColor: incomeColor ?? this.incomeColor,
      expenseColor: expenseColor ?? this.expenseColor,
      transferColor: transferColor ?? this.transferColor,
      reviewColor: reviewColor ?? this.reviewColor,
    );
  }

  @override
  ThemeExtension<PaisaThemeExtension> lerp(
    ThemeExtension<PaisaThemeExtension>? other,
    double t,
  ) {
    if (other is! PaisaThemeExtension) return this;
    return PaisaThemeExtension(
      incomeColor: Color.lerp(incomeColor, other.incomeColor, t)!,
      expenseColor: Color.lerp(expenseColor, other.expenseColor, t)!,
      transferColor: Color.lerp(transferColor, other.transferColor, t)!,
      reviewColor: Color.lerp(reviewColor, other.reviewColor, t)!,
    );
  }

  Color colorForType(String type) {
    switch (type) {
      case 'income': return incomeColor;
      case 'expense': return expenseColor;
      case 'transfer': return transferColor;
      default: return reviewColor;
    }
  }
}

