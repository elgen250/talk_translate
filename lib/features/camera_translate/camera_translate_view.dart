import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/app_language.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/language_selector_row.dart';
import '../../core/widgets/shared_top_bar.dart';
import '../../data/translation_service.dart';
import '../../shared/settings_modal.dart';

class TranslatedBlockItem {
  final String originalText;
  final String translatedText;
  final Rect boundingBox;

  TranslatedBlockItem({
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
  AppLanguage _sourceLang = supportedLanguages[0]; // English
  AppLanguage _targetLang = supportedLanguages[10]; // Arabic
  String _detectedText = 'Point at text or select photo';
  String? _capturedImagePath;
  bool _isScanning = false;
  bool _isSavingImage = false;

  final GlobalKey _repaintBoundaryKey = GlobalKey();
  Size? _imageNaturalSize;
  List<TranslatedBlockItem> _translatedBlocks = [];

  Future<void> _captureWithAiCamera(bool useCamera) async {
    try {
      setState(() {
        _isScanning = true;
        _translatedBlocks = [];
      });

      final result = await TranslationService.instance
          .captureAndRecognizeBlocks(fromCamera: useCamera);

      if (!mounted) return;
      if (result != null) {
        final path = result['imagePath'] as String?;
        final rawText = (result['text'] as String?)?.trim() ?? '';
        final blocks = (result['blocks'] as List<TextBlock>?) ?? [];

        if (path != null && !kIsWeb) {
          _capturedImagePath = path;
          // Decode image dimensions to accurately calculate overlay scaling
          final file = File(path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final codec = await ui.instantiateImageCodec(bytes);
            final frame = await codec.getNextFrame();
            _imageNaturalSize = Size(
              frame.image.width.toDouble(),
              frame.image.height.toDouble(),
            );
          }
        }

        if (rawText.isNotEmpty) {
          _detectedText = rawText;
          await _translateBlocks(blocks, rawText);
        } else {
          setState(() {
            _isScanning = false;
            _detectedText = 'No text detected';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No text detected in the image. Please try again with clear lighting.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() => _isScanning = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Camera/Gallery error: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _translateBlocks(List<TextBlock> blocks, String fullText) async {
    setState(() => _isScanning = true);

    try {
      // Translate individual blocks to accurately position them on top of the image
      final List<TranslatedBlockItem> translatedList = [];
      for (final block in blocks) {
        final blockClean = block.text.trim();
        if (blockClean.isEmpty) continue;

        final translated = await TranslationService.instance.translate(
          text: blockClean,
          fromCode: _sourceLang.code,
          toCode: _targetLang.code,
          mode: 'camera',
        );

        translatedList.add(
          TranslatedBlockItem(
            originalText: blockClean,
            translatedText: translated,
            boundingBox: block.boundingBox,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _translatedBlocks = translatedList;
        _isScanning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isScanning = false);
    }
  }

  Future<void> _saveOrShareTranslatedImage() async {
    if (_capturedImagePath == null) return;

    try {
      setState(() => _isSavingImage = true);

      // Render the RepaintBoundary (contains image + in-place translation boxes)
      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        setState(() => _isSavingImage = false);
        return;
      }

      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        setState(() => _isSavingImage = false);
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final savedFile = File(
        '${tempDir.path}/translated_image_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await savedFile.writeAsBytes(pngBytes);

      setState(() => _isSavingImage = false);

      // Open Android/iOS Share & Save modal sheet
      await Share.shareXFiles(
        [XFile(savedFile.path)],
        text: 'Translated image via Talk & Translate AI',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image rendered with translated layers! Select Save or Share.'),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSavingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving translated image: $e')),
        );
      }
    }
  }

  void _clearCamera() {
    setState(() {
      _detectedText = 'Point at text or select photo';
      _capturedImagePath = null;
      _translatedBlocks = [];
      _imageNaturalSize = null;
    });
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
                title: 'Camera',
                subtitle: 'Point at signs, menus or labels',
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
                  if (_detectedText != 'Point at text or select photo' &&
                      _detectedText.isNotEmpty) {
                    _captureWithAiCamera(false);
                  }
                },
                onSourceChanged: (l) {
                  setState(() => _sourceLang = l);
                  if (_detectedText != 'Point at text or select photo' &&
                      _detectedText.isNotEmpty) {
                    _captureWithAiCamera(false);
                  }
                },
                onTargetChanged: (l) {
                  setState(() => _targetLang = l);
                  if (_detectedText != 'Point at text or select photo' &&
                      _detectedText.isNotEmpty) {
                    _captureWithAiCamera(false);
                  }
                },
              ),
              const SizedBox(height: 14),

              // Viewfinder & In-Place Translation Canvas
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Stack(
                      children: [
                        // RepaintBoundary capturing image + overlay layers for saving
                        Positioned.fill(
                          child: RepaintBoundary(
                            key: _repaintBoundaryKey,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final viewWidth = constraints.maxWidth;
                                final viewHeight = constraints.maxHeight;

                                return Stack(
                                  children: [
                                    // Captured image
                                    if (_capturedImagePath != null && !kIsWeb)
                                      Positioned.fill(
                                        child: Image.file(
                                          File(_capturedImagePath!),
                                          fit: BoxFit.contain,
                                        ),
                                      ),

                                    // Empty state background
                                    if (_capturedImagePath == null)
                                      Container(
                                        color: const Color(0xFF0F172A),
                                      ),

                                    // Real-Time In-Place Text Overlay on top of Original Picture
                                    if (_capturedImagePath != null &&
                                        _imageNaturalSize != null &&
                                        _imageNaturalSize!.width > 0 &&
                                        _translatedBlocks.isNotEmpty)
                                      ..._buildInPlaceOverlays(
                                        viewWidth: viewWidth,
                                        viewHeight: viewHeight,
                                        imgWidth: _imageNaturalSize!.width,
                                        imgHeight: _imageNaturalSize!.height,
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),

                        // Professional Viewfinder Focus Reticle (when no image is captured)
                        if (_capturedImagePath == null)
                          Center(
                            child: Container(
                              width: 260,
                              height: 260,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 1.5,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  // Top-Left Corner
                                  Positioned(
                                    top: -1,
                                    left: -1,
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          top: BorderSide(color: AppColors.primary, width: 3.5),
                                          left: BorderSide(color: AppColors.primary, width: 3.5),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Top-Right Corner
                                  Positioned(
                                    top: -1,
                                    right: -1,
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          top: BorderSide(color: AppColors.primary, width: 3.5),
                                          right: BorderSide(color: AppColors.primary, width: 3.5),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Bottom-Left Corner
                                  Positioned(
                                    bottom: -1,
                                    left: -1,
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(color: AppColors.primary, width: 3.5),
                                          left: BorderSide(color: AppColors.primary, width: 3.5),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Bottom-Right Corner
                                  Positioned(
                                    bottom: -1,
                                    right: -1,
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(color: AppColors.primary, width: 3.5),
                                          right: BorderSide(color: AppColors.primary, width: 3.5),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Empty State Guide Prompt
                        if (_capturedImagePath == null)
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                  child: Icon(
                                    CupertinoIcons.viewfinder,
                                    size: 42,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'Aim camera at signs, labels or text',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Words will be replaced in-place on the picture',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Top Bar Actions (Save / Share & Status)
                        if (_capturedImagePath != null)
                          Positioned(
                            top: 14,
                            left: 14,
                            right: 14,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(CupertinoIcons.checkmark_seal_fill,
                                          color: AppColors.primary, size: 14),
                                      const SizedBox(width: 6),
                                      Text(
                                        'In-Place AR Overlay (${_translatedBlocks.length} items)',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Save / Share Translated Picture Action Button
                                InkWell(
                                  onTap: _isSavingImage ? null : _saveOrShareTranslatedImage,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_isSavingImage)
                                          const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        else
                                          const Icon(
                                            CupertinoIcons.arrow_down_doc_fill,
                                            color: Colors.white,
                                            size: 15,
                                          ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'Save Picture',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),



                        // Scanning Indicator
                        if (_isScanning)
                          Positioned(
                            top: 20,
                            right: 20,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Replacing words...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Bottom Control Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Import from Gallery
                    InkWell(
                      onTap: _isScanning ? null : () => _captureWithAiCamera(false),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.photo_on_rectangle,
                              size: 20,
                              color: AppColors.textPrimary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Gallery',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Primary Shutter Camera Button
                    GestureDetector(
                      onTap: _isScanning ? null : () => _captureWithAiCamera(true),
                      child: Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.38),
                              blurRadius: 18,
                              spreadRadius: 2,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(
                              CupertinoIcons.camera_fill,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Reset / Clear Button
                    InkWell(
                      onTap: _clearCamera,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.arrow_counterclockwise,
                              size: 19,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Clear',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // Calculate coordinates to map bounding boxes precisely onto BoxFit.contain image
  List<Widget> _buildInPlaceOverlays({
    required double viewWidth,
    required double viewHeight,
    required double imgWidth,
    required double imgHeight,
  }) {
    final double scaleX = viewWidth / imgWidth;
    final double scaleY = viewHeight / imgHeight;
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    final double renderedWidth = imgWidth * scale;
    final double renderedHeight = imgHeight * scale;

    final double offsetX = (viewWidth - renderedWidth) / 2;
    final double offsetY = (viewHeight - renderedHeight) / 2;

    return _translatedBlocks.map((item) {
      final rect = item.boundingBox;

      final left = offsetX + (rect.left * scale);
      final top = offsetY + (rect.top * scale);
      final width = (rect.width * scale).clamp(24.0, viewWidth);
      final height = (rect.height * scale).clamp(18.0, viewHeight);

      return Positioned(
        left: left,
        top: top,
        width: width,
        height: height,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: AppColors.primary,
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Text(
              item.translatedText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}
