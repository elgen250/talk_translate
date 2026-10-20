import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/models/app_language.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/card_decoration.dart';
import '../../data/app_database.dart';
import '../../data/translation_service.dart';
import '../../data/offline_voice_service.dart';

class OfflineModeScreen extends StatefulWidget {
  const OfflineModeScreen({super.key});

  @override
  State<OfflineModeScreen> createState() => _OfflineModeScreenState();
}

class _OfflineModeScreenState extends State<OfflineModeScreen> {
  String? _downloadingCode;
  bool _isVoiceModelReady = false;
  bool _isVoiceDownloading = false;
  double _voiceProgress = 0.0;
  String _voiceStatus = '';

  @override
  void initState() {
    super.initState();
    _checkVoiceModel();
  }

  Future<void> _checkVoiceModel() async {
    final ready = await OfflineVoiceService.instance.isVoiceModelReady();
    if (mounted) setState(() => _isVoiceModelReady = ready);
  }

  Future<void> _handleVoiceDownloadTap() async {
    if (_isVoiceModelReady) {
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Offline Voice Recognition AI'),
          content: const Text(
            'Whisper On-Device Speech Model (~39 MB) is ready for 100% offline voice translation.\n\nDelete model to free up storage?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (shouldDelete == true) {
        await OfflineVoiceService.instance.deleteVoiceModel();
        await _checkVoiceModel();
      }
    } else {
      setState(() {
        _isVoiceDownloading = true;
        _voiceProgress = 0.0;
        _voiceStatus = 'Connecting to model repository...';
      });

      final success = await OfflineVoiceService.instance.downloadVoiceModel(
        onProgress: (p, status) {
          if (mounted) {
            setState(() {
              _voiceProgress = p;
              _voiceStatus = status;
            });
          }
        },
      );

      if (mounted) {
        setState(() => _isVoiceDownloading = false);
        await _checkVoiceModel();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? '✅ Offline Voice Recognition AI downloaded & ready!'
                : '❌ Download failed. Please check internet connection.'),
            backgroundColor: success ? AppColors.readyGreen : Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handlePackTap(AppLanguage lang) async {
    final isReady = AppDatabase.instance.downloadedPacks.contains(lang.code);

    if (isReady) {
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('${lang.flag} ${lang.name} Pack'),
          content: Text(
            'This language package is currently ready for 100% offline AI translation.\n\nDo you want to delete it to free up storage?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (shouldDelete == true) {
        await TranslationService.instance.deleteAiModel(lang.code);
        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Removed ${lang.name} offline package.')),
          );
        }
      }
    } else {
      setState(() => _downloadingCode = lang.code);
      final success =
          await TranslationService.instance.downloadAiModel(lang.code);
      if (!mounted) return;
      setState(() => _downloadingCode = null);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${lang.flag} ${lang.name} AI model downloaded & ready!'),
            backgroundColor: AppColors.readyGreen,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final readyCount = AppDatabase.instance.downloadedPacks.length;
    final totalCount = supportedLanguages.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(CupertinoIcons.xmark, color: AppColors.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Text(
              'Offline AI Models',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Download neural AI language packages to translate instantly without any internet connection.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8E9BAE),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Downloaded: $readyCount / $totalCount packs ready',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            // On-Device Voice AI Engine Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isVoiceModelReady
                        ? [const Color(0xFF10B981).withValues(alpha: 0.12), Colors.white]
                        : [AppColors.primary.withValues(alpha: 0.08), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isVoiceModelReady
                        ? const Color(0xFF10B981).withValues(alpha: 0.4)
                        : AppColors.primary.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _isVoiceModelReady
                                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                      : AppColors.primary.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  CupertinoIcons.mic_fill,
                                  color: _isVoiceModelReady
                                      ? const Color(0xFF10B981)
                                      : AppColors.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Voice AI Engine (Whisper)',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      _isVoiceModelReady
                                          ? '100% Offline Voice-to-Text Ready'
                                          : 'Offline microphone transcription (~39 MB)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _isVoiceModelReady
                                            ? const Color(0xFF10B981)
                                            : AppColors.textSecondary,
                                        fontWeight: _isVoiceModelReady
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!_isVoiceDownloading)
                          InkWell(
                            onTap: _handleVoiceDownloadTap,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: _isVoiceModelReady
                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                    : AppColors.primary,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                _isVoiceModelReady ? 'Ready ✓' : 'Download',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _isVoiceModelReady
                                      ? const Color(0xFF10B981)
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (_isVoiceDownloading) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _voiceProgress,
                          backgroundColor: Colors.grey.shade200,
                          color: AppColors.primary,
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _voiceStatus,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${(_voiceProgress * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: supportedLanguages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final lang = supportedLanguages[index];
                  final isReady =
                      AppDatabase.instance.downloadedPacks.contains(lang.code);
                  final isDownloading = _downloadingCode == lang.code;

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: cardDecoration(),
                    child: Row(
                      children: [
                        Text(lang.flag, style: const TextStyle(fontSize: 26)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            lang.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _handlePackTap(lang),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isReady
                                  ? AppColors.readyBg
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: isDownloading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Row(
                                    children: [
                                      Icon(
                                        isReady
                                            ? Icons.check_circle
                                            : CupertinoIcons.cloud_download,
                                        size: 15,
                                        color: isReady
                                            ? AppColors.readyGreen
                                            : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        isReady ? 'Ready' : 'Download',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isReady
                                              ? AppColors.readyGreen
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

