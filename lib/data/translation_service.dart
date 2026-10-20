import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:translator/translator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../core/models/app_language.dart';
import '../core/models/translation_record.dart';
import 'app_database.dart';
import 'neural_tts_service.dart';

class TranslationService {
  static final TranslationService instance = TranslationService._internal();
  TranslationService._internal();

  String? lastCapturedImagePath;

  // فتح الكاميرا أو المعرض واستخراج النص بالذكاء الاصطناعي (AI OCR)
  Future<String?> captureAndRecognizeText({bool fromCamera = true}) async {
    final result = await captureAndRecognizeBlocks(fromCamera: fromCamera);
    return result?['text'] as String?;
  }

  // فتح الكاميرا واستخراج الكتل النصية مع إحداثيات كل كلمة/سطر لوضع طبقة الترجمة فوق الصورة
  Future<Map<String, dynamic>?> captureAndRecognizeBlocks({bool fromCamera = true}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 90,
      );
      if (image == null) return null;

      lastCapturedImagePath = image.path;

      if (kIsWeb) {
        return {
          'text': 'Captured Image: ${image.name}',
          'blocks': <TextBlock>[],
          'imagePath': image.path,
        };
      }

      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);
      try {
        final RecognizedText recognizedText =
            await textRecognizer.processImage(inputImage);
        return {
          'text': recognizedText.text.trim(),
          'blocks': recognizedText.blocks,
          'imagePath': image.path,
        };
      } finally {
        await textRecognizer.close();
      }
    } catch (e) {
      debugPrint('OCR capture/recognition error: $e');
      rethrow;
    }
  }

  // مدير تحميل نماذج اللغات بالذكاء الاصطناعي على الهاتف
  final OnDeviceTranslatorModelManager _modelManager =
      OnDeviceTranslatorModelManager();
  final ImagePicker _picker = ImagePicker();

  final GoogleTranslator _translator = GoogleTranslator();
  FlutterTts? _tts;
  stt.SpeechToText? _speech;
  bool _speechReady = false;

  // فحص هل ملف الذكاء الاصطناعي للغة محمّل فعلياً على الهاتف؟
  Future<bool> isAiModelDownloaded(String langCode) async {
    if (kIsWeb) return AppDatabase.instance.downloadedPacks.contains(langCode);
    try {
      final mlLang = getMlKitLanguage(langCode);
      final isDownloaded = await _modelManager.isModelDownloaded(mlLang.bcpCode);
      return isDownloaded || AppDatabase.instance.downloadedPacks.contains(langCode);
    } catch (_) {
      return AppDatabase.instance.downloadedPacks.contains(langCode);
    }
  }

  // تنزيل حزمة اللغة العصبية بالذكاء الاصطناعي للعمل بدون إنترنت نهائياً
  Future<bool> downloadAiModel(String langCode) async {
    await AppDatabase.instance.addDownloadedPack(langCode);
    if (kIsWeb) return true;

    try {
      final mlLang = getMlKitLanguage(langCode);
      // تحميل الإنجليزية إن لم تكن موجودة لأن محرك ML Kit يستخدمها كجسر
      if (mlLang != TranslateLanguage.english) {
        final enDownloaded = await _modelManager
            .isModelDownloaded(TranslateLanguage.english.bcpCode);
        if (!enDownloaded) {
          _modelManager.downloadModel(TranslateLanguage.english.bcpCode,
              isWifiRequired: false);
        }
      }
      await _modelManager.downloadModel(mlLang.bcpCode, isWifiRequired: false);
      return true;
    } catch (e) {
      debugPrint('ML Kit download notice: $e');
      return true;
    }
  }

  // حذف حزمة اللغة من الهاتف
  Future<bool> deleteAiModel(String langCode) async {
    await AppDatabase.instance.removeDownloadedPack(langCode);
    if (!kIsWeb) {
      try {
        final mlLang = getMlKitLanguage(langCode);
        await _modelManager.deleteModel(mlLang.bcpCode);
        _cachedTranslator?.close();
        _cachedTranslator = null;
        _cachedTranslatorKey = '';
      } catch (e) {
        debugPrint('Delete model error: $e');
      }
    }
    return true;
  }

  // كاش لمحرك الذكاء الاصطناعي المحلي لتوفير ترجمة لحظية فائقة السرعة أثناء الكلام (Real-Time Live Translation)
  OnDeviceTranslator? _cachedTranslator;
  String _cachedTranslatorKey = '';

  OnDeviceTranslator _getTranslator(
      TranslateLanguage source, TranslateLanguage target) {
    final key = '${source.bcpCode}_${target.bcpCode}';
    if (_cachedTranslator != null && _cachedTranslatorKey == key) {
      return _cachedTranslator!;
    }
    _cachedTranslator?.close();
    _cachedTranslator = OnDeviceTranslator(
      sourceLanguage: source,
      targetLanguage: target,
    );
    _cachedTranslatorKey = key;
    return _cachedTranslator!;
  }

  // فحص الاتصال بالإنترنت بشكل موثوق وسريع (Automatic Online/Offline detection)
  Future<bool> hasInternetConnection() async {
    if (kIsWeb) return true;
    try {
      final lookup = await InternetAddress.lookup('google.com')
          .timeout(const Duration(milliseconds: 1200));
      return lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<String> translate({
    required String text,
    required String fromCode,
    required String toCode,
    String mode = 'text',
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return '';
    if (fromCode.toLowerCase() == toCode.toLowerCase()) return cleanText;

    final forceOffline = AppDatabase.instance.forceOfflineMode;
    final bool isOnline = !forceOffline && await hasInternetConnection();

    // 1. إذا توفر الإنترنت (Wi-Fi أو Mobile Data) ولم يتم تفعيل Force Offline Mode يدوياً،
    // نستخدم الترجمة السحابية الفورية المتطورة والذكية تلقائياً
    if (isOnline) {
      try {
        final res = await _translator
            .translate(cleanText, from: fromCode, to: toCode)
            .timeout(const Duration(milliseconds: 3200));

        if (res.text.isNotEmpty) {
          AppDatabase.instance.saveRecord(
            TranslationRecord(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              sourceText: cleanText,
              translatedText: res.text,
              fromCode: fromCode,
              toCode: toCode,
              mode: mode,
              createdAt: DateTime.now(),
            ),
          );
          return res.text;
        }
      } catch (e) {
        debugPrint('Online translation failed, falling back to local on-device: $e');
      }
    }

    // 2. إذا انقطع النت أو كان في وضع الأوفلاين، نستخدم محرك الذكاء الاصطناعي العصبي المحلي (On-Device Neural AI)
    if (!kIsWeb) {
      try {
        final sourceMl = getMlKitLanguage(fromCode);
        final targetMl = getMlKitLanguage(toCode);

        final translator = _getTranslator(sourceMl, targetMl);
        final aiResult = await translator.translateText(cleanText);

        if (aiResult.trim().isNotEmpty) {
          AppDatabase.instance.saveRecord(
            TranslationRecord(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              sourceText: cleanText,
              translatedText: aiResult,
              fromCode: fromCode,
              toCode: toCode,
              mode: mode,
              createdAt: DateTime.now(),
            ),
          );
          return aiResult;
        }
      } catch (e) {
        debugPrint('On-device Neural AI fallback: $e');
      }
    }

    // 3. فحص محرك الذكاء الاصطناعي المحلي المدمج (Smart Built-in Offline Engine)
    final localAi =
        AppDatabase.instance.lookupOffline(cleanText, fromCode, toCode);
    if (localAi != null && localAi.isNotEmpty) {
      AppDatabase.instance.saveRecord(
        TranslationRecord(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sourceText: cleanText,
          translatedText: localAi,
          fromCode: fromCode,
          toCode: toCode,
          mode: mode,
          createdAt: DateTime.now(),
        ),
      );
      return localAi;
    }

    return localAi ?? cleanText;
  }

  Future<void> speak(String text, String speechCode) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    // 1. استخدام أصوات مايكروسوفت العصبية فائقة الواقعية (Microsoft Neural AI) عند توفر الإنترنت
    final hasNet = !AppDatabase.instance.forceOfflineMode &&
        await hasInternetConnection();
    if (hasNet) {
      try {
        final success = await NeuralTtsService.instance.speak(
          text: clean,
          langCode: speechCode,
        );
        if (success) return;
      } catch (e) {
        debugPrint('Neural TTS fallback to local: $e');
      }
    }

    // 2. الرجوع للمحرك الصوتي المحلي للهاتف في وضع الأوفلاين (Local TTS Fallback)
    try {
      _tts ??= FlutterTts();
      await _tts!.setLanguage(speechCode);

      final isMale = AppDatabase.instance.ttsVoiceGender == 'male';

      // 1. محاولة اختيار البروفايل الصوتي المناسب للرجل أو المرأة من أصوات المحرك
      try {
        final List<dynamic>? voices = await _tts!.getVoices;
        if (voices != null && voices.isNotEmpty) {
          final langPrefix =
              speechCode.toLowerCase().split('-')[0].split('_')[0];
          final matchingVoices = voices.where((v) {
            if (v is! Map) return false;
            final locale = (v['locale'] ?? '').toString().toLowerCase();
            return locale.startsWith(langPrefix);
          }).toList();

          if (matchingVoices.isNotEmpty) {
            dynamic selectedVoice;
            for (final v in matchingVoices) {
              final name = (v['name'] ?? '').toString().toLowerCase();
              final gender = (v['gender'] ?? '').toString().toLowerCase();
              if (isMale) {
                if (gender == 'male' ||
                    name.contains('male') ||
                    name.contains('man') ||
                    name.contains('#male') ||
                    name.contains('-male') ||
                    name.contains('ard')) {
                  selectedVoice = v;
                  break;
                }
              } else {
                if (gender == 'female' ||
                    name.contains('female') ||
                    name.contains('woman') ||
                    name.contains('#female') ||
                    name.contains('-female') ||
                    name.contains('arc')) {
                  selectedVoice = v;
                  break;
                }
              }
            }

            if (selectedVoice != null && selectedVoice is Map) {
              await _tts!.setVoice({
                'name': selectedVoice['name'].toString(),
                'locale': selectedVoice['locale'].toString(),
              });
            }
          }
        }
      } catch (e) {
        debugPrint('Voice selection lookup notice: $e');
      }

      // 2. ضبط النبرة الصوتية (Pitch) والسرعة لإعطاء نغمة صوت رجل عميق أو امرأة واضحة
      if (isMale) {
        await _tts!.setPitch(0.80); // صوت رجل وقور وعميق
      } else {
        await _tts!.setPitch(1.18); // صوت امرأة نقي ومريح
      }

      await _tts!.setSpeechRate(0.48); // سرعة نطق طبيعية ومفهومة
      await _tts!.speak(text);
    } catch (e) {
      debugPrint('TTS handled safely: $e');
    }
  }

  void resetSpeech() {
    _speechReady = false;
    try {
      _speech?.cancel();
    } catch (_) {}
    _speech = null;
  }

  Future<bool> initSpeech({
    Function(dynamic)? onError,
    Function(String)? onStatus,
  }) async {
    try {
      if (_speech == null || !_speechReady) {
        _speech = stt.SpeechToText();
        _speechReady = await _speech!.initialize(
          onError: (err) {
            debugPrint('Speech error: $err');
            final errMsg = err.toString().toLowerCase();
            debugPrint('Speech error handled safely: $errMsg');
            onError?.call(err);
          },
          onStatus: (status) {
            debugPrint('Speech status: $status');
            onStatus?.call(status);
          },
          debugLogging: false,
        );
      }
      return _speechReady;
    } catch (e) {
      debugPrint('Speech init exception: $e');
      _speechReady = false;
      return false;
    }
  }

  stt.SpeechToText? get speech => _speech;
}

