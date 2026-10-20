import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class AppLanguage {
  final String name;
  final String flag;
  final String code;
  final String speechCode;

  const AppLanguage({
    required this.name,
    required this.flag,
    required this.code,
    required this.speechCode,
  });
}

const List<AppLanguage> supportedLanguages = [
  AppLanguage(name: 'English', flag: '🇺🇸', code: 'en', speechCode: 'en-US'),
  AppLanguage(name: 'Spanish', flag: '🇪🇸', code: 'es', speechCode: 'es-ES'),
  AppLanguage(name: 'French', flag: '🇫🇷', code: 'fr', speechCode: 'fr-FR'),
  AppLanguage(name: 'German', flag: '🇩🇪', code: 'de', speechCode: 'de-DE'),
  AppLanguage(name: 'Italian', flag: '🇮🇹', code: 'it', speechCode: 'it-IT'),
  AppLanguage(
      name: 'Portuguese (Brazil)',
      flag: '🇧🇷',
      code: 'pt',
      speechCode: 'pt-BR'),
  AppLanguage(name: 'Japanese', flag: '🇯🇵', code: 'ja', speechCode: 'ja-JP'),
  AppLanguage(name: 'Korean', flag: '🇰🇷', code: 'ko', speechCode: 'ko-KR'),
  AppLanguage(
      name: 'Chinese, Simplified',
      flag: '🇨🇳',
      code: 'zh-cn',
      speechCode: 'zh-CN'),
  AppLanguage(
      name: 'Chinese, Traditional',
      flag: '🇹🇼',
      code: 'zh-tw',
      speechCode: 'zh-TW'),
  AppLanguage(name: 'Arabic', flag: '🇪🇬', code: 'ar', speechCode: 'ar-EG'),
];

TranslateLanguage getMlKitLanguage(String code) {
  switch (code.toLowerCase()) {
    case 'ar':
      return TranslateLanguage.arabic;
    case 'fr':
      return TranslateLanguage.french;
    case 'es':
      return TranslateLanguage.spanish;
    case 'de':
      return TranslateLanguage.german;
    case 'it':
      return TranslateLanguage.italian;
    case 'pt':
      return TranslateLanguage.portuguese;
    case 'ja':
      return TranslateLanguage.japanese;
    case 'ko':
      return TranslateLanguage.korean;
    case 'zh-cn':
    case 'zh-tw':
      return TranslateLanguage.chinese;
    case 'en':
    default:
      return TranslateLanguage.english;
  }
}

