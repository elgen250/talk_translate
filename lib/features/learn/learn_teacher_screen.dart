import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/card_decoration.dart';

class LearnTeacherScreen extends StatefulWidget {
  const LearnTeacherScreen({super.key});

  @override
  State<LearnTeacherScreen> createState() => _LearnTeacherScreenState();
}

class _LearnTeacherScreenState extends State<LearnTeacherScreen> {
  bool _showAnswer = false;
  int _index = 0;

  final List<Map<String, String>> _cards = [
    {
      'q': 'Bonjour, comment allez-vous ?',
      'a': 'Hello, how are you?',
      'lang': 'French'
    },
    {
      'q': 'Où est l\'aéroport ?',
      'a': 'Where is the airport?',
      'lang': 'French'
    },
    {'q': 'Merci beaucoup', 'a': 'Thank you very much', 'lang': 'French'},
    {'q': 'Café au lait', 'a': 'Coffee with milk', 'lang': 'French'},
  ];

  @override
  Widget build(BuildContext context) {
    final card = _cards[_index % _cards.length];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Learn - Personal Teacher',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => setState(() => _showAnswer = !_showAnswer),
              child: Container(
                width: double.infinity,
                height: 260,
                padding: const EdgeInsets.all(24),
                decoration: cardDecoration(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _showAnswer
                          ? 'ENGLISH MEANING'
                          : '${card['lang']!.toUpperCase()} PHRASE',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _showAnswer ? card['a']! : card['q']!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Tap card to flip',
                      style: TextStyle(fontSize: 12, color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _index++;
                  _showAnswer = false;
                });
              },
              icon: const Icon(CupertinoIcons.arrow_right),
              label: const Text('Next Flashcard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

