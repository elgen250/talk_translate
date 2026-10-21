import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/models/app_language.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/card_decoration.dart';
import '../../core/widgets/language_selector_row.dart';
import '../../core/widgets/shared_top_bar.dart';
import '../../data/app_database.dart';
import '../../data/translation_service.dart';
import '../../data/offline_voice_service.dart';
import '../offline_mode/offline_mode_screen.dart';
import '../../shared/settings_modal.dart';

class TalkTranslateView extends StatefulWidget {
  const TalkTranslateView({super.key});

  @override
  State<TalkTranslateView> createState() => _TalkTranslateViewState();
}

class _TalkTranslateViewState extends State<TalkTranslateView> {
  AppLanguage _sourceLang = supportedLanguages[0]; // English
  AppLanguage _targetLang = supportedLanguages[10]; // Arabic
  String _spokenText = '';
  String _translatedText = '';
  bool _isListening = false;
  bool _isTranslating = false;

  // Track Online (Wi-Fi) vs Local (Offline AI) mode dynamically
  bool _isOnline = true;
  bool _isUsingLocalAi = false;
  Timer? _connectivityTimer;

  // PRO Feature: Split-Screen Face-to-Face Dual Mode
  bool _isSplitMode = false;
  bool _isSpeakerTwoListening = false;
  String _speakerTwoSpokenText = '';
  String _speakerTwoTranslatedText = '';

  String? _offlineNotice;

  // Real-Time Live Streaming Translation
  Timer? _liveDebounceTimer;
  String _lastLiveTranslatedText = '';
  int _liveTranslateRequestId = 0;

  // Track whether the user explicitly stopped listening
  bool _userRequestedStop = false;
  String _accumulatedSpokenText = '';
  String _speakerTwoAccumulatedSpokenText = '';
  Timer? _restartSttTimer;

  // ScrollControllers for auto-scrolling long speech and translations
  final ScrollController _spokenScrollController = ScrollController();
  final ScrollController _translatedScrollController = ScrollController();
  final ScrollController _speakerTwoSpokenScrollController = ScrollController();
  final ScrollController _speakerTwoTranslatedScrollController = ScrollController();

