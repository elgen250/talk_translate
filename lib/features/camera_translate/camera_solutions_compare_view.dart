import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
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
  final String? sourceLangCode;
  final double angle;
  final Offset center;
  final double width;
  final double height;

  OcrTranslatedItem({
    required this.id,
    required this.originalText,
    required this.translatedText,
    required this.boundingBox,
    this.backgroundColor = const Color(0xFFF8FAFC),
    this.textColor = const Color(0xFF0F172A),
    this.isNoise = false,
    this.sourceLangCode,
    this.angle = 0.0,
    Offset? center,
    double? width,
    double? height,
  })  : center = center ?? boundingBox.center,
        width = width ?? boundingBox.width,
        height = height ?? boundingBox.height;

  OcrTranslatedItem copyWith({
    String? originalText,
    String? translatedText,
    Rect? boundingBox,
    Color? backgroundColor,
    Color? textColor,
    bool? isNoise,
    String? sourceLangCode,
    double? angle,
    Offset? center,
    double? width,
    double? height,
  }) {
    return OcrTranslatedItem(
      id: id,
      originalText: originalText ?? this.originalText,
      translatedText: translatedText ?? this.translatedText,
      boundingBox: boundingBox ?? this.boundingBox,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      isNoise: isNoise ?? this.isNoise,
      sourceLangCode: sourceLangCode ?? this.sourceLangCode,
      angle: angle ?? this.angle,
      center: center ?? this.center,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

/// The available visual rendering solutions for comparison.
enum CameraSolutionMode {
  googleLensAR,     // وضع Google Lens المباشر: مطابقة تامة للحجم والمكان وتغطية النص القديم
  interactiveSheet, // الحل 2: التحديد التفاعلي الهادئ وقائمة سفلية
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
  List<AppLanguage> _detectedLanguages = [];

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
        sourceLangCode: 'fr',
      ),
      OcrTranslatedItem(
        id: '2',
        originalText: "Sortie de secours",
        translatedText: "Emergency Exit",
        boundingBox: const Rect.fromLTWH(36, 145, 260, 34),
        backgroundColor: const Color(0xFFF1F5F9),
        textColor: const Color(0xFF0F172A),
        sourceLangCode: 'fr',
      ),
      OcrTranslatedItem(
        id: '3',
        originalText: "Ne pas encombrer le passage",
        translatedText: "Do not obstruct the passage",
        boundingBox: const Rect.fromLTWH(36, 185, 310, 32),
        backgroundColor: const Color(0xFFF1F5F9),
        textColor: const Color(0xFF0F172A),
        sourceLangCode: 'fr',
      ),
      OcrTranslatedItem(
        id: '4',
        originalText: "Menu du jour servi avec salade",
        translatedText: "Daily special served with salad",
        boundingBox: const Rect.fromLTWH(36, 240, 305, 34),
        backgroundColor: const Color(0xFFF1F5F9),
        textColor: const Color(0xFF0F172A),
        sourceLangCode: 'fr',
      ),
      OcrTranslatedItem(
        id: '5',
        originalText: "Merci de votre visite et à bientôt",
        translatedText: "Thank you for your visit, see you soon",
        boundingBox: const Rect.fromLTWH(36, 295, 325, 34),
        backgroundColor: const Color(0xFFF1F5F9),
        textColor: const Color(0xFF0F172A),
        sourceLangCode: 'fr',
      ),
    ];

    setState(() {
      _lensLineItems = sampleItems;
      _mergedItems = sampleItems;
      final frLang = getLanguageByCode('fr');
      if (frLang != null) {
        _detectedLanguages = [frLang];
        _detectedCameraLang = frLang;
      }
    });
  }

  /// Heuristic noise detector to weed out keyboard keys, single non-letter symbols, and UI artifacts
  bool _isNoiseOrKeyboardArtifact(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return true;

    // Filter pure long barcode numbers or serials (e.g. 80404738910)
    final numClean = clean.replaceAll(RegExp(r'[\/\-\:\.\s,\$€£%#]'), '');
    if (double.tryParse(numClean) != null && numClean.length > 7) return true;

    // Filter isolated non-alphanumeric punctuation
    if (clean.length == 1) {
      final code = clean.codeUnitAt(0);
      final isLetterOrDigit = (code >= 65 && code <= 90) || // A-Z
          (code >= 97 && code <= 122) || // a-z
          (code >= 48 && code <= 57) || // 0-9
          (code >= 0xC0 && code <= 0x024F) || // Latin accented
          (code >= 0x0600 && code <= 0x06FF) || // Arabic
          (code >= 0x4E00 && code <= 0x9FFF) || // CJK unified ideographs
          (code >= 0x3040 && code <= 0x30FF) || // Hiragana / Katakana
          (code >= 0xAC00 && code <= 0xD7AF);   // Korean Hangul
      if (!isLetterOrDigit) return true;
    }

    // Filter common on-screen keyboard keys and shortcuts
    final lower = clean.toLowerCase();
    const keyboardKeys = {
      'gif', 'esc', 'tab', 'caps', 'shift', 'ctrl', 'alt', 'fn', 'enter',
      'del', 'backspace', 'home', 'end', 'pgup', 'pgdn', 'prtscn',
    };
    if (keyboardKeys.contains(lower)) return true;

    // Pure symbols/punctuation without letters or digits
    if (RegExp(r'^[^a-zA-Z0-9\u00C0-\u024F\u0600-\u06FF\u4E00-\u9FFF\u3040-\u30FF\uAC00-\uD7AF]+$').hasMatch(clean)) {
      return true;
    }

    return false;
  }

  /// Samples the exact background color around the text line from the original image pixels
  /// using dominant mode clustering (rejects text stroke pixels)
  Color _sampleBackgroundColor(ui.Image image, ByteData? rawRgba, Rect rect) {
    if (rawRgba == null) return const Color(0xFFF1F5F9);

    final int imgW = image.width;
    final int imgH = image.height;

    // Sample perimeter points strictly within the inner margins of the bounding box
    final points = <Offset>[
      Offset(rect.left + 2, rect.top + 2),
      Offset(rect.right - 2, rect.top + 2),
      Offset(rect.left + 2, rect.bottom - 2),
      Offset(rect.right - 2, rect.bottom - 2),
      Offset(rect.left + (rect.width * 0.25), rect.top + 2),
      Offset(rect.left + (rect.width * 0.75), rect.top + 2),
      Offset(rect.left + (rect.width * 0.25), rect.bottom - 2),
      Offset(rect.left + (rect.width * 0.75), rect.bottom - 2),
      Offset(rect.left + 2, rect.top + (rect.height * 0.5)),
      Offset(rect.right - 2, rect.top + (rect.height * 0.5)),
    ];

    final colors = <Color>[];
    for (final pt in points) {
      final int px = pt.dx.toInt().clamp(0, imgW - 1);
      final int py = pt.dy.toInt().clamp(0, imgH - 1);
      final int index = (py * imgW + px) * 4;

      if (index >= 0 && index + 3 < rawRgba.lengthInBytes) {
        colors.add(Color.fromARGB(
          255,
          rawRgba.getUint8(index),
          rawRgba.getUint8(index + 1),
          rawRgba.getUint8(index + 2),
        ));
      }
    }

    if (colors.isEmpty) return const Color(0xFFF1F5F9);

    // Pick dominant color cluster (mode) instead of arithmetic mean
    // This rejects text stroke pixels and extracts true background surface color
    Color bestColor = colors.first;
    int maxClusterCount = 0;

    for (final c in colors) {
      int count = 0;
      for (final other in colors) {
        final dr = ((c.r - other.r).abs() * 255.0).round();
        final dg = ((c.g - other.g).abs() * 255.0).round();
        final db = ((c.b - other.b).abs() * 255.0).round();
        if (dr + dg + db < 75) {
          count++;
        }
      }
      if (count > maxClusterCount) {
        maxClusterCount = count;
        bestColor = c;
      }
    }

    return bestColor;
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
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 92,
    );

    if (image == null) return;

    // Reset old overlays and detected languages immediately so previous image data is never stuck
    setState(() {
      _isProcessing = true;
      _lensLineItems.clear();
      _mergedItems.clear();
      if (_sourceLang.isAuto) {
        _detectedCameraLang = null;
        _detectedLanguages.clear();
      }
    });

    try {
      final rawBytes = await image.readAsBytes();

      // Normalize orientation: Decode with Skia/Impeller (which bakes EXIF orientation to upright)
      // and re-encode to a pure upright PNG. This guarantees that ML Kit, the Flutter canvas,
      // and pixel background sampling are in the exact same 1:1 upright coordinate system on both iOS and Android!
      final ui.Codec codec = await ui.instantiateImageCodec(rawBytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image uiImage = frameInfo.image;

      final ByteData? pngByteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List normalizedBytes = pngByteData != null ? pngByteData.buffer.asUint8List() : rawBytes;

      final tempDir = await getTemporaryDirectory();
      final normalizedFile = File('${tempDir.path}/ocr_normalized_image.png');
      await normalizedFile.writeAsBytes(normalizedBytes);

      // Extract raw RGBA bytes for pixel-level background color sampling
      ByteData? rawRgba;
      try {
        rawRgba = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      } catch (e) {
        debugPrint('toByteData error: $e');
      }

      // Universal Cross-Platform OCR on the normalized upright image
      final recognizedLines = await TranslationService.instance.recognizeLinesFromImage(
        imageFile: XFile(normalizedFile.path),
        bytes: normalizedBytes,
        sourceLangCode: _sourceLang.isAuto ? null : _sourceLang.code,
      );

      if (recognizedLines.isEmpty) {
        if (!mounted) return;
        setState(() {
          _imageBytes = normalizedBytes;
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
        double angle,
        Offset center,
        double width,
        double height,
      })> candidateLines = [];

      int lineCounter = 0;
      for (final line in recognizedLines) {
        final text = line.text.trim();
        if (text.isEmpty || _isNoiseOrKeyboardArtifact(text)) continue;
        lineCounter++;

        final Color bg = _sampleBackgroundColor(uiImage, rawRgba, line.boundingBox);
        final Color fg = _getTextColorForBackground(bg);

        double angle = line.angle;
        Offset center = line.boundingBox.center;
        double lineW = line.boundingBox.width;
        double lineH = line.boundingBox.height;

        final pts = line.cornerPoints;
        if (pts != null && pts.length >= 4) {
          center = Offset(
            (pts[0].dx + pts[1].dx + pts[2].dx + pts[3].dx) / 4.0,
            (pts[0].dy + pts[1].dy + pts[2].dy + pts[3].dy) / 4.0,
          );
          lineW = math.sqrt(math.pow(pts[1].dx - pts[0].dx, 2) + math.pow(pts[1].dy - pts[0].dy, 2));
          lineH = math.sqrt(math.pow(pts[3].dx - pts[0].dx, 2) + math.pow(pts[3].dy - pts[0].dy, 2));
          angle = math.atan2(pts[1].dy - pts[0].dy, pts[1].dx - pts[0].dx);
        }

        candidateLines.add((
          id: 'line_$lineCounter',
          text: text,
          box: line.boundingBox,
          bgColor: bg,
          fgColor: fg,
          angle: angle,
          center: center,
          width: lineW,
          height: lineH,
        ));
      }

      if (candidateLines.isEmpty) {
        if (!mounted) return;
        setState(() {
          _imageBytes = normalizedBytes;
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

      // Sort candidate lines vertically (top to bottom) for stable spatial grouping
      candidateLines.sort((a, b) => a.box.top.compareTo(b.box.top));

      // 2. Group candidate lines into cohesive visual clusters (signs / paragraphs)
      final List<List<({
        String id,
        String text,
        Rect box,
        Color bgColor,
        Color fgColor,
        double angle,
        Offset center,
        double width,
        double height,
      })>> clusters = [];
      for (final item in candidateLines) {
        bool added = false;
        for (final cluster in clusters) {
          final last = cluster.last;
          final double vertGap = (item.box.top - last.box.bottom).abs();
          final double avgHeight = (item.box.height + last.box.height) / 2.0;
          final double horizOverlap = (item.box.right < last.box.left || item.box.left > last.box.right) ? 0.0 : 1.0;
          final double horizGap = item.box.left > last.box.right
              ? item.box.left - last.box.right
              : (last.box.left > item.box.right ? last.box.left - item.box.right : 0.0);
          final bool isHorizontallyNear = horizOverlap > 0 || horizGap < (last.box.width.clamp(40.0, 300.0));

          if (vertGap <= avgHeight * 1.3 && isHorizontallyNear) {
            cluster.add(item);
            added = true;
            break;
          }
        }
        if (!added) {
          clusters.add([item]);
        }
      }

      // 3. Translate clusters independently so each sign/cluster detects and preserves its actual language
      final List<OcrTranslatedItem> tempLensLines = [];
      final List<OcrTranslatedItem> tempBlocks = [];
      final Set<String> detectedCodes = {};

      int blockCounter = 0;
      final clusterResults = await Future.wait(
        clusters.map((cluster) async {
          blockCounter++;
          double minL = double.infinity, minT = double.infinity;
          double maxR = -double.infinity, maxB = -double.infinity;
          for (final it in cluster) {
            if (it.box.left < minL) minL = it.box.left;
            if (it.box.top < minT) minT = it.box.top;
            if (it.box.right > maxR) maxR = it.box.right;
            if (it.box.bottom > maxB) maxB = it.box.bottom;
          }

          final blockRect = Rect.fromLTRB(minL, minT, maxR, maxB);
          final Color blockBg = _sampleBackgroundColor(uiImage, rawRgba, blockRect);
          final Color blockFg = _getTextColorForBackground(blockBg);

          final clusterText = cluster.map((it) => it.text).join('\n');
          final clusterFromCode = _sourceLang.isAuto ? 'auto' : _sourceLang.code;

          try {
            final res = await TranslationService.instance.translateWithDetection(
              text: clusterText,
              fromCode: clusterFromCode,
              toCode: _targetLang.code,
              mode: 'camera',
            );

            final String detected = res.detectedSource.toLowerCase();
            final String translatedCluster = res.text.isNotEmpty ? res.text : clusterText;
            final translatedLines = translatedCluster.split('\n');
            final List<OcrTranslatedItem> clusterLensItems = [];

            if (translatedLines.length == cluster.length) {
              for (int i = 0; i < cluster.length; i++) {
                final it = cluster[i];
                final tLine = translatedLines[i].trim();
                clusterLensItems.add(
                  OcrTranslatedItem(
                    id: it.id,
                    originalText: it.text,
                    translatedText: tLine.isNotEmpty ? tLine : it.text,
                    boundingBox: it.box,
                    backgroundColor: it.bgColor,
                    textColor: it.fgColor,
                    sourceLangCode: detected,
                    angle: it.angle,
                    center: it.center,
                    width: it.width,
                    height: it.height,
                  ),
                );
              }
            } else {
              // Fallback: translate lines individually using the cluster's detected language with 1:1 precision
              final individualTranslations = await Future.wait(
                cluster.map((it) async {
                  try {
                    final t = await TranslationService.instance.translate(
                      text: it.text,
                      fromCode: detected,
                      toCode: _targetLang.code,
                      mode: 'camera',
                    );
                    return t.isNotEmpty ? t : it.text;
                  } catch (_) {
                    return it.text;
                  }
                }),
              );

              for (int i = 0; i < cluster.length; i++) {
                final it = cluster[i];
                final tLine = individualTranslations[i].trim();
                clusterLensItems.add(
                  OcrTranslatedItem(
                    id: it.id,
                    originalText: it.text,
                    translatedText: tLine.isNotEmpty ? tLine : it.text,
                    boundingBox: it.box,
                    backgroundColor: it.bgColor,
                    textColor: it.fgColor,
                    sourceLangCode: detected,
                    angle: it.angle,
                    center: it.center,
                    width: it.width,
                    height: it.height,
                  ),
                );
              }
            }

            final blockItem = OcrTranslatedItem(
              id: 'block_$blockCounter',
              originalText: clusterText,
              translatedText: translatedCluster,
              boundingBox: blockRect,
              backgroundColor: blockBg,
              textColor: blockFg,
              sourceLangCode: detected,
            );

            return (
              lensItems: clusterLensItems,
              blockItem: blockItem,
              detectedCode: detected,
            );
          } catch (e) {
            debugPrint('Cluster translation error: $e');
            final List<OcrTranslatedItem> fallbackLens = cluster.map((it) {
              return OcrTranslatedItem(
                id: it.id,
                originalText: it.text,
                translatedText: it.text,
                boundingBox: it.box,
                backgroundColor: it.bgColor,
                textColor: it.fgColor,
                sourceLangCode: _sourceLang.code,
                angle: it.angle,
                center: it.center,
                width: it.width,
                height: it.height,
              );
            }).toList();

            final blockItem = OcrTranslatedItem(
              id: 'block_$blockCounter',
              originalText: clusterText,
              translatedText: clusterText,
              boundingBox: blockRect,
              backgroundColor: blockBg,
              textColor: blockFg,
              sourceLangCode: _sourceLang.code,
            );

            return (
              lensItems: fallbackLens,
              blockItem: blockItem,
              detectedCode: _sourceLang.code,
            );
          }
        }),
      );

      for (final cr in clusterResults) {
        tempLensLines.addAll(cr.lensItems);
        tempBlocks.add(cr.blockItem);
        if (cr.detectedCode.isNotEmpty &&
            cr.detectedCode != 'und' &&
            cr.detectedCode != 'auto') {
          detectedCodes.add(cr.detectedCode);
        }
      }

      final List<AppLanguage> detectedLangs = [];
      for (final code in detectedCodes) {
        final lang = getLanguageByCode(code);
        if (lang != null && !detectedLangs.contains(lang)) {
          detectedLangs.add(lang);
        }
      }

      if (!mounted) return;
      setState(() {
        _imageBytes = normalizedBytes;
        _decodedImage = uiImage;
        _lensLineItems = tempLensLines;
        _mergedItems = tempBlocks;
        _detectedLanguages = detectedLangs;
        _detectedCameraLang = detectedLangs.isNotEmpty ? detectedLangs.first : null;
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

  /// Re-translates currently scanned items in real-time when the user switches source/target language
  Future<void> _retranslateCurrentItems() async {
    if (_lensLineItems.isEmpty && _mergedItems.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final effectiveFromCode = _detectedCameraLang?.code ?? (_sourceLang.isAuto ? 'auto' : _sourceLang.code);

      // 1. Re-translate Exact Lens lines in parallel batches of 10
      final List<OcrTranslatedItem> updatedLensLines = [];
      const batchSize = 10;
      for (var i = 0; i < _lensLineItems.length; i += batchSize) {
        final end = (i + batchSize < _lensLineItems.length) ? i + batchSize : _lensLineItems.length;
        final batch = _lensLineItems.sublist(i, end);

        final results = await Future.wait(
          batch.map((item) async {
            final fromCode = _sourceLang.isAuto
                ? (item.sourceLangCode ?? effectiveFromCode)
                : _sourceLang.code;
            try {
              final translated = await TranslationService.instance.translate(
                text: item.originalText,
                fromCode: fromCode,
                toCode: _targetLang.code,
                mode: 'camera',
              );
              return item.copyWith(
                translatedText: translated.isNotEmpty ? translated : item.originalText,
              );
            } catch (_) {
              return item;
            }
          }),
        );
        updatedLensLines.addAll(results);
      }

      // 2. Re-translate Merged blocks in parallel batches of 10
      final List<OcrTranslatedItem> updatedBlocks = [];
      for (var i = 0; i < _mergedItems.length; i += batchSize) {
        final end = (i + batchSize < _mergedItems.length) ? i + batchSize : _mergedItems.length;
        final batch = _mergedItems.sublist(i, end);

        final results = await Future.wait(
          batch.map((item) async {
            final fromCode = _sourceLang.isAuto
                ? (item.sourceLangCode ?? effectiveFromCode)
                : _sourceLang.code;
            try {
              final translated = await TranslationService.instance.translate(
                text: item.originalText,
                fromCode: fromCode,
                toCode: _targetLang.code,
                mode: 'camera',
              );
              return item.copyWith(
                translatedText: translated.isNotEmpty ? translated : item.originalText,
              );
            } catch (_) {
              return item;
            }
          }),
        );
        updatedBlocks.addAll(results);
      }

      if (!mounted) return;
      setState(() {
        _lensLineItems = updatedLensLines;
        _mergedItems = updatedBlocks;
        _isProcessing = false;
      });
    } catch (e) {
      debugPrint('Retranslate error: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
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
        final itemLang = item.sourceLangCode != null
            ? (getLanguageByCode(item.sourceLangCode!) ?? _sourceLang)
            : (_detectedCameraLang ?? _sourceLang);
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
                          Text(itemLang.flag, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(
                            itemLang.name,
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

  String _getDetectedBadgeLabel() {
    if (_detectedLanguages.length > 1) {
      final names = _detectedLanguages.map((l) => '${l.name} ${l.flag}').join(' & ');
      return 'Multi-Language: $names';
    } else if (_detectedCameraLang != null) {
      return 'Detected: ${_detectedCameraLang!.name} ${_detectedCameraLang!.flag}';
    }
    return '';
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
                      } else if (_detectedLanguages.isNotEmpty) {
                        _sourceLang = _targetLang;
                        _targetLang = _detectedLanguages.first;
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Target language cannot be Auto Detect')),
                        );
                        return;
                      }
                    } else {
                      final temp = _sourceLang;
                      _sourceLang = _targetLang;
                      _targetLang = temp;
                    }
                  });
                  _retranslateCurrentItems();
                },
                onSourceChanged: (l) {
                  setState(() {
                    _sourceLang = l;
                    if (!l.isAuto) {
                      _detectedCameraLang = null;
                      _detectedLanguages.clear();
                    }
                  });
                  _retranslateCurrentItems();
                },
                onTargetChanged: (l) {
                  setState(() => _targetLang = l);
                  _retranslateCurrentItems();
                },
              ),
              if (_sourceLang.isAuto && (_detectedLanguages.isNotEmpty || _detectedCameraLang != null)) ...[
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
                          _getDetectedBadgeLabel(),
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
                child: _buildCanvasViewfinder(),
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

  /// Segmented button row allowing instant live switching between the 2 modes
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
          const SizedBox(width: 6),

          // Button 2: Interactive Focus & Sheet
          Expanded(
            child: _buildModeTabButton(
              mode: CameraSolutionMode.interactiveSheet,
              title: '2. Focus & Sheet',
              subtitle: 'تحديد وقائمة',
              icon: CupertinoIcons.viewfinder_circle_fill,
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

        return Center(
          child: SizedBox(
            width: renderedWidth,
            height: renderedHeight,
            child: Stack(
              children: [
                // 1. Base Image exactly matching the SizedBox bounds
                Positioned.fill(
                  child: Image.memory(
                    _imageBytes!,
                    fit: BoxFit.fill,
                  ),
                ),

                // 2. Exact Overlays rendered dynamically in identical coordinate space
                if (!_showOriginal)
                  ..._lensLineItems.map((item) {
                    if (_activeMode == CameraSolutionMode.googleLensAR) {
                      return _buildGoogleLensOverlay(item, scale);
                    } else {
                      return _buildInteractiveFocusOverlay(item, scale);
                    }
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Solution 1: Google Lens AR 1:1 In-Place Replacement
  /// - Exact position & rotation: centered and oriented along the text baseline angle
  /// - Full typographic bleed: expands 24% vertically and 28% horizontally to erase all ascenders, descenders, and accents
  /// - Seamless background: fills with sampled background color, NO drop shadows, NO sticker chips
  Widget _buildGoogleLensOverlay(
    OcrTranslatedItem item,
    double scale,
  ) {
    final double centerX = item.center.dx * scale;
    final double centerY = item.center.dy * scale;

    final double rawW = item.width * scale;
    final double rawH = item.height * scale;

    // Generous typographic bleed:
    // ML Kit's raw bounding box only wraps tight ink, cutting off ascenders (t, d, b, l),
    // descenders (g, p, q, y), and accents (é, à, è).
    // Expanding by 24% vertically and 28% horizontally ensures 100% complete coverage of the original text!
    final double verticalBleed = math.max(5.0, rawH * 0.24);
    final double horizontalBleed = math.max(6.0, rawH * 0.28);

    final double boxWidth = rawW + (horizontalBleed * 2.0);
    final double boxHeight = rawH + (verticalBleed * 2.0);

    final double targetFontSize = rawH * 0.84;
    final bool isRtl = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]').hasMatch(item.translatedText);

    Widget boxContent = Container(
      width: boxWidth,
      height: boxHeight,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: horizontalBleed * 0.4),
      decoration: BoxDecoration(
        color: item.backgroundColor,
        borderRadius: BorderRadius.circular(3),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Text(
          item.translatedText,
          maxLines: 1,
          textAlign: TextAlign.center,
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          style: TextStyle(
            color: item.textColor,
            fontSize: targetFontSize,
            fontWeight: FontWeight.w600,
            height: 1.1,
            letterSpacing: isRtl ? 0 : -0.2,
          ),
        ),
      ),
    );

    // If text is tilted (e.g. angled camera shot of monitor/paper), rotate the overlay to match exactly!
    if (item.angle.abs() > 0.015) {
      boxContent = Transform.rotate(
        angle: item.angle,
        alignment: Alignment.center,
        child: boxContent,
      );
    }

    return Positioned(
      left: centerX - (boxWidth / 2.0),
      top: centerY - (boxHeight / 2.0),
      width: boxWidth,
      height: boxHeight,
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
        child: boxContent,
      ),
    );
  }

  /// Solution 2: Interactive Focus Box with glowing outline
  Widget _buildInteractiveFocusOverlay(
    OcrTranslatedItem item,
    double scale,
  ) {
    final double centerX = item.center.dx * scale;
    final double centerY = item.center.dy * scale;

    final double boxWidth = item.width * scale + 8.0;
    final double boxHeight = item.height * scale + 6.0;

    Widget focusBox = Container(
      width: boxWidth,
      height: boxHeight,
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
    );

    if (item.angle.abs() > 0.015) {
      focusBox = Transform.rotate(
        angle: item.angle,
        alignment: Alignment.center,
        child: focusBox,
      );
    }

    return Positioned(
      left: centerX - (boxWidth / 2.0),
      top: centerY - (boxHeight / 2.0),
      width: boxWidth,
      height: boxHeight,
      child: GestureDetector(
        onTap: () => _showDetailBottomSheet(context, item),
        child: focusBox,
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
