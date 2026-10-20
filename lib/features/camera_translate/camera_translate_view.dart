import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

class TranslatedLineItem {
  final String originalText;
  final String translatedText;
  final Rect boundingBox;

  TranslatedLineItem({
    required this.originalText,
    required this.translatedText,
    required this.boundingBox,
  });
}

class CameraTranslateView extends StatefulWidget {
  const CameraTranslateView({super.key});

  @override
  State<CameraTranslateView> createState() => _CameraTranslateViewState();
}

class _CameraTranslateViewState extends State<CameraTranslateView> {
  AppLanguage _sourceLang = supportedLanguages[1]; // French
  AppLanguage _targetLang = supportedLanguages[0]; // English

  Uint8List? _imageBytes;
  ui.Image? _decodedImage;
  List<TranslatedLineItem> _translatedLines = [];
  
  bool _isProcessing = false;
  bool _showOriginal = false;
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadSamplePreset();
  }

  // Load an initial demo scene so the view is never empty on launch
  Future<void> _loadSamplePreset() async {
    // We start with pre-calculated sample blocks simulating a scanned menu or form
    setState(() {
      _translatedLines = [
        TranslatedLineItem(
          originalText: "Café au lait",
          translatedText: "Coffee with milk",
          boundingBox: const Rect.fromLTWH(40, 100, 280, 45),
        ),
        TranslatedLineItem(
          originalText: "Sortie de secours",
          translatedText: "Emergency exit",
          boundingBox: const Rect.fromLTWH(40, 170, 320, 45),
        ),
        TranslatedLineItem(
          originalText: "Refresh Data",
          translatedText: "تحديث البيانات",
          boundingBox: const Rect.fromLTWH(40, 240, 240, 40),
        ),
      ];
    });
  }

  // Capture from Camera or Gallery with Professional Line-Level OCR
  Future<void> _pickAndProcessImage(bool useCamera) async {
    final XFile? image = await _picker.pickImage(
      source: useCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 90,
    );

    if (image == null) return;

    setState(() {
      _isProcessing = true;
      _translatedLines.clear();
    });

    try {
      final bytes = await image.readAsBytes();
      final uiImage = await _decodeImage(bytes);

      if (kIsWeb) {
        // Web fallback simulation since native ML Kit requires mobile channels
        setState(() {
          _imageBytes = bytes;
          _decodedImage = uiImage;
          _isProcessing = false;
        });
        _processWebFallbackText(image.name);
        return;
      }

      // Native Mobile OCR Processing via Google ML Kit TextRecognizer
      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      
      try {
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        List<TranslatedLineItem> tempLines = [];

        for (TextBlock block in recognizedText.blocks) {
          for (TextLine line in block.lines) {
            final text = line.text.trim();
            // Filter out pure numbers, dates, or tiny noise to keep UI clean
            if (text.isEmpty || _isPureNumberOrDate(text)) continue;

            // Translate each line individually or batch
            final translated = await TranslationService.instance.translate(
              text: text,
              fromCode: _sourceLang.code,
              toCode: _targetLang.code,
              mode: 'camera',
            );

            tempLines.add(
              TranslatedLineItem(
                originalText: text,
                translatedText: translated,
                boundingBox: line.boundingBox,
              ),
            );
          }
        }

        if (!mounted) return;
        setState(() {
          _imageBytes = bytes;
          _decodedImage = uiImage;
          _translatedLines = tempLines;
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

  bool _isPureNumberOrDate(String text) {
    // Skip strings that are purely numeric IDs or dates like 80404738 or 2026/05/3
    final clean = text.replaceAll(RegExp(r'[\/\-\:\.\s]'), '');
    return double.tryParse(clean) != null && clean.length > 4;
  }

  void _processWebFallbackText(String filename) async {
    const sampleText = "Café au lait - 4.50€\nSortie de secours\nRefresh Data";
    final translated = await TranslationService.instance.translate(
      text: sampleText,
      fromCode: _sourceLang.code,
      toCode: _targetLang.code,
      mode: 'camera',
    );
    setState(() {
      _translatedLines = [
        TranslatedLineItem(
          originalText: sampleText,
          translatedText: translated,
          boundingBox: const Rect.fromLTWH(50, 120, 300, 100),
        ),
      ];
    });
  }

  // High-Resolution Image Export & Share
  Future<void> _saveAndShareTranslatedImage() async {
    try {
      RenderRepaintBoundary boundary = _repaintBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/translated_image.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([XFile(file.path)], text: 'Translated via Talk & Translate OCR');
    } catch (e) {
      debugPrint('Share error: $e');
    }
  }

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
                title: 'Camera OCR',
                subtitle: 'Point at signs, menus or documents',
                onSettingsTap: () => showSettingsModal(context),
              ),
              const SizedBox(height: 14),
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
              const SizedBox(height: 14),
              
              // Interactive Viewfinder & Image Canvas Container
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        // RepaintBoundary captures final composited view for gallery export
                        RepaintBoundary(
                          key: _repaintBoundaryKey,
                          child: InteractiveViewer(
                            minScale: 1.0,
                            maxScale: 4.0,
                            child: Center(
                              child: _imageBytes == null
                                  ? _buildPlaceholderScene()
                                  : _buildImageWithOverlays(),
                            ),
                          ),
                        ),

                        // Loading Indicator
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
                                    'AI Neural OCR Processing...',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Top Controls Overlay (Toggle Original vs Translated)
                        if (_imageBytes != null && !_isProcessing)
                          Positioned(
                            top: 16,
                            right: 16,
                            child: GestureDetector(
                              onTapDown: (_) => setState(() => _showOriginal = true),
                              onTapUp: (_) => setState(() => _showOriginal = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white30),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _showOriginal ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _showOriginal ? 'Showing Original' : 'Hold to View Original',
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Bottom Action Bar: Camera, Gallery, and Export Share
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : () => _pickAndProcessImage(true),
                      icon: const Icon(CupertinoIcons.camera_fill),
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
                      icon: const Icon(CupertinoIcons.photo_fill),
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
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderScene() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.camera_viewfinder, size: 64, color: Colors.white54),
          const SizedBox(height: 16),
          const Text(
            'Smart OCR & Image Translation',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Capture a sign, menu, or document. Text will be translated directly on top of the image in real time.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _pickAndProcessImage(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Start Camera'),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWithOverlays() {
    if (_imageBytes == null || _decodedImage == null) return Container();

    return LayoutBuilder(
      builder: (context, constraints) {
        final imgWidth = _decodedImage!.width.toDouble();
        final imgHeight = _decodedImage!.height.toDouble();

        // Calculate BoxFit.contain aspect ratio mapping
        final double widgetWidth = constraints.maxWidth;
        final double widgetHeight = constraints.maxHeight;

        final double scaleX = widgetWidth / imgWidth;
        final double scaleY = widgetHeight / imgHeight;
        final double scale = scaleX < scaleY ? scaleX : scaleY;

        final double renderedWidth = imgWidth * scale;
        final double renderedHeight = imgHeight * scale;

        final double offsetX = (widgetWidth - renderedWidth) / 2;
        final double offsetY = (widgetHeight - renderedHeight) / 2;

        return SizedBox(
          width: widgetWidth,
          height: widgetHeight,
          child: Stack(
            children: [
              // Base Image
              Center(
                child: Image.memory(
                  _imageBytes!,
                  fit: BoxFit.contain,
                ),
              ),

              // Translated Text Overlays (Google Lens Style)
              if (!_showOriginal)
                ..._translatedLines.map((item) {
                  final rect = item.boundingBox;
                  // Map ML Kit relative rect to actual rendered widget pixel coordinates
                  final double left = offsetX + (rect.left * scale);
                  final double top = offsetY + (rect.top * scale);
                  final double width = rect.width * scale;
                  final double height = rect.height * scale;

                  return Positioned(
                    left: left < 0 ? 0 : left,
                    top: top < 0 ? 0 : top,
                    width: width < 40 ? 40 : width,
                    height: height < 20 ? 20 : height,
                    child: GestureDetector(
                      onTap: () {
                        TranslationService.instance.speak(item.translatedText, _targetLang.speechCode);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${item.originalText} ➔ ${item.translatedText}')),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
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
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
