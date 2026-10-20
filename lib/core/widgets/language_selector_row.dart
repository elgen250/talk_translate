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

  const LanguageSelectorRow({
    super.key,
    required this.source,
    required this.target,
    required this.onSwap,
    required this.onSourceChanged,
    required this.onTargetChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildDropdown(source, onSourceChanged)),
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
        Expanded(child: _buildDropdown(target, onTargetChanged)),
      ],
    );
  }

  Widget _buildDropdown(
      AppLanguage current, ValueChanged<AppLanguage> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: cardDecoration(),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AppLanguage>(
          value: current,
          isDense: true,
          isExpanded: true,
          icon: const Icon(CupertinoIcons.chevron_down,
              size: 14, color: Color(0xFF8E9BAE)),
          items: supportedLanguages.map((lang) {
            return DropdownMenuItem(
              value: lang,
              child: Row(
                children: [
                  Text(lang.flag, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      lang.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
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

