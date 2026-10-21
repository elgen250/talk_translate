import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/app_language.dart';
import '../theme/app_colors.dart';
import 'card_decoration.dart';

class LanguageSelectorRow extends StatelessWidget {
  final AppLanguage source;
  final AppLanguage target;
  final VoidCallback onSwap;
  final ValueChanged<AppLanguage> onSourceChanged;
  final ValueChanged<AppLanguage> onTargetChanged;
  final bool allowAutoDetect;

  const LanguageSelectorRow({
    super.key,
    required this.source,
    required this.target,
    required this.onSwap,
    required this.onSourceChanged,
    required this.onTargetChanged,
    this.allowAutoDetect = false,
  });

  @override
  Widget build(BuildContext context) {
    final sourceOptions = allowAutoDetect
        ? [autoDetectLanguage, ...supportedLanguages]
        : supportedLanguages;

    return Row(
      children: [
        Expanded(child: _buildDropdown(source, onSourceChanged, sourceOptions, isSource: true)),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onSwap,
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.arrow_right_arrow_left,
                color: Colors.white, size: 16),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _buildDropdown(target, onTargetChanged, supportedLanguages, isSource: false)),
      ],
    );
  }

  Widget _buildDropdown(
    AppLanguage current,
    ValueChanged<AppLanguage> onChanged,
    List<AppLanguage> options, {
    required bool isSource,
  }) {
    // Ensure current language is valid within the options list
    final safeCurrent = options.contains(current) ? current : options.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: cardDecoration(),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AppLanguage>(
          value: safeCurrent,
          isDense: true,
          isExpanded: true,
          icon: const Icon(CupertinoIcons.chevron_down,
              size: 14, color: Color(0xFF8E9BAE)),
          items: options.map((lang) {
            final isAuto = lang.isAuto;
            return DropdownMenuItem(
              value: lang,
              child: Row(
                children: [
                  Text(lang.flag, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isAuto ? 'Auto Detect' : lang.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: isAuto ? FontWeight.bold : FontWeight.w600,
                        fontSize: 13,
                        color: isAuto ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (isAuto)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'AI',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }
}
