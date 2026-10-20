import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../data/app_database.dart';
import '../data/translation_service.dart';

void showSettingsModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) {
        final currentGender = AppDatabase.instance.ttsVoiceGender;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Settings & AI Voice',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.xmark_circle_fill,
                          color: AppColors.textHint, size: 24),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 1. AI Voice Gender Selection (Male vs Female)
                const Text(
                  'AI Speaker Voice (صوت المتحدث الذكي)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Male Voice Option
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setModalState(() {
                            AppDatabase.instance.setTtsVoiceGender('male');
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: currentGender == 'male'
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: currentGender == 'male'
                                  ? AppColors.primary
                                  : Colors.grey.shade300,
                              width: currentGender == 'male' ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text('👨', style: TextStyle(fontSize: 28)),
                              const SizedBox(height: 6),
                              Text(
                                'Male Voice',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: currentGender == 'male'
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const Text(
                                'صوت رجل عميق',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Female Voice Option
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setModalState(() {
                            AppDatabase.instance.setTtsVoiceGender('female');
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: currentGender == 'female'
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: currentGender == 'female'
                                  ? AppColors.primary
                                  : Colors.grey.shade300,
                              width: currentGender == 'female' ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text('👩', style: TextStyle(fontSize: 28)),
                              const SizedBox(height: 6),
                              Text(
                                'Female Voice',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: currentGender == 'female'
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const Text(
                                'صوت امرأة واضح',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Test Voice Button
                Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(CupertinoIcons.play_circle_fill,
                        color: AppColors.primary, size: 20),
                    label: Text(
                      currentGender == 'male'
                          ? 'استمع لتجربة صوت الرجل (Test Voice)'
                          : 'استمع لتجربة صوت المرأة (Test Voice)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    onPressed: () {
                      final sample = currentGender == 'male'
                          ? 'أهلاً بك، تم ضبط صوت المتحدث للرجل بنجاح. Welcome to Talk Translate.'
                          : 'أهلاً بك، تم ضبط صوت المتحدث للمرأة بنجاح. Welcome to Talk Translate.';
                      TranslationService.instance.speak(sample, 'ar-SA');
                    },
                  ),
                ),


                // 3. Simulate Offline Mode Switch
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(CupertinoIcons.wifi_slash,
                        color: Colors.amber, size: 22),
                  ),
                  title: const Text(
                    'Simulate Offline Mode Only',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary),
                  ),
                  subtitle: const Text(
                    'Test local dictionary & cached translations without internet',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  value: AppDatabase.instance.forceOfflineMode,
                  onChanged: (val) {
                    setModalState(
                        () => AppDatabase.instance.forceOfflineMode = val);
                  },
                ),

                // 4. Clear History & Cache
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(CupertinoIcons.trash,
                        color: Colors.redAccent, size: 20),
                  ),
                  title: const Text(
                    'Clear Offline Cache & History',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.redAccent),
                  ),
                  onTap: () {
                    AppDatabase.instance.clearHistory();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('History & offline cache cleared'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    ),
  );
}

