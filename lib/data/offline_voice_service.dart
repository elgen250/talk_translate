import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

class OfflineVoiceService {
  static final OfflineVoiceService instance = OfflineVoiceService._internal();
  OfflineVoiceService._internal();

  final AudioRecorder _audioRecorder = AudioRecorder();
  sherpa.OfflineRecognizer? _recognizer;
  bool _bindingsInitialized = false;
  bool _isRecording = false;
  String? _currentRecordingPath;
  String? _lastLoadedLang;

  bool get isRecording => _isRecording;

  void initBindings() {
    if (_bindingsInitialized) return;
    try {
      sherpa.initBindings();
      _bindingsInitialized = true;
      debugPrint('Sherpa-onnx bindings initialized successfully');
    } catch (e) {
      debugPrint('Sherpa bindings init error: $e');
    }
  }

  Future<Directory> getModelDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${appDir.path}/sherpa_whisper_tiny');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir;
  }

  Future<bool> isVoiceModelReady() async {
    try {
      final dir = await getModelDirectory();
      final encoder = File('${dir.path}/tiny-encoder.int8.onnx');
      final decoder = File('${dir.path}/tiny-decoder.int8.onnx');
      final tokens = File('${dir.path}/tiny-tokens.txt');

      return (await encoder.exists()) &&
          (await encoder.length() > 5000000) &&
          (await decoder.exists()) &&
          (await decoder.length() > 20000000) &&
          (await tokens.exists()) &&
          (await tokens.length() > 100000);
    } catch (_) {
      return false;
    }
  }

  static const String tokensUrl =
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main/tiny-tokens.txt';
  static const String encoderUrl =
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main/tiny-encoder.int8.onnx';
  static const String decoderUrl =
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main/tiny-decoder.int8.onnx';

  Future<bool> downloadVoiceModel({
    Function(double progress, String status)? onProgress,
  }) async {
    try {
      final dir = await getModelDirectory();
      final client = http.Client();

      final files = [
        {'name': 'tiny-tokens.txt', 'url': tokensUrl, 'weight': 0.05},
        {'name': 'tiny-encoder.int8.onnx', 'url': encoderUrl, 'weight': 0.25},
        {'name': 'tiny-decoder.int8.onnx', 'url': decoderUrl, 'weight': 0.70},
      ];

      double cumulativeProgress = 0.0;

      for (final f in files) {
        final filename = f['name'] as String;
        final url = f['url'] as String;
        final weight = f['weight'] as double;
        final targetFile = File('${dir.path}/$filename');

        if (await targetFile.exists() && await targetFile.length() > 100000) {
          cumulativeProgress += weight;
          onProgress?.call(cumulativeProgress, 'Ready: $filename');
          continue;
        }

        onProgress?.call(cumulativeProgress, 'Downloading $filename...');
        final req = http.Request('GET', Uri.parse(url));
        final response = await client.send(req);

        if (response.statusCode != 200) {
          debugPrint('Failed to download $filename: status ${response.statusCode}');
          return false;
        }

        final totalBytes = response.contentLength ?? 1;
        int receivedBytes = 0;
        final tempFile = File('${dir.path}/$filename.tmp');
        if (await tempFile.exists()) await tempFile.delete();
        final sink = tempFile.openWrite();

        await response.stream.listen((chunk) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          final fileProgress = receivedBytes / totalBytes;
          final currentOverall = cumulativeProgress + (fileProgress * weight);
          onProgress?.call(
            currentOverall.clamp(0.0, 1.0),
            'Downloading $filename (${(fileProgress * 100).toInt()}%)',
          );
        }).asFuture();

        await sink.flush();
        await sink.close();

        if (await targetFile.exists()) await targetFile.delete();
        await tempFile.rename(targetFile.path);
        cumulativeProgress += weight;
      }

      client.close();
      onProgress?.call(1.0, 'Model ready!');
      return await isVoiceModelReady();
    } catch (e) {
      debugPrint('Download voice model error: $e');
      return false;
    }
  }

  Future<void> deleteVoiceModel() async {
    try {
      _recognizer?.free();
      _recognizer = null;
      _lastLoadedLang = null;

      final dir = await getModelDirectory();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Delete voice model error: $e');
    }
  }

  Future<bool> _loadRecognizerForLanguage(String langCode) async {
    initBindings();
    final cacheKey = langCode;

    if (_recognizer != null && _lastLoadedLang == cacheKey) {
      return true;
    }

    try {
      _recognizer?.free();
      _recognizer = null;

      final dir = await getModelDirectory();
      final encoderPath = '${dir.path}/tiny-encoder.int8.onnx';
      final decoderPath = '${dir.path}/tiny-decoder.int8.onnx';
      final tokensPath = '${dir.path}/tiny-tokens.txt';

      // تثبيت اللغة المحددة بدقة 100% دون تشتيت النموذج بين لغات أخرى
      String whisperLang = langCode.toLowerCase().trim();
      if (whisperLang.contains('_')) {
        whisperLang = whisperLang.split('_').first;
      } else if (whisperLang.contains('-')) {
        whisperLang = whisperLang.split('-').first;
      }

      final config = sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          whisper: sherpa.OfflineWhisperModelConfig(
            encoder: encoderPath,
            decoder: decoderPath,
            language: whisperLang,
            task: 'transcribe',
          ),
          tokens: tokensPath,
          numThreads: 2,
          debug: false,
          provider: 'cpu',
        ),
        decodingMethod: 'greedy_search',
      );

      _recognizer = sherpa.OfflineRecognizer(config);
      _lastLoadedLang = cacheKey;
      debugPrint('Loaded OfflineRecognizer for: $whisperLang');
      return true;
    } catch (e) {
      debugPrint('Error loading recognizer: $e');
      return false;
    }
  }

  Future<bool> startRecording() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      _currentRecordingPath =
          '${tempDir.path}/offline_speech_${DateTime.now().millisecondsSinceEpoch}.wav';
      final file = File(_currentRecordingPath!);
      if (await file.exists()) await file.delete();

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      debugPrint('Started recording to $_currentRecordingPath');
      return true;
    } catch (e) {
      debugPrint('Start recording error: $e');
      _isRecording = false;
      return false;
    }
  }

  // ==========================================
  // REAL-TIME LIVE STREAMING RECOGNITION (ASR)
  // ==========================================
  StreamSubscription<Uint8List>? _micStreamSub;
  final List<double> _accumulatedSamples = [];
  bool _isLiveStreaming = false;
  bool _isDecoding = false;
  DateTime _lastDecodeTime = DateTime.now();
  String _latestLiveHypothesis = '';

  bool get isLiveStreaming => _isLiveStreaming;

  Future<bool> startLiveStreaming({
    required String langCode,
    required void Function(String liveText) onTextUpdate,
  }) async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        debugPrint('Microphone permission not granted');
        return false;
      }

      final loaded = await _loadRecognizerForLanguage(langCode);
      if (!loaded || _recognizer == null) {
        debugPrint('Failed to load OfflineRecognizer for $langCode');
        return false;
      }

      await stopLiveStreaming();

      _accumulatedSamples.clear();
      _latestLiveHypothesis = '';
      _isDecoding = false;
      _lastDecodeTime = DateTime.now();

      final stream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      _isLiveStreaming = true;
      _isRecording = true;

      _micStreamSub = stream.listen(
        (data) {
          if (!_isLiveStreaming) return;

          // Convert PCM 16-bit little endian bytes to float32 samples [-1.0, 1.0]
          final byteData = ByteData.sublistView(data);
          final sampleCount = data.length ~/ 2;
          for (int i = 0; i < sampleCount; i++) {
            final sampleInt = byteData.getInt16(i * 2, Endian.little);
            _accumulatedSamples.add(sampleInt / 32768.0);
          }

          // Trigger decoding periodically if we have at least ~0.8s of audio
          // and at least 600ms have elapsed since last decode
          final now = DateTime.now();
          if (_accumulatedSamples.length >= 12800 &&
              !_isDecoding &&
              now.difference(_lastDecodeTime).inMilliseconds >= 550) {
            _runIntermediateDecode(onTextUpdate);
          }
        },
        onError: (err) {
          debugPrint('Audio record stream error: $err');
          _isLiveStreaming = false;
          _isRecording = false;
        },
        onDone: () {
          debugPrint('Audio record stream done');
          _isLiveStreaming = false;
          _isRecording = false;
        },
        cancelOnError: false,
      );

      debugPrint('Live streaming speech recognition started for lang: $langCode');
      return true;
    } catch (e) {
      debugPrint('Start live streaming error: $e');
      _isLiveStreaming = false;
      _isRecording = false;
      return false;
    }
  }

  void _runIntermediateDecode(void Function(String liveText) onTextUpdate) async {
    if (_isDecoding || _recognizer == null || _accumulatedSamples.length < 8000) {
      return;
    }

    _isDecoding = true;
    _lastDecodeTime = DateTime.now();

    try {
      // Snapshot samples up to current length
      final samplesSnapshot = Float32List.fromList(_accumulatedSamples);
      final stream = _recognizer!.createStream();
      stream.acceptWaveform(samples: samplesSnapshot, sampleRate: 16000);
      _recognizer!.decode(stream);
      final result = _recognizer!.getResult(stream);
      stream.free();

      final text = result.text.trim();
      if (text.isNotEmpty && text != _latestLiveHypothesis) {
        _latestLiveHypothesis = text;
        onTextUpdate(text);
        debugPrint('Live ASR update: "$text"');
      }
    } catch (e) {
      debugPrint('Error during intermediate decode: $e');
    } finally {
      _isDecoding = false;
    }
  }

  Future<String?> stopLiveStreaming() async {
    if (!_isLiveStreaming && _micStreamSub == null && !_isRecording) {
      return null;
    }

    _isLiveStreaming = false;
    _isRecording = false;

    try {
      await _micStreamSub?.cancel();
      _micStreamSub = null;
      await _audioRecorder.stop();
    } catch (e) {
      debugPrint('Stop audio recorder stream error: $e');
    }

    // Final decode pass on all accumulated audio
    if (_recognizer != null && _accumulatedSamples.length >= 4000) {
      try {
        final samplesSnapshot = Float32List.fromList(_accumulatedSamples);
        final stream = _recognizer!.createStream();
        stream.acceptWaveform(samples: samplesSnapshot, sampleRate: 16000);
        _recognizer!.decode(stream);
        final result = _recognizer!.getResult(stream);
        stream.free();
        final finalResult = result.text.trim();
        _accumulatedSamples.clear();
        debugPrint('Final Live ASR Result: "$finalResult"');
        return finalResult.isNotEmpty ? finalResult : _latestLiveHypothesis;
      } catch (e) {
        debugPrint('Final decode error: $e');
      }
    }

    _accumulatedSamples.clear();
    return _latestLiveHypothesis.isNotEmpty ? _latestLiveHypothesis : null;
  }

  Future<String?> stopRecordingAndTranscribe({required String langCode}) async {
    if (_isLiveStreaming) {
      return await stopLiveStreaming();
    }
    if (!_isRecording) return null;

    try {
      final path = await _audioRecorder.stop();
      _isRecording = false;

      if (path == null) return null;
      final file = File(path);
      if (!await file.exists() || await file.length() < 2000) {
        debugPrint('Recorded file is too small or missing');
        return null;
      }

      final loaded = await _loadRecognizerForLanguage(langCode);
      if (!loaded || _recognizer == null) {
        debugPrint('OfflineRecognizer not loaded');
        return null;
      }

      final waveData = sherpa.readWave(path);
      if (waveData.samples.isEmpty) {
        debugPrint('Waveform has no samples');
        return null;
      }

      final stream = _recognizer!.createStream();
      stream.acceptWaveform(
        samples: waveData.samples,
        sampleRate: waveData.sampleRate,
      );

      _recognizer!.decode(stream);
      final result = _recognizer!.getResult(stream);
      final text = result.text.trim();
      stream.free();

      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}

      debugPrint('Offline Speech Recognition Result: "$text"');
      return text;
    } catch (e) {
      debugPrint('Transcribe error: $e');
      _isRecording = false;
      return null;
    }
  }

  void cancelRecording() async {
    try {
      _isLiveStreaming = false;
      await _micStreamSub?.cancel();
      _micStreamSub = null;
      _accumulatedSamples.clear();
      if (_isRecording) {
        await _audioRecorder.stop();
        _isRecording = false;
      }
    } catch (_) {}
  }
}


