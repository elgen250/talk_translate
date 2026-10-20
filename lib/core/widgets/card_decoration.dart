import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

BoxDecoration cardDecoration() {
  return BoxDecoration(
    color: AppColors.cardBg,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.03),
        blurRadius: 10,
        offset: const Offset(0, 4),
      )
    ],
  );
}