  void _scrollToBottom(ScrollController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasClients) {
        controller.animateTo(
          controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _connectivityTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _checkConnectivity();
    });
  }

  @override
  void dispose() {
    _userRequestedStop = true;
    _isRestartingStt = false;
    _connectivityTimer?.cancel();
    _liveDebounceTimer?.cancel();
    _restartSttTimer?.cancel();
    try {
      TranslationService.instance.speech?.stop();
    } catch (_) {}
    _spokenScrollController.dispose();
    _translatedScrollController.dispose();
    _speakerTwoSpokenScrollController.dispose();
    _speakerTwoTranslatedScrollController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final hasNet = !AppDatabase.instance.forceOfflineMode &&
        await TranslationService.instance.hasInternetConnection();
    if (mounted && _isOnline != hasNet) {
      setState(() {
        _isOnline = hasNet;
        if (hasNet) {
          _isUsingLocalAi = false;
        }
      });
    }
  }

  void _swapLanguages() {
    _liveDebounceTimer?.cancel();
    setState(() {
      final temp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = temp;
      _spokenText = '';
      _translatedText = '';
      _accumulatedSpokenText = '';
      _speakerTwoSpokenText = '';
      _speakerTwoTranslatedText = '';
      _speakerTwoAccumulatedSpokenText = '';
    });
  }

  // ترجمة فورية ولحظية أثناء الكلام بدون انتظار إغلاق المايك (Live Streaming Translation)
  void _liveTranslate(String text,
      {required bool fromSpeakerTwo, required bool isFinal}) {
    final clean = text.trim();
    if (clean.isEmpty) return;

    _liveDebounceTimer?.cancel();
    final duration =
        isFinal ? Duration.zero : const Duration(milliseconds: 180);

    _liveDebounceTimer = Timer(duration, () async {
      if (!mounted) return;
      final currentRequestId = ++_liveTranslateRequestId;
      _lastLiveTranslatedText = clean;

      final from = fromSpeakerTwo ? _targetLang : _sourceLang;
      final to = fromSpeakerTwo ? _sourceLang : _targetLang;

      if (mounted) setState(() => _isTranslating = true);

      try {
        final res = await TranslationService.instance.translate(
          text: clean,
          fromCode: from.code,
          toCode: to.code,
          mode: 'talk',
        );

        if (!mounted || currentRequestId != _liveTranslateRequestId) return;

        setState(() {
          if (fromSpeakerTwo) {
            _speakerTwoTranslatedText = res;
          } else {
            _translatedText = res;
          }
          _isTranslating = false;
        });
        _scrollToBottom(fromSpeakerTwo
            ? _speakerTwoTranslatedScrollController
            : _translatedScrollController);
      } catch (e) {
        debugPrint('Live translation error: $e');
        if (mounted && currentRequestId == _liveTranslateRequestId) {
          setState(() => _isTranslating = false);
        }
      }
    });
  }




  void _showQuickTextInput({required bool speakerTwo}) {
    final activeLang = speakerTwo ? _targetLang : _sourceLang;
    final toLang = speakerTwo ? _sourceLang : _targetLang;
    final controller = TextEditingController(
      text: speakerTwo ? _speakerTwoSpokenText : _spokenText,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${activeLang.flag} ${activeLang.name} ➔ ${toLang.flag} ${toLang.name}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter text to translate offline with AI...',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(CupertinoIcons.doc_on_clipboard),
                    label: const Text('Paste'),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        controller.text = data!.text!;
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(CupertinoIcons.arrow_right_circle,
                        color: Colors.white),
                    label: const Text('Translate',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                    onPressed: () {
                      final text = controller.text.trim();
                      if (text.isNotEmpty) {
                        Navigator.pop(ctx);
                        setState(() {
                          if (speakerTwo) {
                            _speakerTwoSpokenText = text;
                          } else {
                            _spokenText = text;
                          }
                        });
                        _liveTranslate(text,
                            fromSpeakerTwo: speakerTwo, isFinal: true);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Tracking current continuous STT chunk
  String _currentSessionWords = '';
  String _speakerTwoCurrentSessionWords = '';
  bool _isRestartingStt = false;

  void _commitCurrentSessionWords({required bool speakerTwo}) {
    if (speakerTwo) {
      final chunk = _speakerTwoCurrentSessionWords.trim();
      if (chunk.isNotEmpty) {
        _speakerTwoAccumulatedSpokenText = _speakerTwoAccumulatedSpokenText.isEmpty
            ? chunk
            : '$_speakerTwoAccumulatedSpokenText $chunk';
        _speakerTwoCurrentSessionWords = '';
        debugPrint('STT commit [speakerTwo]: "$chunk" -> total: "$_speakerTwoAccumulatedSpokenText"');
      }
    } else {
      final chunk = _currentSessionWords.trim();
      if (chunk.isNotEmpty) {
        _accumulatedSpokenText = _accumulatedSpokenText.isEmpty
            ? chunk
            : '$_accumulatedSpokenText $chunk';
        _currentSessionWords = '';
        debugPrint('STT commit [speakerOne]: "$chunk" -> total: "$_accumulatedSpokenText"');
      }
    }
  }

  Future<bool> _startContinuousOnlineListen({required bool speakerTwo}) async {
    try {
      final available = await TranslationService.instance.initSpeech(
        onError: (err) {
          if (!mounted || _userRequestedStop) return;
          debugPrint('STT notice (online live): $err');
          final errStr = err.toString().toLowerCase();
          _commitCurrentSessionWords(speakerTwo: speakerTwo);
          if (errStr.contains('error_no_match') ||
              errStr.contains('error_speech_timeout')) {
            _scheduleContinuousRestart(
                speakerTwo: speakerTwo, reason: 'silence_timeout', delayMs: 250);
          } else if (errStr.contains('error_busy') || errStr.contains('error_client')) {
            _scheduleContinuousRestart(
                speakerTwo: speakerTwo, reason: 'busy_client_backoff', delayMs: 400);
          } else {
            _scheduleContinuousRestart(
                speakerTwo: speakerTwo, reason: 'error: $err', delayMs: 400);
          }
        },
        onStatus: (status) {
          if (!mounted || _userRequestedStop) return;
          debugPrint('STT status (online live): $status');
          if (status == 'notListening' || status == 'done' || status == 'doneNoResult') {
            _commitCurrentSessionWords(speakerTwo: speakerTwo);
            _scheduleContinuousRestart(
                speakerTwo: speakerTwo, reason: 'status: $status', delayMs: 250);
          }
        },
      );

      if (available && TranslationService.instance.speech != null) {
        final activeLang = speakerTwo ? _targetLang : _sourceLang;
        String effectiveLocale = activeLang.speechCode;
        try {
          final locales = await TranslationService.instance.speech!.locales();
          if (locales.isNotEmpty) {
            final exactMatch = locales.where(
              (l) =>
                  l.localeId.toLowerCase().replaceAll('_', '-') ==
                  effectiveLocale.toLowerCase().replaceAll('_', '-'),
            );
            if (exactMatch.isNotEmpty) {
              effectiveLocale = exactMatch.first.localeId;
            } else {
              final prefixMatch = locales.where(
                (l) => l.localeId
                    .toLowerCase()
                    .startsWith(activeLang.code.toLowerCase()),
              );
              if (prefixMatch.isNotEmpty) {
                effectiveLocale = prefixMatch.first.localeId;
              }
            }
          }
        } catch (e) {
          debugPrint('Locale lookup error: $e');
        }

        debugPrint('STT starting listen with locale: $effectiveLocale (active: ${activeLang.name})');

        await TranslationService.instance.speech!.listen(
          listenOptions: stt.SpeechListenOptions(
            listenFor: const Duration(hours: 1),
            pauseFor: const Duration(seconds: 15),
            localeId: effectiveLocale,
            onDevice: false,
            cancelOnError: false,
            partialResults: true,
            listenMode: stt.ListenMode.dictation,
          ),
          onResult: (result) {
            if (!mounted || _userRequestedStop) return;
            final words = result.recognizedWords.trim();
            debugPrint('STT onResult: words="$words", isFinal=${result.finalResult}');

            if (words.isNotEmpty) {
              _offlineNotice = null;
              if (speakerTwo) {
                _speakerTwoCurrentSessionWords = words;
              } else {
                _currentSessionWords = words;
              }

              final prefix = speakerTwo
                  ? _speakerTwoAccumulatedSpokenText
                  : _accumulatedSpokenText;
              final fullText = prefix.isEmpty ? words : '$prefix $words';

              setState(() {
                if (speakerTwo) {
                  _speakerTwoSpokenText = fullText;
                } else {
                  _spokenText = fullText;
                }
              });
              _scrollToBottom(speakerTwo
                  ? _speakerTwoSpokenScrollController
                  : _spokenScrollController);

              if (fullText != _lastLiveTranslatedText) {
                _liveTranslate(fullText,
                    fromSpeakerTwo: speakerTwo, isFinal: result.finalResult);
              }
            }

            if (result.finalResult && words.isNotEmpty) {
              _commitCurrentSessionWords(speakerTwo: speakerTwo);
            }
          },
        );
        return true;
      }
    } catch (e) {
      debugPrint('Online speech start error: $e');
      _commitCurrentSessionWords(speakerTwo: speakerTwo);
      _scheduleContinuousRestart(
          speakerTwo: speakerTwo, reason: 'exception: $e', delayMs: 400);
    }
    return false;
  }

  void _scheduleContinuousRestart({
    required bool speakerTwo,
    required String reason,
    int delayMs = 350,
  }) {
    if (!mounted || _userRequestedStop) return;
    final stillActive = speakerTwo ? _isSpeakerTwoListening : _isListening;
    if (!stillActive) return;

    // Prevent duplicate clashing timers from multiple done/error events
    if (_isRestartingStt) return;
    _isRestartingStt = true;

    _restartSttTimer?.cancel();
    _restartSttTimer = Timer(Duration(milliseconds: delayMs), () async {
      _isRestartingStt = false;
      if (!mounted || _userRequestedStop) return;
      final active = speakerTwo ? _isSpeakerTwoListening : _isListening;
      if (!active) return;

      // If already listening natively, avoid clashing
      if (TranslationService.instance.speech?.isListening == true) {
        debugPrint('Continuous STT recognizer already active, skipping.');
        return;
      }

      debugPrint('Continuous STT restarting cleanly (trigger: $reason)...');
      _startContinuousOnlineListen(speakerTwo: speakerTwo);
    });
  }

  Future<void> _toggleListening({bool speakerTwo = false}) async {
    final isCurrentlyListening =
        speakerTwo ? _isSpeakerTwoListening : _isListening;

    if (isCurrentlyListening) {
      _userRequestedStop = true;
      _isRestartingStt = false;
      _restartSttTimer?.cancel();

      if (OfflineVoiceService.instance.isRecording) {
        setState(() {
          if (speakerTwo) {
            _isSpeakerTwoListening = false;
          } else {
            _isListening = false;
          }
          _isTranslating = true;
        });

        final activeLang = speakerTwo ? _targetLang : _sourceLang;
        final recognized = await OfflineVoiceService.instance
            .stopRecordingAndTranscribe(langCode: activeLang.code);

        if (!mounted) return;
        setState(() => _isTranslating = false);

        if (recognized != null && recognized.isNotEmpty) {
          setState(() {
            if (speakerTwo) {
              _speakerTwoSpokenText = recognized;
            } else {
              _spokenText = recognized;
            }
          });
          _liveTranslate(recognized, fromSpeakerTwo: speakerTwo, isFinal: true);
        }
        return;
      }

      try {
        await TranslationService.instance.speech?.stop();
      } catch (_) {}
      _liveDebounceTimer?.cancel();
      if (!mounted) return;
      setState(() {
        if (speakerTwo) {
          _isSpeakerTwoListening = false;
        } else {
          _isListening = false;
        }
      });

      // الترجمة تظهر على الشاشة فقط، ونطق الصوت لا يعمل تلقائياً أبداً
      // بل يعمل فقط وحصرياً عندما يضغط المستخدم بنفسه على أيقونة السماعة في كارت الترجمة
      return;
    }

    // Starting new listening session - reset user stop flag
    _userRequestedStop = false;
    _isRestartingStt = false;
    _restartSttTimer?.cancel();

    // Auto-detect connectivity to switch between Online (Wi-Fi) and Local (Offline AI)
    final forceOffline = AppDatabase.instance.forceOfflineMode;
    final hasNet = !forceOffline &&
        await TranslationService.instance.hasInternetConnection();

    _isOnline = hasNet;
    _isUsingLocalAi = !hasNet;

    // Immediately activate listening state so UI pulses and stays responsive
    setState(() {
      if (speakerTwo) {
        _isSpeakerTwoListening = true;
        _speakerTwoSpokenText = '';
        _speakerTwoTranslatedText = '';
        _speakerTwoAccumulatedSpokenText = '';
        _speakerTwoCurrentSessionWords = '';
      } else {
        _isListening = true;
        _spokenText = '';
        _translatedText = '';
        _accumulatedSpokenText = '';
        _currentSessionWords = '';
      }
      _offlineNotice = null;
    });

    // 1. ONLINE MODE: Use online cloud speech recognition with streaming partial words
    if (hasNet) {
      final success = await _startContinuousOnlineListen(speakerTwo: speakerTwo);
      if (success) return;
      if (mounted) setState(() => _isUsingLocalAi = true);
    }

    // 2. OFFLINE MODE: Use local Whisper model or on-device speech
    _isUsingLocalAi = true;

    // Check if on-device Whisper model is downloaded and ready
    final isVoiceModelReady =
        await OfflineVoiceService.instance.isVoiceModelReady();

    if (isVoiceModelReady) {
      final started = await OfflineVoiceService.instance.startRecording();
      if (!started && mounted) {
        setState(() {
          _isListening = false;
          _isSpeakerTwoListening = false;
        });
      }
      return;
    }

    // Fallback to system STT engine with onDevice: true
    try {
      final available = await TranslationService.instance.initSpeech(
        onError: (err) {
          if (!mounted) return;
          final errStr = err?.toString().toLowerCase() ?? '';
          debugPrint('STT notice (safe offline): $errStr');
          if (errStr.contains('error_language_unavailable') ||
              errStr.contains('error_network')) {
            setState(() {
              _offlineNotice =
                  'لتشغيل التعرف الصوتي 100% بدون إنترنت، قم بتحميل نموذج الصوت الذكي (Whisper) من شاشة Offline AI Models.';
            });
          }
        },
        onStatus: (status) {
          if (!mounted) return;
          debugPrint('STT status (safe offline): $status');
        },
      );

      if (available && TranslationService.instance.speech != null) {
        final activeLang = speakerTwo ? _targetLang : _sourceLang;
        String effectiveLocale = activeLang.speechCode;
        try {
          final locales = await TranslationService.instance.speech!.locales();
          if (locales.isNotEmpty) {
            final exactMatch = locales.where(
              (l) =>
                  l.localeId.toLowerCase().replaceAll('_', '-') ==
                  effectiveLocale.toLowerCase().replaceAll('_', '-'),
            );
            if (exactMatch.isNotEmpty) {
              effectiveLocale = exactMatch.first.localeId;
            } else {
              final prefixMatch = locales.where(
                (l) => l.localeId
                    .toLowerCase()
                    .startsWith(activeLang.code.toLowerCase()),
              );
              if (prefixMatch.isNotEmpty) {
                effectiveLocale = prefixMatch.first.localeId;
              }
            }
          }
        } catch (e) {
          debugPrint('Locale lookup error: $e');
        }

        await TranslationService.instance.speech!.listen(
          listenOptions: stt.SpeechListenOptions(
            localeId: effectiveLocale,
            onDevice: true,
            cancelOnError: false,
            partialResults: true,
            listenMode: stt.ListenMode.dictation,
          ),
          onResult: (result) {
            if (!mounted) return;
            final words = result.recognizedWords;
            setState(() {
              if (words.isNotEmpty) _offlineNotice = null;
              if (speakerTwo) {
                _speakerTwoSpokenText = words;
              } else {
                _spokenText = words;
              }
            });

            // البدء بالترجمة فورياً ولحظياً أثناء نطق الكلمات دون انتظار إغلاق المايك
            final currentSpoken =
                (speakerTwo ? _speakerTwoSpokenText : _spokenText).trim();
            if (currentSpoken.isNotEmpty &&
                currentSpoken != _lastLiveTranslatedText) {
              _liveTranslate(currentSpoken,
                  fromSpeakerTwo: speakerTwo, isFinal: result.finalResult);
            }

            if (result.finalResult) {
              _liveDebounceTimer?.cancel();
              setState(() {
                _isListening = false;
                _isSpeakerTwoListening = false;
              });
              if (currentSpoken.isNotEmpty) {
                _liveTranslate(currentSpoken,
                    fromSpeakerTwo: speakerTwo, isFinal: true);
              }
            }
          },
        );
      }
    } catch (e) {
      debugPrint('Speech listen attempt handled safely: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSplitMode) {
      return _buildSplitConversationScreen();
    }
    return _buildStandardTalkScreen();
  }

  Widget _buildStandardTalkScreen() {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SharedTopBar(
                title: 'Talk',
                subtitle: _isOnline
                    ? 'Speak and translate live (Wi-Fi)'
                    : 'Speak and translate (Local AI)',
                onSettingsTap: () => showSettingsModal(context),
              ),
              const SizedBox(height: 12),

              // PRO Mode Switcher: Standard vs Split Conversation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: LanguageSelectorRow(
                      source: _sourceLang,
                      target: _targetLang,
                      onSwap: _swapLanguages,
                      onSourceChanged: (l) => setState(() => _sourceLang = l),
                      onTargetChanged: (l) => setState(() => _targetLang = l),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => setState(() => _isSplitMode = true),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.person_2_fill,
                              color: AppColors.primary, size: 20),
                          Text(
                            'DUAL',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Source Card
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                _sourceLang.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (_isListening) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: _isUsingLocalAi
                                        ? Colors.blue.withValues(alpha: 0.15)
                                        : Colors.redAccent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.fiber_manual_record,
                                        size: 8,
                                        color: _isUsingLocalAi
                                            ? Colors.blue
                                            : Colors.redAccent,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _isUsingLocalAi ? 'LOCAL' : 'LIVE',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: _isUsingLocalAi
                                              ? Colors.blue
                                              : Colors.redAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(_sourceLang.flag,
                              style: const TextStyle(fontSize: 18)),
                        ],
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _spokenScrollController,
                          physics: const BouncingScrollPhysics(),
                          child: Text(
                            _spokenText.isEmpty
                                ? (_isListening
                                    ? (_isUsingLocalAi
                                        ? '🎙️ الاستماع بالذكاء الاصطناعي المحلي (Local)... تحدث ثم انقر المايك للترجمة'
                                        : 'Listening live... Speak now')
                                    : 'Tap microphone to speak')
                                : _spokenText,
                            style: TextStyle(
                              fontSize: 19,
                              color: _spokenText.isEmpty
                                  ? AppColors.textHint
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      if (_offlineNotice != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(CupertinoIcons.info_circle_fill,
                                  color: Colors.amber.shade800, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _offlineNotice!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.amber.shade900,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const OfflineModeScreen()),
                                  );
                                },
                                child: const Text(
                                  'تنزيل',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_spokenText.isNotEmpty)
                        Align(
                          alignment: Alignment.bottomRight,
                          child: IconButton(
                            icon: const Icon(CupertinoIcons.speaker_2,
                                color: AppColors.textHint),
                            onPressed: () => TranslationService.instance
                                .speak(_spokenText, _sourceLang.speechCode),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Target Card
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                _targetLang.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (_isListening && _translatedText.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: _isUsingLocalAi
                                        ? Colors.blue.withValues(alpha: 0.15)
                                        : AppColors.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _isUsingLocalAi ? 'LOCAL AI' : 'LIVE AI',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: _isUsingLocalAi
                                          ? Colors.blue
                                          : AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(_targetLang.flag,
                              style: const TextStyle(fontSize: 18)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: _isTranslating
                            ? const Row(
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Translating...',
                                    style: TextStyle(
                                      fontSize: 17,
                                      color: AppColors.textHint,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              )
                            : SingleChildScrollView(
                                controller: _translatedScrollController,
                                physics: const BouncingScrollPhysics(),
                                child: Text(
                                  _translatedText.isEmpty
                                      ? 'Translation will appear here'
                                      : _translatedText,
                                  style: TextStyle(
                                    fontSize: 19,
                                    color: _translatedText.isEmpty
                                        ? AppColors.textHint
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(CupertinoIcons.speaker_2,
                                color: AppColors.textHint),
                            onPressed: () => TranslationService.instance
                                .speak(_translatedText, _targetLang.speechCode),
                          ),
                          IconButton(
                            icon: const Icon(CupertinoIcons.doc_on_doc,
                                color: AppColors.textHint),
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
                            icon: const Icon(CupertinoIcons.share,
                                color: AppColors.textHint),
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
              ),
              const SizedBox(height: 16),

              // Floating Mic Button + Keyboard Quick Type + Clear
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(CupertinoIcons.keyboard,
                        color: AppColors.primary, size: 28),
                    onPressed: () => _showQuickTextInput(speakerTwo: false),
                    tooltip: 'Type message',
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () => _toggleListening(speakerTwo: false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: _isListening ? 78 : 70,
                      height: _isListening ? 78 : 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isListening
                            ? (_isUsingLocalAi ? Colors.blueAccent : Colors.redAccent)
                            : AppColors.primary,
                        boxShadow: [
                          BoxShadow(
                            color: (_isListening
                                    ? (_isUsingLocalAi ? Colors.blueAccent : Colors.redAccent)
                                    : AppColors.primary)
                                .withValues(alpha: 0.35),
                            blurRadius: 20,
                            spreadRadius: 5,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isListening
                            ? CupertinoIcons.stop_fill
                            : CupertinoIcons.mic_fill,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    icon: const Icon(CupertinoIcons.trash,
                        color: AppColors.textHint, size: 24),
                    onPressed: () {
                      setState(() {
                        _spokenText = '';
                        _translatedText = '';
                        _accumulatedSpokenText = '';
                      });
                    },
                    tooltip: 'Clear',
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // PRO Split Face-to-Face Dual Mic Mode
  Widget _buildSplitConversationScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            // Exit button bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'PRO: Dual Conversation Mode',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark_circle_fill,
                        color: Colors.white70, size: 24),
                    onPressed: () => setState(() => _isSplitMode = false),
                  ),
                ],
              ),
            ),

            // Top Half: Person 2 (Inverted 180° so they see it right-side-up)
            Expanded(
              child: RotatedBox(
                quarterTurns: 2,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _isSpeakerTwoListening
                          ? (_isUsingLocalAi ? Colors.blue : Colors.redAccent)
                          : Colors.white12,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_targetLang.flag} ${_targetLang.name}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                          Container(
                            padding: _isSpeakerTwoListening
                                ? const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3)
                                : EdgeInsets.zero,
                            decoration: _isSpeakerTwoListening
                                ? BoxDecoration(
                                    color: (_isUsingLocalAi
                                            ? Colors.blue
                                            : Colors.redAccent)
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  )
                                : null,
                            child: Text(
                              _isSpeakerTwoListening
                                  ? (_isUsingLocalAi ? 'LOCAL' : 'LIVE')
                                  : 'THEIR TURN',
                              style: TextStyle(
                                color: _isSpeakerTwoListening
                                    ? (_isUsingLocalAi
                                        ? Colors.blueAccent
                                        : Colors.redAccent)
                                    : Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _speakerTwoSpokenScrollController,
                          physics: const BouncingScrollPhysics(),
                          child: Center(
                            child: Text(
                              _speakerTwoSpokenText.isNotEmpty
                                  ? _speakerTwoSpokenText
                                  : (_speakerTwoTranslatedText.isNotEmpty
                                      ? _speakerTwoTranslatedText
                                      : 'Tap mic and speak across table'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(CupertinoIcons.keyboard,
                                color: Colors.white70, size: 22),
                            onPressed: () =>
                                _showQuickTextInput(speakerTwo: true),
                            tooltip: 'Type',
                          ),
                          const SizedBox(width: 14),
                          GestureDetector(
                            onTap: () => _toggleListening(speakerTwo: true),
                            child: Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isSpeakerTwoListening
                                    ? (_isUsingLocalAi
                                        ? Colors.blueAccent
                                        : Colors.redAccent)
                                    : Colors.teal,
                              ),
                              child: Icon(
                                _isSpeakerTwoListening
                                    ? CupertinoIcons.stop_fill
                                    : CupertinoIcons.mic_fill,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          IconButton(
                            icon: const Icon(CupertinoIcons.trash,
                                color: Colors.white38, size: 20),
                            onPressed: () => setState(() {
                              _speakerTwoSpokenText = '';
                              _speakerTwoTranslatedText = '';
                              _speakerTwoAccumulatedSpokenText = '';
                            }),
                            tooltip: 'Clear',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Divider(color: Colors.white24, height: 1),

            // Bottom Half: Person 1 (Facing You)
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isListening
                        ? (_isUsingLocalAi ? Colors.blue : Colors.redAccent)
                        : Colors.white12,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_sourceLang.flag} ${_sourceLang.name}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        Container(
                          padding: _isListening
                              ? const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3)
                              : EdgeInsets.zero,
                          decoration: _isListening
                              ? BoxDecoration(
                                  color: (_isUsingLocalAi
                                          ? Colors.blue
                                          : Colors.redAccent)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                )
                              : null,
                          child: Text(
                            _isListening
                                ? (_isUsingLocalAi ? 'LOCAL' : 'LIVE')
                                : 'YOUR TURN',
                            style: TextStyle(
                              color: _isListening
                                  ? (_isUsingLocalAi
                                      ? Colors.blueAccent
                                      : Colors.redAccent)
                                  : Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _spokenScrollController,
                        physics: const BouncingScrollPhysics(),
                        child: Center(
                          child: Text(
                            _spokenText.isNotEmpty
                                ? _spokenText
                                : (_translatedText.isNotEmpty
                                    ? _translatedText
                                    : 'Tap mic and speak'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 18),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(CupertinoIcons.keyboard,
                              color: Colors.white70, size: 22),
                          onPressed: () =>
                              _showQuickTextInput(speakerTwo: false),
                          tooltip: 'Type',
                        ),
                        const SizedBox(width: 14),
                        GestureDetector(
                          onTap: () => _toggleListening(speakerTwo: false),
                          child: Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isListening
                                  ? (_isUsingLocalAi
                                      ? Colors.blueAccent
                                      : Colors.redAccent)
                                  : AppColors.primary,
                            ),
                            child: Icon(
                              _isListening
                                  ? CupertinoIcons.stop_fill
                                  : CupertinoIcons.mic_fill,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        IconButton(
                          icon: const Icon(CupertinoIcons.trash,
                              color: Colors.white38, size: 20),
                          onPressed: () => setState(() {
                            _spokenText = '';
                            _translatedText = '';
                            _accumulatedSpokenText = '';
                          }),
                          tooltip: 'Clear',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
