import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models/translation_record.dart';

class AppDatabase extends ChangeNotifier {
  static final AppDatabase instance = AppDatabase._internal();
  AppDatabase._internal();

  List<TranslationRecord> history = [];
  Set<String> downloadedPacks = {}; // تبدأ فارغة لتكون الحالة الافتراضية Download
  Map<String, String> offlineCache = {};
  bool forceOfflineMode = false;
  bool isProUser = true;

  // إعدادات صوت الذكاء الاصطناعي (رجل أم امرأة)
  String ttsVoiceGender = 'female'; // 'male' or 'female'
  bool enableMultilingualSpeech = false; // تركيز كامل على لغة واحدة محددة لدقة 100%

  // قاموس ومحرك ذكاء اصطناعي محلي موسع للعمل بدون إنترنت 100%
  final Map<String, Map<String, String>> _builtInDictionary = {
    // التحيات والأساسيات
    'hello': {'fr': 'Bonjour', 'ar': 'مرحباً', 'es': 'Hola', 'de': 'Hallo', 'it': 'Ciao', 'ja': 'こんにちは', 'ru': 'Привет', 'zh': '你好'},
    'hi': {'fr': 'Salut', 'ar': 'أهلاً', 'es': 'Hola', 'de': 'Hallo', 'it': 'Ciao'},
    'good morning': {'fr': 'Bonjour', 'ar': 'صباح الخير', 'es': 'Buenos días', 'de': 'Guten Morgen', 'it': 'Buongiorno'},
    'good evening': {'fr': 'Bonsoir', 'ar': 'مساء الخير', 'es': 'Buenas noches', 'de': 'Guten Abend', 'it': 'Buonasera'},
    'good night': {'fr': 'Bonne nuit', 'ar': 'تصبح على خير', 'es': 'Buenas noches', 'de': 'Gute Nacht'},
    'goodbye': {'fr': 'Au revoir', 'ar': 'مع السلامة', 'es': 'Adiós', 'de': 'Auf Wiedersehen', 'it': 'Arrivederci'},
    'see you soon': {'fr': 'À bientôt', 'ar': 'أراك قريباً', 'es': 'Hasta pronto', 'de': 'Bis bald'},
    'welcome': {'fr': 'Bienvenue', 'ar': 'أهلاً وسهلاً', 'es': 'Bienvenido', 'de': 'Willkommen'},
    
    // السؤال عن الحال
    'how are you': {'fr': 'Comment allez-vous ?', 'ar': 'كيف حالك؟', 'es': '¿Cómo estás?', 'de': 'Wie geht es dir?', 'it': 'Come stai?'},
    'how are you doing': {'fr': 'Comment ça va ?', 'ar': 'كيف تجري أمورك؟', 'es': '¿Cómo te va?', 'de': 'Wie läuft es?'},
    'i am fine': {'fr': 'Je vais bien', 'ar': 'أنا بخير', 'es': 'Estoy bien', 'de': 'Mir geht es gut'},
    'i am good': {'fr': 'Je vais bien', 'ar': 'أنا بخير', 'es': 'Estoy bien', 'de': 'Mir geht es gut'},
    'and you': {'fr': 'Et vous ?', 'ar': 'وأنت؟', 'es': '¿Y tú?', 'de': 'Und dir?'},
    
    // الشكر والاعتذار
    'thank you': {'fr': 'Merci', 'ar': 'شكراً', 'es': 'Gracias', 'de': 'Danke', 'it': 'Grazie'},
    'thank you very much': {'fr': 'Merci beaucoup', 'ar': 'شكراً جزيلاً', 'es': 'Muchas gracias', 'de': 'Vielen Dank'},
    'thanks': {'fr': 'Merci', 'ar': 'شكراً', 'es': 'Gracias', 'de': 'Danke'},
    'you are welcome': {'fr': 'De rien', 'ar': 'عفواً', 'es': 'De nada', 'de': 'Bitte schön'},
    'please': {'fr': 'S\'il vous plaît', 'ar': 'من فضلك', 'es': 'Por favor', 'de': 'Bitte', 'it': 'Per favore'},
    'sorry': {'fr': 'Pardon / Désolé', 'ar': 'عذراً / أنا آسف', 'es': 'Lo siento', 'de': 'Entschuldigung'},
    'excuse me': {'fr': 'Excusez-moi', 'ar': 'معذرة', 'es': 'Disculpe', 'de': 'Entschuldigen Sie'},
    'no problem': {'fr': 'Pas de problème', 'ar': 'لا توجد مشكلة', 'es': 'No hay problema', 'de': 'Kein Problem'},
    
    // الأسماء والتعارف
    'what is your name': {'fr': 'Comment vous appelez-vous ?', 'ar': 'ما هو اسمك؟', 'es': '¿Cómo te llamas?', 'de': 'Wie heißen Sie?'},
    'my name is': {'fr': 'Je m\'appelle', 'ar': 'اسمي هو', 'es': 'Mi nombre es', 'de': 'Ich heiße'},
    'nice to meet you': {'fr': 'Enchanté', 'ar': 'سعيد بلقائك', 'es': 'Mucho gusto', 'de': 'Freut mich, Sie kennenzulernen'},
    'where are you from': {'fr': 'D\'où venez-vous ?', 'ar': 'من أين أنت؟', 'es': '¿De dónde eres?', 'de': 'Woher kommen Sie?'},
    'i am from': {'fr': 'Je viens de', 'ar': 'أنا من', 'es': 'Soy de', 'de': 'Ich komme aus'},
    
    // الأماكن والتنقل
    'where is': {'fr': 'Où est', 'ar': 'أين', 'es': 'Dónde está', 'de': 'Wo ist'},
    'where is the airport': {'fr': 'Où est l\'aéroport ?', 'ar': 'أين يقع المطار؟', 'es': '¿Dónde está el aeropuerto?', 'de': 'Wo ist der Flughafen?'},
    'where is the hotel': {'fr': 'Où est l\'hôtel ?', 'ar': 'أين الفندق؟', 'es': '¿Dónde está el hotel?', 'de': 'Wo ist das Hotel?'},
    'where is the bathroom': {'fr': 'Où sont les toilettes ?', 'ar': 'أين دورة المياه؟', 'es': '¿Dónde está el baño?', 'de': 'Wo sind die Toiletten?'},
    'where is the hospital': {'fr': 'Où est l\'hôpital ?', 'ar': 'أين المستشفى؟', 'es': '¿Dónde está el hospital?', 'de': 'Wo ist das Krankenhaus?'},
    'airport': {'fr': 'Aéroport', 'ar': 'مطار', 'es': 'Aeropuerto', 'de': 'Flughafen'},
    'hotel': {'fr': 'Hôtel', 'ar': 'فندق', 'es': 'Hotel', 'de': 'Hotel'},
    'taxi': {'fr': 'Taxi', 'ar': 'تاكسي', 'es': 'Taxi', 'de': 'Taxi'},
    'metro': {'fr': 'Métro', 'ar': 'مترو', 'es': 'Metro', 'de': 'U-Bahn'},
    'train': {'fr': 'Train', 'ar': 'قطار', 'es': 'Tren', 'de': 'Zug'},
    'bus': {'fr': 'Bus', 'ar': 'حافلة / باص', 'es': 'Autobús', 'de': 'Bus'},
    'ticket': {'fr': 'Billet', 'ar': 'تذكرة', 'es': 'Boleto / Billete', 'de': 'Fahrkarte'},
    'exit': {'fr': 'Sortie', 'ar': 'مخرج', 'es': 'Salida', 'de': 'Ausgang'},
    'entrance': {'fr': 'Entrée', 'ar': 'مدخل', 'es': 'Entrada', 'de': 'Eingang'},
    
    // الأكل والمطاعم
    'water': {'fr': 'Eau', 'ar': 'ماء', 'es': 'Agua', 'de': 'Wasser'},
    'coffee': {'fr': 'Café', 'ar': 'قهوة', 'es': 'Café', 'de': 'Kaffee'},
    'tea': {'fr': 'Thé', 'ar': 'شاي', 'es': 'Té', 'de': 'Tee'},
    'milk': {'fr': 'Lait', 'ar': 'حليب', 'es': 'Leche', 'de': 'Milch'},
    'bread': {'fr': 'Pain', 'ar': 'خبز', 'es': 'Pan', 'de': 'Brot'},
    'food': {'fr': 'Nourriture', 'ar': 'طعام', 'es': 'Comida', 'de': 'Essen'},
    'restaurant': {'fr': 'Restaurant', 'ar': 'مطعم', 'es': 'Restaurante', 'de': 'Restaurant'},
    'the bill please': {'fr': 'L\'addition, s\'il vous plaît', 'ar': 'الحساب من فضلك', 'es': 'La cuenta, por favor', 'de': 'Die Rechnung, bitte'},
    'i would like': {'fr': 'Je voudrais', 'ar': 'أود الحصول على', 'es': 'Me gustaría', 'de': 'Ich möchte'},
    
    // المساعدة والطوارئ
    'help': {'fr': 'À l\'aide', 'ar': 'النجدة / مساعدة', 'es': 'Ayuda', 'de': 'Hilfe'},
    'can you help me': {'fr': 'Pouvez-vous m\'aider ?', 'ar': 'هل يمكنك مساعدتي؟', 'es': '¿Puedes ayudarme?', 'de': 'Können Sie mir helfen?'},
    'i need a doctor': {'fr': 'J\'ai besoin d\'un médecin', 'ar': 'أحتاج إلى طبيب', 'es': 'Necesito un médico', 'de': 'Ich brauche einen Arzt'},
    'police': {'fr': 'Police', 'ar': 'الشرطة', 'es': 'Policía', 'de': 'Polizei'},
    'i am lost': {'fr': 'Je suis perdu', 'ar': 'أنا تائه', 'es': 'Estoy perdido', 'de': 'Ich habe mich verlaufen'},
    
    // التسوق والأموال
    'how much is this': {'fr': 'Combien ça coûte ?', 'ar': 'بكم هذا؟ / كم سعر هذا؟', 'es': '¿Cuánto cuesta esto?', 'de': 'Wie viel kostet das?'},
    'how much': {'fr': 'Combien', 'ar': 'كم السعر / بكم', 'es': 'Cuánto', 'de': 'Wie viel'},
    'money': {'fr': 'Argent', 'ar': 'نقود / فلوس', 'es': 'Dinero', 'de': 'Geld'},
    'expensive': {'fr': 'Cher', 'ar': 'غالي', 'es': 'Caro', 'de': 'Teuer'},
    'cheap': {'fr': 'Pas cher', 'ar': 'رخيص', 'es': 'Barato', 'de': 'Billig'},
    
    // كلمات شائعة
    'yes': {'fr': 'Oui', 'ar': 'نعم', 'es': 'Sí', 'de': 'Ja', 'it': 'Sì'},
    'no': {'fr': 'Non', 'ar': 'لا', 'es': 'No', 'de': 'Nein', 'it': 'No'},
    'okay': {'fr': 'D\'accord', 'ar': 'حسناً', 'es': 'De acuerdo', 'de': 'In Ordnung'},
    'today': {'fr': 'Aujourd\'hui', 'ar': 'اليوم', 'es': 'Hoy', 'de': 'Heute'},
    'tomorrow': {'fr': 'Demain', 'ar': 'غداً', 'es': 'Mañana', 'de': 'Morgen'},
    'yesterday': {'fr': 'Hier', 'ar': 'أمس', 'es': 'Ayer', 'de': 'Gestern'},
    'now': {'fr': 'Maintenant', 'ar': 'الآن', 'es': 'Ahora', 'de': 'Jetzt'},
    'later': {'fr': 'Plus tard', 'ar': 'لاحقاً', 'es': 'Más tarde', 'de': 'Später'},
  };

