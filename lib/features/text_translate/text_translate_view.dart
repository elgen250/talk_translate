import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/app_language.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/card_decoration.dart';
import '../../core/widgets/language_selector_row.dart';
import '../../core/widgets/shared_top_bar.dart';
import '../../data/app_database.dart';
import '../../data/translation_service.dart';
import '../../shared/settings_modal.dart';

class TextTranslateView extends StatefulWidget {
  const TextTranslateView({super.key});

  @override
  State<TextTranslateView> createState() => _TextTranslateViewState();
}

class _TextTranslateViewState extends State<TextTranslateView> {
  final TextEditingController _textController = TextEditingController();
  Timer? _debounce;
  AppLanguage _sourceLang = supportedLanguages[0]; // English
  AppLanguage _targetLang = supportedLanguages[10]; // Arabic
  String _translatedText = '';
  bool _isTranslating = false;
  bool _isFavorited = false;

  // PRO Feature: Smart Tone Selection
  String _selectedTone = 'Natural';
  final List<Map<String, dynamic>> _tones = [
    {'name': 'Natural', 'icon': CupertinoIcons.sparkles, 'tag': 'natural'},
    {'name': 'Formal', 'icon': CupertinoIcons.briefcase, 'tag': 'formal'},
    {'name': 'Casual', 'icon': CupertinoIcons.chat_bubble_2, 'tag': 'casual'},
    {'name': 'Business', 'icon': CupertinoIcons.building_2_fill, 'tag': 'business'},
  ];

