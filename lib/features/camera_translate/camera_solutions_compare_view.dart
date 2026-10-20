import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/app_language.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/language_selector_row.dart';
import '../../core/widgets/shared_top_bar.dart';
import '../../data/translation_service.dart';
import '../../shared/settings_modal.dart';

/// Represents a recognized and translated text segment with its visual bounding box.
class OcrTranslatedItem {
  final String id;
  final String originalText;
  final String translatedText;
  final Rect boundingBox;
  final bool isNoise;

  OcrTranslatedItem({
    required this.id,
    required this.originalText,
    required this.translatedText,
    required this.boundingBox,
    this.isNoise = false,
  });

  OcrTranslatedItem copyWith({
    String? originalText,
    String? translatedText,
    Rect? boundingBox,
    bool? isNoise,
  }) {
    return OcrTranslatedItem(
      id: id,
      originalText: originalText ?? this.originalText,
      translatedText: translatedText ?? this.translatedText,
      boundingBox: boundingBox ?? this.boundingBox,
      isNoise: isNoise ?? this.isNoise,
    );
  }
}

/// The available visual rendering solutions for comparison.
enum CameraSolutionMode {
  smartLens,        // الحل 1: التراكب الذكي مع التنقية ودمج الفقرات
  interactiveSheet, // الحل 2: التحديد التفاعلي الهادئ وقائمة سفلية
  readerList,       // الحل 3: قائمة المستند المنظمة للقراءة والنسخ
  rawBaseline,      // الوضع الحالي: للمقارنة المباشرة قبل وبعد
}

/// A dedicated comparison widget implementing all 3 OCR solutions with independent toggle buttons.
class CameraSolutionsCompareView extends StatefulWidget {
  const CameraSolutionsCompareView({super.key});

  @override
  State<CameraSolutionsCompareView> createState() => _CameraSolutionsCompareViewState();
}

class _CameraSolutionsCompareViewState extends State<CameraSolutionsCompareView> {
  CameraSolutionMode _activeMode = CameraSolutionMode.smartLens;

  AppLanguage _sourceLang = supportedLanguages[1]; // French default
  AppLanguage _targetLang = supportedLanguages[0]; // English default

  Uint8List? _imageBytes;
  ui.Image? _decodedImage;
  
  // Stored items for both granular raw mode and merged smart mode
  List<OcrTranslatedItem> _rawItems = [];
  List<OcrTranslatedItem> _mergedItems = [];
  
