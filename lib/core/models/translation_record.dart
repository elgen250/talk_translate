class TranslationRecord {
  final String id;
  final String sourceText;
  final String translatedText;
  final String fromCode;
  final String toCode;
  final String mode; // 'text', 'talk', 'camera'
  final DateTime createdAt;
  bool isFavorite;

  TranslationRecord({
    required this.id,
    required this.sourceText,
    required this.translatedText,
    required this.fromCode,
    required this.toCode,
    required this.mode,
    required this.createdAt,
    this.isFavorite = false,
  });
}

