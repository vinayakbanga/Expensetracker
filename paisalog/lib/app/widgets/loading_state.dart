/// Full-screen loading indicator.
library;
import 'package:flutter/material.dart';
import '../theme.dart';

class LoadingState extends StatelessWidget {
  final String? message;
  const LoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            strokeWidth: 2.5,
            color: PaisaColors.primary,
          ),
          if (message != null) ...[
            const SizedBox(height: PaisaSpacing.md),
            Text(
              message!,
              style: PaisaTextStyles.bodySmall.copyWith(
                color: PaisaColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