  bool _isProcessing = false;
  bool _showOriginal = false;
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadSamplePreset();
  }

  /// Preset demo data reflecting a scanned real-world document/menu
  Future<void> _loadSamplePreset() async {
    final sampleItems = [
      OcrTranslatedItem(
        id: '1',
        originalText: "Café au lait - 4.50€",
        translatedText: "Coffee with milk - €4.50",
        boundingBox: const Rect.fromLTWH(36, 90, 290, 42),
      ),
      OcrTranslatedItem(
        id: '2',
        originalText: "Sortie de secours\nNe pas encombrer le passage",
        translatedText: "Emergency Exit\nDo not obstruct the passage",
        boundingBox: const Rect.fromLTWH(36, 150, 320, 68),
      ),
      OcrTranslatedItem(
        id: '3',
        originalText: "Menu du jour servi avec salade",
        translatedText: "Daily special served with salad",
        boundingBox: const Rect.fromLTWH(36, 235, 310, 44),
      ),
      OcrTranslatedItem(
        id: '4',
        originalText: "Merci de votre visite et à bientôt",
        translatedText: "Thank you for your visit, see you soon",
        boundingBox: const Rect.fromLTWH(36, 295, 330, 44),
      ),
    ];

    setState(() {
      _rawItems = sampleItems;
      _mergedItems = sampleItems;
    });
  }

  /// Heuristic noise detector to weed out keyboard keys, single letters, and UI artifacts
  bool _isNoiseOrKeyboardArtifact(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return true;

    // Filter pure numbers or long dates (e.g. 80404738, 2026/05/3)
    final numClean = clean.replaceAll(RegExp(r'[\/\-\:\.\s,\$€£%#]'), '');
    if (double.tryParse(numClean) != null && numClean.length > 3) return true;

    // Filter isolated single characters (keyboard keys like G, X, 1, 8) unless allowed valid words
    if (clean.length == 1) {
      const allowedSingleChars = {'a', 'i', 'y', 'à', 'و', '&', '+'};
      if (!allowedSingleChars.contains(clean.toLowerCase())) return true;
    }

    // Filter common on-screen keyboard keys and shortcuts
    final lower = clean.toLowerCase();
    const keyboardKeys = {
      'gif', 'esc', 'tab', 'caps', 'shift', 'ctrl', 'alt', 'fn', 'enter',
      'del', 'backspace', 'home', 'end', 'pgup', 'pgdn', 'prtscn',
      'df', 'hj k', 'gh', 'asdf', 'qwerty', 'zxcv', 'une s',
    };
    if (keyboardKeys.contains(lower)) return true;

    // Pure symbols/punctuation without letters or digits
    if (RegExp(r'^[^a-zA-Z0-9\u0600-\u06FF\u4E00-\u9FFF\u3040-\u30FF\uAC00-\uD7AF]+$').hasMatch(clean)) {
      return true;
    }

    return false;
  }

  /// Capture image from Camera or Pick from Gallery
  Future<void> _pickAndProcessImage(bool useCamera) async {
    final XFile? image = await _picker.pickImage(
      source: useCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 90,
    );

    if (image == null) return;

    setState(() {
      _isProcessing = true;
      _rawItems.clear();
      _mergedItems.clear();
    });

    try {
      final bytes = await image.readAsBytes();
      final uiImage = await _decodeImage(bytes);

      if (kIsWeb) {
        setState(() {
          _imageBytes = bytes;
          _decodedImage = uiImage;
          _isProcessing = false;
        });
        _processWebFallbackText();
        return;
      }

      // Native Mobile OCR using Google ML Kit
      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

      try {
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

        // 1. Extract Raw Lines (Unfiltered, baseline)
        final List<({String id, String text, Rect box, bool isNoise})> extractedLines = [];
        int lineCounter = 0;

        // 2. Extract Smart Merged Paragraphs
        final List<({String id, String text, Rect box})> smartBlocks = [];

        for (final block in recognizedText.blocks) {
          final List<TextLine> validBlockLines = [];

          for (final line in block.lines) {
            lineCounter++;
            final text = line.text.trim();
            final isNoise = _isNoiseOrKeyboardArtifact(text);
            
            extractedLines.add((
              id: 'raw_$lineCounter',
              text: text,
              box: line.boundingBox,
              isNoise: isNoise,
            ));

            if (!isNoise) {
              validBlockLines.add(line);
            }
          }

          // If block has valid text lines, merge nearby lines into coherent paragraph units
          if (validBlockLines.isNotEmpty) {
            // Calculate combined bounding box
            double minL = double.infinity, minT = double.infinity;
            double maxR = -double.infinity, maxB = -double.infinity;

            final combinedWords = <String>[];
            for (final vl in validBlockLines) {
              combinedWords.add(vl.text.trim());
              if (vl.boundingBox.left < minL) minL = vl.boundingBox.left;
              if (vl.boundingBox.top < minT) minT = vl.boundingBox.top;
              if (vl.boundingBox.right > maxR) maxR = vl.boundingBox.right;
              if (vl.boundingBox.bottom > maxB) maxB = vl.boundingBox.bottom;
            }

            final combinedText = combinedWords.join('\n');
            if (combinedText.trim().isNotEmpty) {
              smartBlocks.add((
                id: 'block_${smartBlocks.length + 1}',
                text: combinedText,
                box: Rect.fromLTRB(minL, minT, maxR, maxB),
              ));
            }
          }
        }

        // 3. Batch Translate Smart Blocks (Fast, high-quality full sentence context)
        final List<OcrTranslatedItem> tempMerged = [];
        const batchSize = 10;
        for (var i = 0; i < smartBlocks.length; i += batchSize) {
          final end = (i + batchSize < smartBlocks.length) ? i + batchSize : smartBlocks.length;
          final batch = smartBlocks.sublist(i, end);

          final results = await Future.wait(
            batch.map((item) async {
              try {
                final translated = await TranslationService.instance.translate(
                  text: item.text,
                  fromCode: _sourceLang.code,
                  toCode: _targetLang.code,
                  mode: 'camera',
                );
                return OcrTranslatedItem(
                  id: item.id,
                  originalText: item.text,
                  translatedText: translated.isNotEmpty ? translated : item.text,
                  boundingBox: item.box,
                );
              } catch (_) {
                return OcrTranslatedItem(
                  id: item.id,
                  originalText: item.text,
                  translatedText: item.text,
                  boundingBox: item.box,
                );
              }
            }),
          );
          tempMerged.addAll(results);
        }

        // 4. Batch Translate Raw Items (For comparison baseline)
        final List<OcrTranslatedItem> tempRaw = [];
        for (var i = 0; i < extractedLines.length; i += batchSize) {
          final end = (i + batchSize < extractedLines.length) ? i + batchSize : extractedLines.length;
          final batch = extractedLines.sublist(i, end);

          final results = await Future.wait(
            batch.map((item) async {
              try {
                final translated = await TranslationService.instance.translate(
                  text: item.text,
                  fromCode: _sourceLang.code,
                  toCode: _targetLang.code,
                  mode: 'camera',
                );
                return OcrTranslatedItem(
                  id: item.id,
                  originalText: item.text,
                  translatedText: translated.isNotEmpty ? translated : item.text,
                  boundingBox: item.box,
                  isNoise: item.isNoise,
                );
              } catch (_) {
                return OcrTranslatedItem(
                  id: item.id,
                  originalText: item.text,
                  translatedText: item.text,
                  boundingBox: item.box,
                  isNoise: item.isNoise,
                );
              }
            }),
          );
          tempRaw.addAll(results);
        }

        if (!mounted) return;
        setState(() {
          _imageBytes = bytes;
          _decodedImage = uiImage;
          _rawItems = tempRaw;
          _mergedItems = tempMerged;
          _isProcessing = false;
        });
      } finally {
        await textRecognizer.close();
      }
    } catch (e) {
      debugPrint('OCR Error: $e');
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to process image: $e')),
      );
    }
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(bytes, (ui.Image img) {
      completer.complete(img);
    });
    return completer.future;
  }

  void _processWebFallbackText() async {
    const sampleText = "Café au lait - 4.50€\nSortie de secours\nRefresh Data";
    final translated = await TranslationService.instance.translate(
      text: sampleText,
      fromCode: _sourceLang.code,
      toCode: _targetLang.code,
      mode: 'camera',
    );
    final fallbackItem = OcrTranslatedItem(
      id: 'web_1',
      originalText: sampleText,
      translatedText: translated,
      boundingBox: const Rect.fromLTWH(40, 100, 300, 90),
    );
    setState(() {
      _rawItems = [fallbackItem];
      _mergedItems = [fallbackItem];
    });
  }

  /// High-Resolution Image Export & Share
  Future<void> _saveAndShareTranslatedImage() async {
    try {
      RenderRepaintBoundary boundary = _repaintBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/translated_comparison.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([XFile(file.path)], text: 'Translated via Talk & Translate OCR');
    } catch (e) {
      debugPrint('Share error: $e');
    }
  }

  /// Bottom Sheet for Solution 2 (Interactive Focus & Bottom Sheet)
  void _showDetailBottomSheet(BuildContext context, OcrTranslatedItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Grab Handle
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

                // Header with Mode 2 indicator
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.sparkles, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Smart Recognition',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Source Text Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(_sourceLang.flag, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(
                            _sourceLang.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.originalText,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Translated Text Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.readyBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.readyGreen.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(_targetLang.flag, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(
                            _targetLang.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.readyGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.translatedText,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F5132),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Action Buttons: Listen & Copy
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          TranslationService.instance.speak(
                            item.translatedText,
                            _targetLang.speechCode,
                          );
                        },
                        icon: const Icon(CupertinoIcons.speaker_2_fill, size: 18),
                        label: const Text('Listen'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: item.translatedText));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied translation to clipboard!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(CupertinoIcons.doc_on_clipboard, size: 18),
                        label: const Text('Copy'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              SharedTopBar(
                title: 'Camera Solutions Lab',
                subtitle: 'Test & compare OCR algorithms live',
                onSettingsTap: () => showSettingsModal(context),
              ),
              const SizedBox(height: 10),

              // Language Selector Row
              LanguageSelectorRow(
                source: _sourceLang,
                target: _targetLang,
                onSwap: () {
                  setState(() {
                    final temp = _sourceLang;
                    _sourceLang = _targetLang;
                    _targetLang = temp;
                  });
                },
                onSourceChanged: (l) => setState(() => _sourceLang = l),
                onTargetChanged: (l) => setState(() => _targetLang = l),
              ),
              const SizedBox(height: 10),

              // Solution Selector Switcher: Dedicated buttons for each solution
              _buildSolutionsControlBar(),
              const SizedBox(height: 10),

              // Main Canvas / Content Area
              Expanded(
                child: _activeMode == CameraSolutionMode.readerList
                    ? _buildReaderListMode()
                    : _buildCanvasViewfinder(),
              ),

              const SizedBox(height: 12),

              // Bottom Action Controls
              _buildBottomActionButtons(),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  /// Dedicated multi-button bar allowing instant toggle between all 3 solutions + baseline
  Widget _buildSolutionsControlBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Button 1: Smart Lens (Merged + Clean)
          Expanded(
            child: _buildModeTabButton(
              mode: CameraSolutionMode.smartLens,
              title: '1. Smart Lens',
              subtitle: 'دمج وتنقية',
              icon: CupertinoIcons.sparkles,
            ),
          ),
          const SizedBox(width: 4),

          // Button 2: Interactive Focus & Sheet
          Expanded(
            child: _buildModeTabButton(
              mode: CameraSolutionMode.interactiveSheet,
              title: '2. Focus & Sheet',
              subtitle: 'تحديد وقائمة',
              icon: CupertinoIcons.viewfinder_circle_fill,
            ),
          ),
          const SizedBox(width: 4),

          // Button 3: Reader List Mode
          Expanded(
            child: _buildModeTabButton(
              mode: CameraSolutionMode.readerList,
              title: '3. Reader List',
              subtitle: 'قائمة مقروءة',
              icon: CupertinoIcons.list_bullet_below_rectangle,
            ),
          ),
          const SizedBox(width: 4),

          // Button 4: Baseline Raw (For immediate side-by-side comparison)
          Expanded(
            child: _buildModeTabButton(
              mode: CameraSolutionMode.rawBaseline,
              title: 'Raw Base',
              subtitle: 'الوضع السابق',
              icon: CupertinoIcons.exclamationmark_triangle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTabButton({
    required CameraSolutionMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final bool isSelected = _activeMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeMode = mode;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.primary : Colors.grey.shade600,
            ),
            const SizedBox(height: 3),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                color: isSelected ? AppColors.textPrimary : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Viewfinder Container for Canvas-based solutions (Smart Lens, Interactive Sheet, Raw Baseline)
  Widget _buildCanvasViewfinder() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // RepaintBoundary for high-res snapshot
            RepaintBoundary(
              key: _repaintBoundaryKey,
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Center(
                  child: _imageBytes == null
                      ? _buildPlaceholderScene()
                      : _buildImageWithActiveSolutionOverlays(),
                ),
              ),
            ),

            // Processing Indicator
            if (_isProcessing)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 12),
                      Text(
                        'AI OCR & Smart Clustering...',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),

            // Top-Right Hold-To-View Original Button
            if (_imageBytes != null && !_isProcessing)
              Positioned(
                top: 14,
                right: 14,
                child: GestureDetector(
                  onTapDown: (_) => setState(() => _showOriginal = true),
                  onTapUp: (_) => setState(() => _showOriginal = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showOriginal ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _showOriginal ? 'Original Image' : 'Hold for Original',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Current Mode Badge Overlay at Top-Left
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  _getModeBadgeLabel(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getModeBadgeLabel() {
    switch (_activeMode) {
      case CameraSolutionMode.smartLens:
        return 'Mode 1: Smart Filtered Lens';
      case CameraSolutionMode.interactiveSheet:
        return 'Mode 2: Tap to Focus & Sheet';
      case CameraSolutionMode.readerList:
        return 'Mode 3: Document Reader';
      case CameraSolutionMode.rawBaseline:
        return 'Baseline: Unfiltered Overlays';
    }
  }

  /// Placeholder when no image is captured yet
  Widget _buildPlaceholderScene() {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.camera_viewfinder, size: 64, color: Colors.white54),
          const SizedBox(height: 14),
          const Text(
            'Multi-Solution Camera Lab',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Take a photo or choose from gallery. You can then toggle all 3 solutions live on the exact same image to compare results.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => _pickAndProcessImage(true),
            icon: const Icon(CupertinoIcons.camera_fill, size: 18),
            label: const Text('Capture Live Photo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Main dynamic overlay rendering according to the selected mode
  Widget _buildImageWithActiveSolutionOverlays() {
    if (_imageBytes == null || _decodedImage == null) return Container();

    return LayoutBuilder(
      builder: (context, constraints) {
        final imgWidth = _decodedImage!.width.toDouble();
        final imgHeight = _decodedImage!.height.toDouble();

        final double widgetWidth = constraints.maxWidth;
        final double widgetHeight = constraints.maxHeight;

        final double scaleX = widgetWidth / imgWidth;
        final double scaleY = widgetHeight / imgHeight;
        final double scale = scaleX < scaleY ? scaleX : scaleY;

        final double renderedWidth = imgWidth * scale;
        final double renderedHeight = imgHeight * scale;

        final double offsetX = (widgetWidth - renderedWidth) / 2;
        final double offsetY = (widgetHeight - renderedHeight) / 2;

        final itemsToRender = (_activeMode == CameraSolutionMode.rawBaseline)
            ? _rawItems
            : _mergedItems;

        return SizedBox(
          width: widgetWidth,
          height: widgetHeight,
          child: Stack(
            children: [
              // 1. Base Image
              Center(
                child: Image.memory(
                  _imageBytes!,
                  fit: BoxFit.contain,
                ),
              ),

              // 2. Overlays rendered dynamically according to the chosen solution
              if (!_showOriginal)
                ...itemsToRender.map((item) {
                  final rect = item.boundingBox;
                  final double left = offsetX + (rect.left * scale);
                  final double top = offsetY + (rect.top * scale);
                  final double width = rect.width * scale;
                  final double height = rect.height * scale;

                  final safeLeft = left < 0 ? 0.0 : left;
                  final safeTop = top < 0 ? 0.0 : top;
                  final safeWidth = width < 45 ? 45.0 : width;
                  final safeHeight = height < 22 ? 22.0 : height;

                  if (_activeMode == CameraSolutionMode.smartLens) {
                    return _buildSmartLensOverlay(item, safeLeft, safeTop, safeWidth, safeHeight);
                  } else if (_activeMode == CameraSolutionMode.interactiveSheet) {
                    return _buildInteractiveFocusOverlay(item, safeLeft, safeTop, safeWidth, safeHeight);
                  } else {
                    return _buildRawBaselineOverlay(item, safeLeft, safeTop, safeWidth, safeHeight);
                  }
                }),
            ],
          ),
        );
      },
    );
  }

  /// Solution 1: Smart Filtered & Frosted Lens
  Widget _buildSmartLensOverlay(
    OcrTranslatedItem item,
    double left,
    double top,
    double width,
    double height,
  ) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        onTap: () {
          TranslationService.instance.speak(item.translatedText, _targetLang.speechCode);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${item.originalText} ➔ ${item.translatedText}'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xE60F172A), // Dark slate frosted glass look
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white30, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              item.translatedText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Solution 2: Interactive Focus Box with subtle outline & glowing tap response
  Widget _buildInteractiveFocusOverlay(
    OcrTranslatedItem item,
    double left,
    double top,
    double width,
    double height,
  ) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        onTap: () => _showDetailBottomSheet(context, item),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF38BDF8), width: 1.8), // Glowing cyan border
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                blurRadius: 6,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Subtle badge icon in the corner
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Color(0xFF38BDF8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.text_cursor, size: 8, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Solution 4 (Baseline): Original raw overlay with blue chips for direct comparison
  Widget _buildRawBaselineOverlay(
    OcrTranslatedItem item,
    double left,
    double top,
    double width,
    double height,
  ) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: item.isNoise ? Colors.redAccent.withValues(alpha: 0.8) : AppColors.primary,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            item.translatedText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  /// Solution 3: Document / Reader List Mode
  Widget _buildReaderListMode() {
    final items = _mergedItems.isNotEmpty ? _mergedItems : _rawItems;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // List Header Stats & Bulk Actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Icon(CupertinoIcons.doc_text_fill, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Extracted Document (${items.length} segments)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (items.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      final fullText = items.map((e) => e.translatedText).join('\n\n');
                      Clipboard.setData(ClipboardData(text: fullText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied all translated text to clipboard!')),
                      );
                    },
                    icon: const Icon(CupertinoIcons.doc_on_clipboard, size: 14),
                    label: const Text('Copy All', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                  ),
              ],
            ),
          ),

          // Scrollable list of translated paragraphs
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text(
                      'No text extracted yet. Capture an image to view document text.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Original Source Row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_sourceLang.flag, style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.originalText,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                            ),
                            // Translated Target Row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_targetLang.flag, style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.translatedText,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(CupertinoIcons.speaker_2, size: 18),
                                  color: AppColors.primary,
                                  onPressed: () {
                                    TranslationService.instance.speak(
                                      item.translatedText,
                                      _targetLang.speechCode,
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(CupertinoIcons.doc_on_clipboard, size: 18),
                                  color: AppColors.primary,
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: item.translatedText));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Translation copied!')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Bottom Buttons for Camera, Gallery, and Image Sharing
  Widget _buildBottomActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : () => _pickAndProcessImage(true),
            icon: const Icon(CupertinoIcons.camera_fill, size: 18),
            label: const Text('Capture Sign'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isProcessing ? null : () => _pickAndProcessImage(false),
            icon: const Icon(CupertinoIcons.photo_fill, size: 18),
            label: const Text('Gallery'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        if (_imageBytes != null) ...[
          const SizedBox(width: 10),
          IconButton(
            onPressed: _saveAndShareTranslatedImage,
            icon: const Icon(CupertinoIcons.share),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ],
    );
  }
}
