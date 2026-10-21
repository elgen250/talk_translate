import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/app_language.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/language_selector_row.dart';
import '../../core/widgets/shared_top_bar.dart';
import '../../data/translation_service.dart';
import '../../shared/settings_modal.dart';

/// Represents a recognized and translated text segment with its visual bounding box and sampled colors.
class OcrTranslatedItem {
  final String id;
  final String originalText;
  final String translatedText;
  final Rect boundingBox;
  final Color backgroundColor;
  final Color textColor;
  final bool isNoise;

  OcrTranslatedItem({
    required this.id,
    required this.originalText,
    required this.translatedText,
    required this.boundingBox,
    this.backgroundColor = const Color(0xFFF8FAFC),
    this.textColor = const Color(0xFF0F172A),
    this.isNoise = false,
  });

  OcrTranslatedItem copyWith({
    String? originalText,
    String? translatedText,
    Rect? boundingBox,
    Color? backgroundColor,
    Color? textColor,
    bool? isNoise,
  }) {
    return OcrTranslatedItem(
      id: id,
      originalText: originalText ?? this.originalText,
      translatedText: translatedText ?? this.translatedText,
      boundingBox: boundingBox ?? this.boundingBox,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      isNoise: isNoise ?? this.isNoise,
    );
  }
}

/// The available visual rendering solutions for comparison.
enum CameraSolutionMode {
  googleLensAR,     // وضع Google Lens المباشر: مطابقة تامة للحجم والمكان وتغطية النص القديم
  interactiveSheet, // الحل 2: التحديد التفاعلي الهادئ وقائمة سفلية
  readerList,       // الحل 3: قائمة المستند المنظمة للقراءة والنسخ
  mergedParagraphs, // الحل 4: دمج الفقرات
}

/// A dedicated comparison widget implementing all OCR solutions with exact in-place Google Lens alignment.
class CameraSolutionsCompareView extends StatefulWidget {
  const CameraSolutionsCompareView({super.key});

  @override
  State<CameraSolutionsCompareView> createState() => _CameraSolutionsCompareViewState();
}

class _CameraSolutionsCompareViewState extends State<CameraSolutionsCompareView> {
  // Default to pure Google Lens AR 1:1 in-place mode
  CameraSolutionMode _activeMode = CameraSolutionMode.googleLensAR;

  AppLanguage _sourceLang = autoDetectLanguage; // Auto Detect by default
  AppLanguage _targetLang = supportedLanguages[0]; // English default
  AppLanguage? _detectedCameraLang;

  Uint8List? _imageBytes;
  ui.Image? _decodedImage;
  