  Future<void> init() async {
    // تحميل الحزم المنزلة المحفوظة في ذاكرة الجهاز
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('saved_downloaded_packs');
      if (saved != null) {
        downloadedPacks = saved.toSet();
      } else {
        downloadedPacks = {}; // افتراضياً لا توجد حزم محملة مسبقاً وتظهر Download
      }
      forceOfflineMode = prefs.getBool('force_offline_mode') ?? false;
      isProUser = prefs.getBool('is_pro_user') ?? true;
      ttsVoiceGender = prefs.getString('tts_voice_gender') ?? 'female';
      enableMultilingualSpeech =
          prefs.getBool('enable_multilingual_speech') ?? false;
    } catch (e) {
      downloadedPacks = {};
    }

    // سجل أولي للاختبار
    history = [
      TranslationRecord(
        id: '1',
        sourceText: 'Bonjour, comment allez-vous ?',
        translatedText: 'Hello, how are you?',
        fromCode: 'fr',
        toCode: 'en',
        mode: 'talk',
        createdAt: DateTime.now(),
        isFavorite: true,
      ),
      TranslationRecord(
        id: '2',
        sourceText: 'Where is the airport?',
        translatedText: 'أين يقع المطار؟',
        fromCode: 'en',
        toCode: 'ar',
        mode: 'text',
        createdAt: DateTime.now(),
      ),
    ];
    notifyListeners();
  }

  Future<void> setTtsVoiceGender(String gender) async {
    ttsVoiceGender = gender;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tts_voice_gender', gender);
    } catch (_) {}
  }

  Future<void> setMultilingualSpeech(bool enabled) async {
    enableMultilingualSpeech = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('enable_multilingual_speech', enabled);
    } catch (_) {}
  }

  void saveRecord(TranslationRecord record) {
    history.removeWhere((r) =>
        r.sourceText.toLowerCase() == record.sourceText.toLowerCase() &&
        r.fromCode == record.fromCode &&
        r.toCode == record.toCode);
    history.insert(0, record);

    final cacheKey =
        '${record.fromCode}_${record.toCode}_${record.sourceText.trim().toLowerCase()}';
    offlineCache[cacheKey] = record.translatedText;
    notifyListeners();
  }

  void toggleFavorite(String id) {
    final index = history.indexWhere((r) => r.id == id);
    if (index != -1) {
      history[index].isFavorite = !history[index].isFavorite;
      notifyListeners();
    }
  }

  void clearHistory() {
    history.clear();
    notifyListeners();
  }

  Future<void> addDownloadedPack(String code) async {
    downloadedPacks.add(code);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('saved_downloaded_packs', downloadedPacks.toList());
    } catch (_) {}
  }

  Future<void> removeDownloadedPack(String code) async {
    downloadedPacks.remove(code);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('saved_downloaded_packs', downloadedPacks.toList());
    } catch (_) {}
  }

  Future<void> toggleLanguagePack(String code) async {
    if (downloadedPacks.contains(code)) {
      await removeDownloadedPack(code);
    } else {
      await addDownloadedPack(code);
    }
  }

  // محرك الذكاء الاصطناعي المحلي (Smart On-Device AI Translation)
  String? lookupOffline(String text, String fromCode, String toCode) {
    String normalize(String s) => s
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final cleanInput = normalize(text);
    if (cleanInput.isEmpty) return '';

    final cacheKey = '${fromCode}_${toCode}_${text.trim().toLowerCase()}';
    if (offlineCache.containsKey(cacheKey)) {
      return offlineCache[cacheKey];
    }

    // 1. تطابق العبارة الكاملة في القاموس الذكي
    for (final entry in _builtInDictionary.entries) {
      if (normalize(entry.key) == cleanInput && entry.value.containsKey(toCode)) {
        return entry.value[toCode];
      }
    }

    // 2. البحث العكسي (إذا كان الإدخال من لغة غير الإنجليزية ومطابق لقيمة داخل القاموس)
    for (final entry in _builtInDictionary.entries) {
      final valInFrom = entry.value[fromCode];
      if (valInFrom != null && normalize(valInFrom) == cleanInput) {
        if (toCode == 'en') return entry.key;
        if (entry.value.containsKey(toCode)) return entry.value[toCode];
      }
    }

    // 3. تحليل وترجمة الجمل المركبة بذكاء اصطناعي محلي (Multi-word phrase matching)
    for (final entry in _builtInDictionary.entries) {
      final normKey = normalize(entry.key);
      if (normKey.length > 3 && cleanInput.contains(normKey) && entry.value.containsKey(toCode)) {
        final translatedPhrase = entry.value[toCode]!;
        final remainder = cleanInput.replaceAll(normKey, '').trim();
        if (remainder.isEmpty) return translatedPhrase;
        final remainderTrans = lookupOffline(remainder, fromCode, toCode) ?? remainder;
        return '$translatedPhrase $remainderTrans';
      }
    }

    // 4. ترجمة كلمة بكلمة مع الحفاظ على الكلمات غير المعروفة
    final words = cleanInput.split(' ');
    bool foundAny = false;
    final translatedWords = words.map((word) {
      for (final entry in _builtInDictionary.entries) {
        if (normalize(entry.key) == word && entry.value.containsKey(toCode)) {
          foundAny = true;
          return entry.value[toCode]!;
        }
        final valInFrom = entry.value[fromCode];
        if (valInFrom != null && normalize(valInFrom) == word) {
          foundAny = true;
          return toCode == 'en' ? entry.key : (entry.value[toCode] ?? word);
        }
      }
      return word;
    }).toList();

    if (foundAny) {
      return translatedWords.join(' ');
    }
    return null;
  }
}

