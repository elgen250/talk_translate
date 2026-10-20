import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/card_decoration.dart';
import '../../core/widgets/shared_top_bar.dart';
import '../../shared/settings_modal.dart';
import '../history/history_screen.dart';
import '../keyboard/keyboard_translator_screen.dart';
import '../learn/learn_teacher_screen.dart';
import '../offline_mode/offline_mode_screen.dart';

class ExtrasView extends StatelessWidget {
  const ExtrasView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SharedTopBar(
                title: 'Extras',
                subtitle: 'More tools for you',
                onSettingsTap: () => showSettingsModal(context),
              ),
              const SizedBox(height: 24),
              _buildMenuCard(
                icon: CupertinoIcons.book_fill,
                title: 'Learn',
                subtitle: 'Your personal teacher',
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                        builder: (_) => const LearnTeacherScreen()),
                  );
                },
              ),
              const SizedBox(height: 14),
              _buildMenuCard(
                icon: CupertinoIcons.keyboard,
                title: 'Keyboard Translator',
                subtitle: 'Translate while typing in any app',
                isPro: true,
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                        builder: (_) => const KeyboardTranslatorScreen()),
                  );
                },
              ),
              const SizedBox(height: 14),
              _buildMenuCard(
                icon: CupertinoIcons.globe,
                title: 'Offline Mode',
                subtitle: 'Download languages to translate without internet',
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                        builder: (_) => const OfflineModeScreen()),
                  );
                },
              ),
              const SizedBox(height: 14),
              _buildMenuCard(
                icon: CupertinoIcons.time,
                title: 'History',
                subtitle: 'All your saved Text and Talk translations',
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (_) => const HistoryScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    bool isLocked = false,
    bool isPro = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF6E8CA7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (isPro) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                      if (isLocked) ...[
                        const SizedBox(width: 6),
                        const Icon(CupertinoIcons.lock_fill,
                            size: 14, color: Color(0xFF6E8CA7)),
                      ]
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8E9BAE),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_right,
                size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