  // Stored items: exact line-by-line items (Google Lens), merged blocks, and raw
  List<OcrTranslatedItem> _lensLineItems = [];
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
        boundingBox: const Rect.fromLTWH(36, 90, 290, 36),
        backgroundColor: const Color(0xFFF1F5F9),
        textColor: const Color(0xFF0F172A),
      ),
      OcrTranslatedItem(
        id: '2',
        originalText: "Sortie de secours",
        translatedText: "Emergency Exit",
        boundingBox: const Rect.fromLTWH(36, 145, 260, 34),
        backgroundColor: const Color(0xFFF1F5F9),
        textColor: const Color(0xFF0F172A),
      ),
      OcrTranslatedItem(
        id: '3',
        originalText: "Ne pas encombrer le passage",
        translatedText: "Do not obstruct the passage",
        boundingBox: const Rect.fromLTWH(36, 185, 310, 32),
        backgroundColor: const Color(0xFFF1F5F9),
        textColor: const Color(0xFF0F172A),
      ),
      OcrTranslatedItem(
        id: '4',
        originalText: "Menu du jour servi avec salade",
        translatedText: "Daily special served with salad",
        boundingBox: const Rect.fromLTWH(36, 240, 305, 34),
        backgroundColor: const Color(0xFFF1F5F9),
        textColor: const Color(0xFF0F172A),
      ),
      OcrTranslatedItem(
        id: '5',
        originalText: "Merci de votre visite et à bientôt",
        translatedText: "Thank you for your visit, see you soon",
        boundingBox: const Rect.fromLTWH(36, 295, 325, 34),
        backgroundColor: const Color(0xFFF1F5F9),
        textColor: const Color(0xFF0F172A),
      ),
    ];

    setState(() {
      _lensLineItems = sampleItems;
      _mergedItems = sampleItems;
    });
  }

  /// Heuristic noise detector to weed out keyboard keys, single letters, and UI artifacts
  bool _isNoiseOrKeyboardArtifact(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return true;

    // Filter pure long numbers or serials (e.g. 80404738)
    final numClean = clean.replaceAll(RegExp(r'[\/\-\:\.\s,\$€£%#]'), '');
    if (double.tryParse(numClean) != null && numClean.length > 5) return true;

    // Filter isolated single characters unless allowed valid words
    if (clean.length == 1) {
      const allowedSingleChars = {'a', 'i', 'y', 'à', 'و', '&', '+', 'c'};
      if (!allowedSingleChars.contains(clean.toLowerCase())) return true;
    }

    // Filter common on-screen keyboard keys and shortcuts
    final lower = clean.toLowerCase();
    const keyboardKeys = {
      'gif', 'esc', 'tab', 'caps', 'shift', 'ctrl', 'alt', 'fn', 'enter',
      'del', 'backspace', 'home', 'end', 'pgup', 'pgdn', 'prtscn',
    };
    if (keyboardKeys.contains(lower)) return true;

    // Pure symbols/punctuation without letters or digits
    if (RegExp(r'^[^a-zA-Z0-9\u0600-\u06FF\u4E00-\u9FFF\u3040-\u30FF\uAC00-\uD7AF]+$').hasMatch(clean)) {
      return true;
    }

    return false;
  }

  /// Samples the exact background color around the text line from the original image pixels
  Color _sampleBackgroundColor(ui.Image image, ByteData? rawRgba, Rect rect) {
    if (rawRgba == null) return const Color(0xFFF1F5F9);

    final int imgW = image.width;
    final int imgH = image.height;

    // Sample 6 perimeter points around the bounding box (corners and margins)
    final points = [
      Offset(rect.left + 2, rect.top + 2),
      Offset(rect.right - 2, rect.top + 2),
      Offset(rect.left + 2, rect.bottom - 2),
      Offset(rect.right - 2, rect.bottom - 2),
      Offset(rect.left + (rect.width / 2), (rect.top - 2).clamp(0, imgH - 1)),
      Offset(rect.left + (rect.width / 2), (rect.bottom + 2).clamp(0, imgH - 1)),
    ];

    int totalR = 0, totalG = 0, totalB = 0, count = 0;

    for (final pt in points) {
      final int px = pt.dx.toInt().clamp(0, imgW - 1);
      final int py = pt.dy.toInt().clamp(0, imgH - 1);
      final int index = (py * imgW + px) * 4;

      if (index >= 0 && index + 3 < rawRgba.lengthInBytes) {
        totalR += rawRgba.getUint8(index);
        totalG += rawRgba.getUint8(index + 1);
        totalB += rawRgba.getUint8(index + 2);
        count++;
      }
    }

    if (count == 0) return const Color(0xFFF1F5F9);

    return Color.fromARGB(
      255,
      (totalR / count).round(),
      (totalG / count).round(),
      (totalB / count).round(),
    );
  }

  /// Computes optimal text color ensuring maximum contrast against the sampled background
  Color _getTextColorForBackground(Color bg) {
    // WCAG Relative Luminance
    final double luminance = bg.computeLuminance();
    // Light background -> crisp rich dark text; Dark background -> crisp pure white
    return luminance > 0.5 ? const Color(0xFF0F172A) : Colors.white;
  }

  /// Capture image from Camera or Pick from Gallery
  Future<void> _pickAndProcessImage(bool useCamera) async {
    final XFile? image = await _picker.pickImage(
      source: useCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
    );

    if (image == null) return;

    // Reset old overlays and detected language immediately so previous image data is never stuck
    setState(() {
      _isProcessing = true;
      _lensLineItems.clear();
      _mergedItems.clear();
      if (_sourceLang.isAuto) {
        _detectedCameraLang = null;
      }
    });

    try {
      final bytes = await image.readAsBytes();
      final uiImage = await _decodeImage(bytes);

      // Extract raw RGBA bytes for pixel-level background color sampling
      ByteData? rawRgba;
      try {
        rawRgba = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      } catch (e) {
        debugPrint('toByteData error: $e');
      }

      // Universal Cross-Platform OCR (Mobile on-device ML Kit + Web/Desktop Cloud OCR)
      final recognizedLines = await TranslationService.instance.recognizeLinesFromImage(
        imageFile: image,
        bytes: bytes,
      );

      if (recognizedLines.isEmpty) {
        if (!mounted) return;
        setState(() {
          _imageBytes = bytes;
          _decodedImage = uiImage;
          _lensLineItems = [];
          _mergedItems = [];
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لم يتم العثور على أي نص في هذه الصورة. يرجى تجربة صورة أوضح.'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // 1. Google Lens Exact Line Candidates
      final List<({
        String id,
        String text,
        Rect box,
        Color bgColor,
        Color fgColor,
      })> candidateLines = [];

      int lineCounter = 0;
      for (final line in recognizedLines) {
        final text = line.text.trim();
        if (text.isEmpty || _isNoiseOrKeyboardArtifact(text)) continue;
        lineCounter++;

        final Color bg = _sampleBackgroundColor(uiImage, rawRgba, line.boundingBox);
        final Color fg = _getTextColorForBackground(bg);

        candidateLines.add((
          id: 'line_$lineCounter',
          text: text,
          box: line.boundingBox,
          bgColor: bg,
          fgColor: fg,
        ));
      }

      if (candidateLines.isEmpty) {
        if (!mounted) return;
        setState(() {
          _imageBytes = bytes;
          _decodedImage = uiImage;
          _lensLineItems = [];
          _mergedItems = [];
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('النصوص المكتشفة غير واضحة أو مجرد رموز. يرجى تجربة صورة أوضح.'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // 2. Merged Paragraph Blocks (for alternative mode)
      final List<({
        String id,
        String text,
        Rect box,
        Color bgColor,
        Color fgColor,
      })> candidateBlocks = [];

      // Group candidate lines that are vertically adjacent
      final List<List<({String id, String text, Rect box, Color bgColor, Color fgColor})>> clusters = [];
      for (final item in candidateLines) {
        bool added = false;
        for (final cluster in clusters) {
          final last = cluster.last;
          final double vertGap = (item.box.top - last.box.bottom).abs();
          final double avgHeight = (item.box.height + last.box.height) / 2.0;
          if (vertGap <= avgHeight * 1.5) {
            cluster.add(item);
            added = true;
            break;
          }
        }
        if (!added) {
          clusters.add([item]);
        }
      }

      int blockCounter = 0;
      for (final cluster in clusters) {
        blockCounter++;
        double minL = double.infinity, minT = double.infinity;
        double maxR = -double.infinity, maxB = -double.infinity;
        final words = <String>[];

        for (final it in cluster) {
          words.add(it.text);
          if (it.box.left < minL) minL = it.box.left;
          if (it.box.top < minT) minT = it.box.top;
          if (it.box.right > maxR) maxR = it.box.right;
          if (it.box.bottom > maxB) maxB = it.box.bottom;
        }

        final blockRect = Rect.fromLTRB(minL, minT, maxR, maxB);
        final Color blockBg = _sampleBackgroundColor(uiImage, rawRgba, blockRect);
        final Color blockFg = _getTextColorForBackground(blockBg);

        candidateBlocks.add((
          id: 'block_$blockCounter',
          text: words.join('\n'),
          box: blockRect,
          bgColor: blockBg,
          fgColor: blockFg,
        ));
      }

      // 3. Detect language if source is Auto Detect
      if (_sourceLang.isAuto && candidateLines.isNotEmpty) {
        final sampleText = candidateLines.take(5).map((l) => l.text).join(' ');
        final detectedCode = await TranslationService.instance.identifyLanguage(sampleText);
        if (detectedCode != null) {
          final resolved = getLanguageByCode(detectedCode);
          if (resolved != null) {
            _detectedCameraLang = resolved;
          }
        }
      }
      final effectiveFromCode = _detectedCameraLang?.code ?? (_sourceLang.isAuto ? 'auto' : _sourceLang.code);

      // 4. Translate Exact Lines in parallel batches of 10
      final List<OcrTranslatedItem> tempLensLines = [];
      const batchSize = 10;
      for (var i = 0; i < candidateLines.length; i += batchSize) {
        final end = (i + batchSize < candidateLines.length) ? i + batchSize : candidateLines.length;
        final batch = candidateLines.sublist(i, end);

        final results = await Future.wait(
          batch.map((item) async {
            try {
              final translated = await TranslationService.instance.translate(
                text: item.text,
                fromCode: effectiveFromCode,
                toCode: _targetLang.code,
                mode: 'camera',
              );
              return OcrTranslatedItem(
                id: item.id,
                originalText: item.text,
                translatedText: translated.isNotEmpty ? translated : item.text,
                boundingBox: item.box,
                backgroundColor: item.bgColor,
                textColor: item.fgColor,
              );
            } catch (_) {
              return OcrTranslatedItem(
                id: item.id,
                originalText: item.text,
                translatedText: item.text,
                boundingBox: item.box,
                backgroundColor: item.bgColor,
                textColor: item.fgColor,
              );
            }
          }),
        );
        tempLensLines.addAll(results);
      }

      // 5. Translate Merged Blocks for alternative mode
      final List<OcrTranslatedItem> tempBlocks = [];
      for (var i = 0; i < candidateBlocks.length; i += batchSize) {
        final end = (i + batchSize < candidateBlocks.length) ? i + batchSize : candidateBlocks.length;
        final batch = candidateBlocks.sublist(i, end);

        final results = await Future.wait(
          batch.map((item) async {
            try {
              final translated = await TranslationService.instance.translate(
                text: item.text,
                fromCode: effectiveFromCode,
                toCode: _targetLang.code,
                mode: 'camera',
              );
              return OcrTranslatedItem(
                id: item.id,
                originalText: item.text,
                translatedText: translated.isNotEmpty ? translated : item.text,
                boundingBox: item.box,
                backgroundColor: item.bgColor,
                textColor: item.fgColor,
              );
            } catch (_) {
              return OcrTranslatedItem(
                id: item.id,
                originalText: item.text,
                translatedText: item.text,
                boundingBox: item.box,
                backgroundColor: item.bgColor,
                textColor: item.fgColor,
              );
            }
          }),
        );
        tempBlocks.addAll(results);
      }

      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _decodedImage = uiImage;
        _lensLineItems = tempLensLines;
        _mergedItems = tempBlocks;
        _isProcessing = false;
      });
    } catch (e) {
      debugPrint('OCR Error: $e');
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء معالجة الصورة: $e')),
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

  /// High-Resolution Image Export & Share
  Future<void> _saveAndShareTranslatedImage() async {
    try {
      RenderRepaintBoundary boundary = _repaintBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/translated_lens.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([XFile(file.path)], text: 'Translated via Talk & Translate Google Lens');
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
                            'Text Details',
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
              SharedTopBar(
                title: 'Google Lens AR',
                subtitle: 'Exact in-place 1:1 text replacement',
                onSettingsTap: () => showSettingsModal(context),
              ),
              const SizedBox(height: 10),

              LanguageSelectorRow(
                source: _sourceLang,
                target: _targetLang,
                allowAutoDetect: true,
                onSwap: () {
                  setState(() {
                    if (_sourceLang.isAuto) {
                      if (_detectedCameraLang != null) {
                        _sourceLang = _targetLang;
                        _targetLang = _detectedCameraLang!;
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Target language cannot be Auto Detect')),
                        );
                      }
                    } else {
                      final temp = _sourceLang;
                      _sourceLang = _targetLang;
                      _targetLang = temp;
                    }
                  });
                },
                onSourceChanged: (l) => setState(() {
                  _sourceLang = l;
                  if (!l.isAuto) _detectedCameraLang = null;
                }),
                onTargetChanged: (l) => setState(() => _targetLang = l),
              ),
              if (_sourceLang.isAuto && _detectedCameraLang != null) ...[
                const SizedBox(height: 6),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(CupertinoIcons.sparkles, size: 13, color: AppColors.primary),
                        const SizedBox(width: 5),
                        Text(
                          'Detected: ${_detectedCameraLang!.name} ${_detectedCameraLang!.flag}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),

              _buildSolutionsControlBar(),
              const SizedBox(height: 10),

              Expanded(
                child: _activeMode == CameraSolutionMode.readerList
                    ? _buildReaderListMode()
                    : _buildCanvasViewfinder(),
              ),

              const SizedBox(height: 12),
              _buildBottomActionButtons(),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  /// Segmented button row allowing instant live switching between all modes
  Widget _buildSolutionsControlBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Button 1: Google Lens AR (Exact 1:1 In-Place)
          Expanded(
            child: _buildModeTabButton(
              mode: CameraSolutionMode.googleLensAR,
              title: '1. Google Lens',
              subtitle: 'نفس الحجم والمكان',
              icon: CupertinoIcons.viewfinder,
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

          // Button 4: Merged Paragraphs
          Expanded(
            child: _buildModeTabButton(
              mode: CameraSolutionMode.mergedParagraphs,
              title: '4. Merged Lens',
              subtitle: 'دمج الفقرات',
              icon: CupertinoIcons.rectangle_stack,
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

  /// Viewfinder Container for Canvas-based solutions
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
                        'Google Lens AI In-Place Translation...',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),

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
      case CameraSolutionMode.googleLensAR:
        return 'Google Lens: Exact 1:1 In-Place';
      case CameraSolutionMode.interactiveSheet:
        return 'Focus & Sheet: Tap to Inspect';
      case CameraSolutionMode.readerList:
        return 'Document Reader List';
      case CameraSolutionMode.mergedParagraphs:
        return 'Merged Paragraphs Lens';
    }
  }

  Widget _buildPlaceholderScene() {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.camera_viewfinder, size: 64, color: Colors.white54),
          const SizedBox(height: 14),
          const Text(
            'Google Lens AR Translation',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Replaces original text in-place with the exact same size, position, and background color matching Google Lens.',
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

        final double offsetX = (widgetWidth - renderedWidth) / 2.0;
        final double offsetY = (widgetHeight - renderedHeight) / 2.0;

        final itemsToRender = (_activeMode == CameraSolutionMode.mergedParagraphs)
            ? _mergedItems
            : _lensLineItems;

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

              // 2. Exact Overlays rendered dynamically
              if (!_showOriginal)
                ...itemsToRender.map((item) {
                  final rect = item.boundingBox;
                  // Exact pixel mapping to the screen
                  final double left = offsetX + (rect.left * scale);
                  final double top = offsetY + (rect.top * scale);
                  final double width = rect.width * scale;
                  final double height = rect.height * scale;

                  if (_activeMode == CameraSolutionMode.googleLensAR) {
                    return _buildGoogleLensOverlay(item, left, top, width, height);
                  } else if (_activeMode == CameraSolutionMode.interactiveSheet) {
                    return _buildInteractiveFocusOverlay(item, left, top, width, height);
                  } else {
                    return _buildMergedParagraphOverlay(item, left, top, width, height);
                  }
                }),
            ],
          ),
        );
      },
    );
  }

  /// Solution 1: Google Lens AR 1:1 In-Place Replacement
  /// - Exact position: directly above the old text with 1px bleed to erase old letters completely
  /// - Exact size: text font size is proportional to the line height (height * 0.78)
  /// - Seamless background: fills with sampled background color, NO drop shadows, NO sticker chips
  Widget _buildGoogleLensOverlay(
    OcrTranslatedItem item,
    double left,
    double top,
    double width,
    double height,
  ) {
    final double targetFontSize = height * 0.78;

    return Positioned(
      left: left - 1,
      top: top - 1,
      width: width + 2,
      height: height + 2,
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
          width: width + 2,
          height: height + 2,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: item.backgroundColor,
            borderRadius: BorderRadius.circular(2),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              item.translatedText,
              maxLines: 1,
              style: TextStyle(
                color: item.textColor,
                fontSize: targetFontSize,
                fontWeight: FontWeight.w600,
                height: 1.05,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Solution 2: Interactive Focus Box with glowing outline
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
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                blurRadius: 4,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Color(0xFF38BDF8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.text_cursor, size: 7, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Solution 4: Merged Paragraphs with frosted dark background
  Widget _buildMergedParagraphOverlay(
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
            color: const Color(0xE60F172A),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white30, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
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

  /// Solution 3: Document / Reader List Mode
  Widget _buildReaderListMode() {
    final items = _lensLineItems.isNotEmpty ? _lensLineItems : _mergedItems;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
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
                  'Extracted Document (${items.length} lines)',
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
                      final fullText = items.map((e) => e.translatedText).join('\n');
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