  List<String> _smartAlternatives = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _translatedText = '';
        _smartAlternatives.clear();
        _isFavorited = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), _translate);
  }

  Future<void> _translate() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isTranslating = true);

    final res = await TranslationService.instance.translate(
      text: text,
      fromCode: _sourceLang.code,
      toCode: _targetLang.code,
      mode: 'text',
    );

    if (!mounted) return;

    // Generate Smart Context Alternatives for PRO
    final alternatives = _generateSmartAlternatives(res, _selectedTone);

    setState(() {
      _translatedText = res;
      _smartAlternatives = alternatives;
      _isTranslating = false;
      _isFavorited = false;
    });
  }

  List<String> _generateSmartAlternatives(String baseTranslation, String tone) {
    if (baseTranslation.isEmpty) return [];
    if (_targetLang.code == 'ar') {
      switch (tone) {
        case 'Formal':
          return [
            'بكل تقدير: $baseTranslation',
            'الصيغة الرسمية: يُرجى التكرم بالعلم أن $baseTranslation',
          ];
        case 'Casual':
          return [
            'باللهجة الودية: $baseTranslation يا غالي',
            'صيغة محادثة سريعة: $baseTranslation',
          ];
        case 'Business':
          return [
            'الصيغة المهنية: نود إحاطتكم بأن $baseTranslation',
            'صيغة المراسلات: برجاء التكرم بمراجعة: $baseTranslation',
          ];
        default:
          return [
            'صيغة بديلة مختصرة: $baseTranslation',
          ];
      }
    } else {
      switch (tone) {
        case 'Formal':
          return [
            'Respectfully: $baseTranslation, if it pleases you.',
            'Kindly note that: $baseTranslation.',
          ];
        case 'Casual':
          return [
            'Casual: Hey, $baseTranslation!',
            'Quick note: Just so you know, $baseTranslation.',
          ];
        case 'Business':
          return [
            'Professional: Please be advised that $baseTranslation.',
            'Executive summary: Regarding our correspondence, $baseTranslation.',
          ];
        default:
          return [
            'Alternative phrasing: $baseTranslation',
          ];
      }
    }
  }

  void _swapLanguages() {
    setState(() {
      final temp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = temp;
      if (_translatedText.isNotEmpty) {
        _textController.text = _translatedText;
        _translatedText = '';
        _smartAlternatives.clear();
        _translate();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SharedTopBar(
                title: 'Text',
                subtitle: 'Smart AI & Context Translation',
                onSettingsTap: () => showSettingsModal(context),
              ),
              const SizedBox(height: 16),
              LanguageSelectorRow(
                source: _sourceLang,
                target: _targetLang,
                onSwap: _swapLanguages,
                onSourceChanged: (l) {
                  setState(() => _sourceLang = l);
                  _translate();
                },
                onTargetChanged: (l) {
                  setState(() => _targetLang = l);
                  _translate();
                },
              ),
              const SizedBox(height: 12),

              // PRO Smart Tone Selector
              Row(
                children: [
                  const Text(
                    'TONE:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _tones.map((t) {
                          final isSelected = _selectedTone == t['name'];
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              avatar: Icon(
                                t['icon'] as IconData,
                                size: 14,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.primary,
                              ),
                              label: Text(t['name'] as String),
                              selected: isSelected,
                              selectedColor: AppColors.primary,
                              backgroundColor: Colors.white,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                              onSelected: (_) {
                                setState(() => _selectedTone = t['name'] as String);
                                if (_translatedText.isNotEmpty) {
                                  _translate();
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Source Input Card
              Container(
                height: 215,
                padding: const EdgeInsets.all(16),
                decoration: cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _sourceLang.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (_textController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _textController.clear();
                                _translatedText = '';
                                _smartAlternatives.clear();
                              });
                            },
                            child: const Icon(CupertinoIcons.xmark_circle_fill,
                                size: 18, color: AppColors.textHint),
                          ),
                      ],
                    ),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        maxLines: null,
                        maxLength: 5000,
                        buildCounter: (context,
                                {required currentLength,
                                required isFocused,
                                maxLength}) =>
                            null,
                        onChanged: _onTextChanged,
                        style: const TextStyle(
                            fontSize: 17, color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Type or paste text to translate...',
                          hintStyle: TextStyle(
                            color: AppColors.textHint,
                            fontSize: 17,
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${_textController.text.length} / 5000',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textHint),
                        ),
                        const Spacer(),
                        _circleIconBtn(
                          icon: CupertinoIcons.doc_on_clipboard,
                          onTap: () async {
                            final data =
                                await Clipboard.getData(Clipboard.kTextPlain);
                            if (data?.text != null) {
                              _textController.text = data!.text!;
                              _onTextChanged(data.text!);
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        _circleIconBtn(
                          icon: CupertinoIcons.speaker_2_fill,
                          onTap: () => TranslationService.instance.speak(
                              _textController.text, _sourceLang.speechCode),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isTranslating ? null : _translate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _textController.text.isEmpty
                                ? const Color(0xFFEDF1F7)
                                : AppColors.primary,
                            foregroundColor: _textController.text.isEmpty
                                ? AppColors.textHint
                                : Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                          ),
                          child: _isTranslating
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Translate',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Target Output Card
              Container(
                height: 220,
                padding: const EdgeInsets.all(16),
                decoration: cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _targetLang.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$_selectedTone Tone',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          _translatedText.isEmpty
                              ? 'Translation will appear here'
                              : _translatedText,
                          style: TextStyle(
                            fontSize: 18,
                            color: _translatedText.isEmpty
                                ? AppColors.textHint
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(CupertinoIcons.speaker_2,
                              size: 20, color: AppColors.textHint),
                          onPressed: () => TranslationService.instance
                              .speak(_translatedText, _targetLang.speechCode),
                        ),
                        IconButton(
                          icon: const Icon(CupertinoIcons.doc_on_doc,
                              size: 20, color: AppColors.textHint),
                          onPressed: () {
                            if (_translatedText.isEmpty) return;
                            Clipboard.setData(
                                ClipboardData(text: _translatedText));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Copied to clipboard')),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            _isFavorited
                                ? CupertinoIcons.heart_fill
                                : CupertinoIcons.heart,
                            size: 20,
                            color: _isFavorited
                                ? Colors.redAccent
                                : AppColors.textHint,
                          ),
                          onPressed: () {
                            if (_translatedText.isEmpty) return;
                            setState(() => _isFavorited = !_isFavorited);
                            if (AppDatabase.instance.history.isNotEmpty) {
                              AppDatabase.instance.toggleFavorite(
                                  AppDatabase.instance.history.first.id);
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(CupertinoIcons.share,
                              size: 20, color: AppColors.textHint),
                          onPressed: () {
                            if (_translatedText.isNotEmpty) {
                              Clipboard.setData(
                                  ClipboardData(text: _translatedText));
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // PRO Smart Context Alternatives Card
              if (_smartAlternatives.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(CupertinoIcons.sparkles,
                              color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Smart Context Alternatives (PRO)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._smartAlternatives.map((alt) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  alt,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  setState(() => _translatedText = alt);
                                  Clipboard.setData(ClipboardData(text: alt));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Alternative applied and copied!')),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Use',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleIconBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Color(0xFFEAF0F6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 17, color: AppColors.primary),
      ),
    );
  }
}
