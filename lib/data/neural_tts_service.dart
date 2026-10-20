import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_edge_tts/flutter_edge_tts.dart';
import 'app_database.dart';

class NeuralTtsService {
  static final NeuralTtsService instance = NeuralTtsService._internal();
  NeuralTtsService._internal();

  final AudioPlayer _player = AudioPlayer();

  // Microsoft Neural Studio Voices (Ultra-Realistic Human Speech)
  static const Map<String, Map<String, String>> _voices = {
    'ar': {
      'male': 'ar-SA-HamedNeural',      // صوت عربي فصيح، عميق، مخارج حروف استوديو
      'female': 'ar-SA-ZariyahNeural',  // صوت عربي إذاعي نقي ومريح
    },
    'en': {
      'male': 'en-US-GuyNeural',
      'female': 'en-US-JennyNeural',
    },
    'fr': {
      'male': 'fr-FR-HenriNeural',
      'female': 'fr-FR-DeniseNeural',
    },
    'es': {
      'male': 'es-ES-AlvaroNeural',
      'female': 'es-ES-ElviraNeural',
    },
    'de': {
      'male': 'de-DE-ConradNeural',
      'female': 'de-DE-KatjaNeural',
    },
    'it': {
      'male': 'it-IT-DiegoNeural',
      'female': 'it-IT-ElsaNeural',
    },
    'ru': {
      'male': 'ru-RU-DmitryNeural',
      'female': 'ru-RU-SvetlanaNeural',
    },
    'tr': {
      'male': 'tr-TR-AhmetNeural',
      'female': 'tr-TR-EmelNeural',
    },
    'ja': {
      'male': 'ja-JP-KeitaNeural',
      'female': 'ja-JP-NanamiNeural',
    },
    'zh': {
      'male': 'zh-CN-YunxiNeural',
      'female': 'zh-CN-XiaoxiaoNeural',
    },
    'ko': {
      'male': 'ko-KR-InJoonNeural',
      'female': 'ko-KR-SunHiNeural',
    },
    'pt': {
      'male': 'pt-BR-AntonioNeural',
      'female': 'pt-BR-FranciscaNeural',
    },
    'hi': {
      'male': 'hi-IN-MadhurNeural',
      'female': 'hi-IN-SwaraNeural',
    },
  };

  String getVoiceName(String langCode, bool isMale) {
    final code = langCode.toLowerCase().split('-')[0].split('_')[0];
    final genderKey = isMale ? 'male' : 'female';
    if (_voices.containsKey(code)) {
      return _voices[code]![genderKey]!;
    }
    return isMale ? 'en-US-GuyNeural' : 'en-US-JennyNeural';
  }

  Future<bool> speak({
    required String text,
    required String langCode,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return false;

    final isMale = AppDatabase.instance.ttsVoiceGender == 'male';
    final voice = getVoiceName(langCode, isMale);

    try {
      await _player.stop();
      final edgeTts = FlutterEdgeTts(
        voice: voice,
        outputFormat: EdgeTtsOutputFormat.audio24Khz96KbitrateMonoMp3,
        connectionTimeout: const Duration(seconds: 10),
      );

      final EdgeTtsSynthesisResult result = await edgeTts.synthesize(clean);
      if (result.audioBytes.isNotEmpty) {
        await _player.play(BytesSource(result.audioBytes));
        return true;
      }
    } catch (e) {
      debugPrint('Neural TTS error: $e');
    }
    return false;
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }
}
