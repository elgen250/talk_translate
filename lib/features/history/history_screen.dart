import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/card_decoration.dart';
import '../../data/app_database.dart';
import '../../data/translation_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _onlyFavorites = false;

  @override
  Widget build(BuildContext context) {
    final allRecords = AppDatabase.instance.history;
    final records = _onlyFavorites
        ? allRecords.where((r) => r.isFavorite).toList()
        : allRecords;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('History',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (allRecords.isNotEmpty)
            IconButton(
              icon: const Icon(CupertinoIcons.trash, color: Colors.redAccent),
              onPressed: () {
                AppDatabase.instance.clearHistory();
                setState(() {});
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All Translations'),
                  selected: !_onlyFavorites,
                  onSelected: (_) => setState(() => _onlyFavorites = false),
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text('Favorites ❤️'),
                  selected: _onlyFavorites,
                  onSelected: (_) => setState(() => _onlyFavorites = true),
                ),
              ],
            ),
          ),
          Expanded(
            child: records.isEmpty
                ? const Center(
                    child: Text(
                      'No saved translations yet.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: records.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = records[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: cardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${item.fromCode.toUpperCase()} → ${item.toCode.toUpperCase()} (${item.mode})',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    AppDatabase.instance
                                        .toggleFavorite(item.id);
                                    setState(() {});
                                  },
                                  child: Icon(
                                    item.isFavorite
                                        ? CupertinoIcons.heart_fill
                                        : CupertinoIcons.heart,
                                    size: 18,
                                    color: item.isFavorite
                                        ? Colors.redAccent
                                        : AppColors.textHint,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.sourceText,
                              style: const TextStyle(
                                  fontSize: 15, color: AppColors.textSecondary),
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.translatedText,
                                    style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(CupertinoIcons.speaker_2,
                                      size: 18, color: AppColors.primary),
                                  onPressed: () => TranslationService.instance
                                      .speak(item.translatedText, item.toCode),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

