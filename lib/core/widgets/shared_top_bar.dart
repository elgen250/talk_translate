import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../../shared/pro_sheet.dart';

class SharedTopBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onSettingsTap;

  const SharedTopBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Row(
          children: [
            GestureDetector(
              onTap: () => showProSheet(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  children: [
                    Icon(CupertinoIcons.star_fill,
                        color: Colors.white, size: 14),
                    SizedBox(width: 5),
                    Text(
                      'Pro',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onSettingsTap,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: const Icon(CupertinoIcons.gear_solid,
                    size: 19, color: AppColors.primaryDark),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

