import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../features/keyboard/keyboard_translator_screen.dart';
import '../features/navigation/main_navigation_screen.dart';
import '../features/offline_mode/offline_mode_screen.dart';

void showProSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5B84A6), Color(0xFF3B82F6)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(CupertinoIcons.sparkles,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Talk Translate PRO',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary),
                  ),
                  Text(
                    'All 5 Premium Features Unlocked ✨',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF22C55E)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Explore each unlocked Pro feature below. Tap any card to open and use it immediately:',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),

          // Feature 1: Camera Translator
          _proFeatureCard(
            context: ctx,
            icon: CupertinoIcons.camera_viewfinder,
            color: Colors.deepPurple,
            title: 'Camera OCR Translator',
            description:
                'Point your camera at signs, menus or labels, or pick any photo to translate on-device in seconds.',
            buttonText: 'Open Camera',
            onAction: () {
              Navigator.pop(ctx);
              MainNavigationScreen.switchTo(2);
            },
          ),

          // Feature 2: Keyboard Translator
          _proFeatureCard(
            context: ctx,
            icon: CupertinoIcons.keyboard,
            color: Colors.blueAccent,
            title: 'Keyboard Translator',
            description:
                'Live in-app translation bar and quick phrases to translate and type in any messaging app.',
            buttonText: 'Try Keyboard',
            onAction: () {
              Navigator.pop(ctx);
              Navigator.push(
                ctx,
                CupertinoPageRoute(
                    builder: (_) => const KeyboardTranslatorScreen()),
              );
            },
          ),

          // Feature 3: Smart Context & Tones
          _proFeatureCard(
            context: ctx,
            icon: CupertinoIcons.chat_bubble_text_fill,
            color: Colors.indigo,
            title: 'Smart Context & AI Tones',
            description:
                'Adaptive tone translation (Formal, Casual, Business) and smart alternative phrasings.',
            buttonText: 'Open Smart Text',
            onAction: () {
              Navigator.pop(ctx);
              MainNavigationScreen.switchTo(0);
            },
          ),

          // Feature 4: Offline Neural Models
          _proFeatureCard(
            context: ctx,
            icon: CupertinoIcons.wifi_slash,
            color: Colors.teal,
            title: '100% Offline Mode',
            description:
                'Download language packs (~30MB) and translate text, voice, and signs without any internet connection.',
            buttonText: 'Manage Offline Packs',
            onAction: () {
              Navigator.pop(ctx);
              Navigator.push(
                ctx,
                CupertinoPageRoute(builder: (_) => const OfflineModeScreen()),
              );
            },
          ),

          // Feature 5: Dual Split-Screen Talk
          _proFeatureCard(
            context: ctx,
            icon: CupertinoIcons.waveform_path,
            color: Colors.orange,
            title: 'Dual Face-to-Face Voice Talk',
            description:
                'Split-screen two-way conversation mode. Inverted screen allows two people to talk naturally across a table.',
            buttonText: 'Start Voice Talk',
            onAction: () {
              Navigator.pop(ctx);
              MainNavigationScreen.switchTo(1);
            },
          ),

          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}

Widget _proFeatureCard({
  required BuildContext context,
  required IconData icon,
  required Color color,
  required String title,
  required String description,
  required String buttonText,
  required VoidCallback onAction,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: onAction,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        buttonText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(CupertinoIcons.chevron_right,
                          color: Colors.white, size: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
