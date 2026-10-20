import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../camera_translate/camera_translate_view.dart';
import '../extras/extras_view.dart';
import '../talk_translate/talk_translate_view.dart';
import '../text_translate/text_translate_view.dart';

class MainNavigationScreen extends StatefulWidget {
  static final ValueNotifier<int> tabNotifier = ValueNotifier<int>(1);

  static void switchTo(int index) {
    tabNotifier.value = index;
  }

  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final List<Widget> _pages = const [
    TextTranslateView(),
    TalkTranslateView(),
    CameraTranslateView(),
    ExtrasView(),
  ];

  @override
  void initState() {
    super.initState();
    MainNavigationScreen.tabNotifier.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    MainNavigationScreen.tabNotifier.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = MainNavigationScreen.tabNotifier.value;
    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, -3),
            )
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, CupertinoIcons.chat_bubble_text, 'Text'),
              _buildNavItem(1, CupertinoIcons.waveform, 'Talk'),
              _buildNavItem(2, CupertinoIcons.viewfinder, 'Camera'),
              _buildNavItem(3, CupertinoIcons.square_grid_2x2, 'Extras'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = MainNavigationScreen.tabNotifier.value == index;
    return GestureDetector(
      onTap: () => MainNavigationScreen.switchTo(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: isSelected
            ? const EdgeInsets.symmetric(horizontal: 22, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? Colors.white : const Color(0xFF8E9BAE),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF8E9BAE),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
