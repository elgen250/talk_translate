import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/app_language.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/card_decoration.dart';
import '../../data/translation_service.dart';

class KeyboardTranslatorScreen extends StatefulWidget {
  const KeyboardTranslatorScreen({super.key});

  @override
  State<KeyboardTranslatorScreen> createState() =>
      _KeyboardTranslatorScreenState();
}

class _KeyboardTranslatorScreenState extends State<KeyboardTranslatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _textController = TextEditingController();
  AppLanguage _targetLang = supportedLanguages[10]; // Arabic
  bool _isTranslating = false;

  final List<Map<String, String>> _messages = [
    {
      'sender': 'Alex (Madrid)',
      'text': '¡Hola! ¿A qué hora nos vemos hoy?',
      'isMe': 'false',
      'flag': '🇪🇸'
    },
    {
      'sender': 'You',
      'text': 'I will arrive at 6 PM sharp!',
      'isMe': 'true',
      'flag': '🇺🇸'
    },
  ];

  final List<String> _quickPhrases = [
    'I will arrive soon',
    'Thank you so much',
    'Where is the meeting point?',
    'Could you please help me?',
    'Have a great day!'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _translateAndSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isTranslating = true);
    final translated = await TranslationService.instance.translate(
      text: text,
      fromCode: 'en',
      toCode: _targetLang.code,
      mode: 'keyboard',
    );

    if (!mounted) return;
    setState(() {
      _isTranslating = false;
      _messages.add({
        'sender': 'You',
        'text': '$text\n($translated)',
        'isMe': 'true',
        'flag': _targetLang.flag,
      });
      _textController.clear();
    });
  }

  Future<void> _quickTranslatePhrase(String phrase) async {
    _textController.text = phrase;
    await _translateAndSend();
  }

  Future<void> _pasteAndTranslate() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _textController.text = data.text!;
      await _translateAndSend();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard is empty')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Row(
          children: [
            Text(
              'Keyboard Translator',
              style: TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 8),
            Text(
              'PRO',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Live Keyboard Bar'),
            Tab(text: 'System Setup Guide'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLivePlaygroundTab(),
          _buildSetupGuideTab(),
        ],
      ),
    );
  }

  Widget _buildLivePlaygroundTab() {
    return Column(
      children: [
        // Simulated Chat Box
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              final isMe = msg['isMe'] == 'true';
              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(msg['flag']!,
                              style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(
                            msg['sender']!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isMe ? Colors.white70 : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        msg['text']!,
                        style: TextStyle(
                          fontSize: 15,
                          color: isMe ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Quick Phrases Bar
        Container(
          height: 38,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: _quickPhrases.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              return ActionChip(
                backgroundColor: Colors.white,
                elevation: 1,
                label: Text(
                  _quickPhrases[index],
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textPrimary),
                ),
                onPressed: () => _quickTranslatePhrase(_quickPhrases[index]),
              );
            },
          ),
        ),

        // Talk Translate Keyboard Extension Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, -2),
              )
            ],
          ),
          child: Row(
            children: [
              const Icon(CupertinoIcons.keyboard,
                  color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Translate to:',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(width: 8),
              DropdownButtonHideUnderline(
                child: DropdownButton<AppLanguage>(
                  value: _targetLang,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  icon: const Icon(CupertinoIcons.chevron_down,
                      size: 12, color: Colors.white70),
                  items: supportedLanguages.map((lang) {
                    return DropdownMenuItem(
                      value: lang,
                      child: Text('${lang.flag} ${lang.name}'),
                    );
                  }).toList(),
                  onChanged: (l) {
                    if (l != null) setState(() => _targetLang = l);
                  },
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(CupertinoIcons.doc_on_clipboard,
                    color: Colors.white70, size: 18),
                tooltip: 'Paste & Translate',
                onPressed: _pasteAndTranslate,
              ),
            ],
          ),
        ),

        // Text Input Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: 'Type message in any language...',
                        hintStyle:
                            TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _translateAndSend(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isTranslating ? null : _translateAndSend,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: _isTranslating
                        ? const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            ),
                          )
                        : const Icon(CupertinoIcons.arrow_up,
                            color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSetupGuideTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(CupertinoIcons.check_mark_circled_solid,
                        color: Colors.green, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Android Instant Text Translation',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Talk Translate is registered on your Android system to translate text from any app (WhatsApp, Chrome, Telegram, Messages, Notes).',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                _stepTile(
                    1, 'Highlight/Select any text inside any app on your phone.'),
                _stepTile(2,
                    'Tap the 3 dots (...) in the popup context menu (Copy / Share).'),
                _stepTile(3,
                    'Select "talktranslate" to translate the text in place!'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(CupertinoIcons.sparkles,
                        color: AppColors.primary, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Quick Clipboard Translation',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Whenever you copy text in any application, opening Talk Translate or using the Live Keyboard Bar will automatically prompt you to translate it with 1 tap.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepTile(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
