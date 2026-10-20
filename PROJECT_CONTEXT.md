# PROJECT_CONTEXT.md
> **Single Source of Truth & Architectural Index**
> *Generated and maintained under the "Read-First, Update-Last" Protocol.*
> *Last Codebase Synchronization:* 2026-10-20T18:59:00+03:00

---

## 1. Project Overview & Runtime Environment
- **App Name:** `talk_translate` (Display Name: `talktranslate` / `Talk & Translate`)
- **Package / Bundle Identifier:** 
  - Android: `com.example.talk_translate`
  - iOS: `com.example.helloWorld` (Target: `Runner`)
- **Description:** Complete Real-time Online & Offline Translation Application for Web, iOS (including iPhone 16 / 17 Pro Max), and Android. Supports continuous voice dictation, camera OCR with bounding-box image translation overlays, on-device Neural AI translation, text transformation tones, offline model management (Google ML Kit + Sherpa ONNX Whisper), and ultra-realistic human TTS (Edge TTS + Flutter TTS).
- **Flutter Version:** Flutter `>=3.44.0` (Local Dev: `3.47.7` stable / Dart `3.13.5`)
- **Target Platforms:** iOS (`>=15.5`), Android (`compileSdk: 35`, `minSdk: 21`), Web (PWA responsive, constrained max width: 500dp).
- **Core Architecture Pattern:** Layered Feature-First Architecture (`Core`, `Data`, `Features`, `Shared`). State flows through Singletons and `ChangeNotifier` / `ValueNotifier` stores with localized widget `setState` for interactive views.

---

## 2. Packages & Dependencies Matrix (`pubspec.yaml`)

| Package | Version | Scope | Role in Project |
| :--- | :--- | :--- | :--- |
| `flutter` | SDK (`>=3.44.0`) | Main | Flutter Framework core UI & rendering engine |
| `fixnum` | `^1.1.1` | Main | 64-bit integer arithmetic support for protobuf/ML serialization |
| `cupertino_icons` | `^1.0.8` | Main | iOS-style SF symbols and Cupertino design icons |
| `http` | `^1.2.0` | Main | Cloud network requests, chunked model downloading from HuggingFace |
| `shared_preferences` | `^2.2.3` | Main | Persistent key-value storage for settings, downloaded pack IDs, voice preferences |
| `speech_to_text` | `^7.0.0` | Main | Platform speech recognition (Google Recognition Service on Android, SFSpeechRecognizer on iOS) |
| `flutter_tts` | `^4.2.0` | Main | Device-native Text-To-Speech audio synthesis fallback |
| `translator` | `^1.0.3` | Main | Google Cloud Web Translator API integration for multi-language text |
| `share_plus` | `^10.1.2` | Main | Native OS share sheet integration for sharing translated text and images |
| `google_mlkit_translation` | `any` | Main | On-device Google ML Kit neural language translation models |
| `google_mlkit_text_recognition` | `any` | Main | Camera OCR text recognition and bounding box extraction |
| `image_picker` | `any` | Main | Camera photo capture and photo library image selection |
| `sherpa_onnx` | `^1.13.8` | Main | Local on-device Whisper Tiny ONNX runtime speech-to-text |
| `record` | `^7.1.2` | Main | High-fidelity PCM/WAV microphone recording for offline speech recognition |
| `path_provider` | `^2.1.2` | Main | Cross-platform filesystem paths for downloaded ONNX models and cached audio |
| `flutter_edge_tts` | `^0.0.2` | Main | Microsoft Edge Neural Studio TTS synthesis (Ultra-realistic human voices) |
| `audioplayers` | `^6.8.1` | Main | Low-latency audio playback for synthesized MP3 byte streams |
| `flutter_test` | SDK | Dev | Unit and widget test framework |

---

## 3. Complete Directory & File Tree

```text
talk_translate/
├── .github/
│   └── workflows/
│       └── build_ios.yml                     # Cloud macOS runner for building unsigned iOS IPA
├── android/
│   ├── app/
│   │   ├── build.gradle.kts                 # Android app build configuration
│   │   └── src/main/AndroidManifest.xml     # Android permissions (Audio, Camera, Bluetooth, Speech)
│   └── build.gradle.kts                     # Root Android Gradle build script
├── ios/
│   ├── Flutter/
│   │   └── AppFrameworkInfo.plist           # MinimumOSVersion: 15.5
│   ├── Runner/
│   │   └── Info.plist                       # iOS Permissions (Microphone, Speech, Camera, Photos)
│   ├── Runner.xcodeproj/project.pbxproj     # Xcode project settings (IPHONEOS_DEPLOYMENT_TARGET: 15.5)
│   └── Podfile                              # CocoaPods configuration (platform :ios, '15.5')
├── lib/
│   ├── core/
│   │   ├── models/
│   │   │   ├── app_language.dart            # AppLanguage definition, supportedLanguages, ML Kit language mapper
│   │   │   └── translation_record.dart      # TranslationRecord entity for history & favorites
│   │   ├── theme/
│   │   │   └── app_colors.dart              # Unified app color palette
│   │   └── widgets/
│   │       ├── card_decoration.dart         # Standard rounded card box decoration
│   │       ├── language_selector_row.dart   # Interactive source/target language selector with swap button
│   │       └── shared_top_bar.dart          # Consistent top header with title, Pro pill, and Settings button
│   ├── data/
│   │   ├── app_database.dart                # Local storage, in-memory history, offline dictionary, SharedPreferences
│   │   ├── neural_tts_service.dart          # Microsoft Neural TTS voice synthesis and playback via AudioPlayer
│   │   ├── offline_voice_service.dart       # On-device Whisper Tiny ONNX STT model downloader and transcriber
│   │   └── translation_service.dart         # Master translation gateway (Cloud, ML Kit, Offline Dict, OCR, STT/TTS)
│   ├── features/
│   │   ├── camera_translate/
│   │   │   ├── camera_solutions_compare_view.dart # Multi-solution OCR lab (Smart Lens, Interactive Sheet, Reader List, Raw Baseline)
│   │   │   └── camera_translate_view.dart   # Shell wrapper forwarding to CameraSolutionsCompareView
│   │   ├── extras/
│   │   │   └── extras_view.dart             # Secondary hub: Learn, Keyboard Translator, Offline Mode, History
│   │   ├── history/
│   │   │   └── history_screen.dart          # Searchable list of past translations, favorites, clear history
│   │   ├── keyboard/
│   │   │   └── keyboard_translator_screen.dart # Interactive keyboard translation simulator & quick phrases
│   │   ├── learn/
│   │   │   └── learn_teacher_screen.dart    # Interactive language flashcard learning tool
│   │   ├── navigation/
│   │   │   └── main_navigation_screen.dart  # Root IndexedStack shell (Text, Talk, Camera, Extras)
│   │   ├── offline_mode/
│   │   │   └── offline_mode_screen.dart     # Language pack & Whisper Tiny ONNX model download manager
│   │   ├── talk_translate/
│   │   │   └── talk_translate_view.dart     # Continuous infinite speech STT, live translation, Split DUAL mode, auto-scroll
│   │   └── text_translate/
│   │       └── text_translate_view.dart     # Debounced text translation, tone presets (Formal/Casual/Business)
│   ├── shared/
│   │   ├── pro_sheet.dart                   # Premium subscription paywall / feature presentation modal
│   │   └── settings_modal.dart              # App settings: Male/Female AI voice, Force Offline toggle
│   └── main.dart                            # App entrypoint, database init, theme config, max-width wrapper
├── web/
│   ├── index.html                           # Web entrypoint
│   └── manifest.json                        # PWA web manifest
├── pubspec.yaml                             # Project configuration, dependencies, and Flutter assets
└── PROJECT_CONTEXT.md                       # This single-source-of-truth index
```

---

## 4. File-by-File Architectural Registry

### `lib/main.dart`
- **Role:** Application bootstrap entrypoint.
- **Classes / Widgets:**
  - `TalkTranslateApp` (`StatelessWidget`): Builds `MaterialApp`, configures `AppColors.primary`, sets scaffold background, enforces a responsive `ConstrainedBox(maxWidth: 500)` container for Web/Tablet layouts, and mounts `MainNavigationScreen`.
- **Key Methods:**
  - `void main()`: Initializes `WidgetsFlutterBinding`, triggers `AppDatabase.instance.init()`, and runs `TalkTranslateApp`.
- **Dependencies:** `lib/core/theme/app_colors.dart`, `lib/data/app_database.dart`, `lib/features/navigation/main_navigation_screen.dart`.
- **Used By:** Flutter runtime runner.

---

### `lib/core/models/app_language.dart`
- **Role:** Data structures and mapping utilities for supported languages.
- **Classes / Models:**
  - `AppLanguage`: Immutable model holding `name` (String), `flag` (String emoji), `code` (ISO 639-1 code), and `speechCode` (BCP-47 speech locale tag).
- **Constants & Functions:**
  - `const List<AppLanguage> supportedLanguages`: 11 pre-configured languages (English, Spanish, French, German, Italian, Portuguese, Japanese, Korean, Chinese Simplified, Chinese Traditional, Arabic).
  - `TranslateLanguage getMlKitLanguage(String code)`: Maps two-letter language code to `google_mlkit_translation`'s `TranslateLanguage` enum.
- **Dependencies:** `package:google_mlkit_translation`.
- **Used By:** `language_selector_row.dart`, `translation_service.dart`, `talk_translate_view.dart`, `text_translate_view.dart`, `camera_translate_view.dart`.

---

### `lib/core/models/translation_record.dart`
- **Role:** Data model representing historical and favorited translation entries.
- **Classes / Models:**
  - `TranslationRecord`: Stores `id`, `sourceText`, `translatedText`, `fromCode`, `toCode`, `mode` (`'text'`, `'talk'`, `'camera'`), `createdAt` (`DateTime`), and `isFavorite` (`bool`).
- **Dependencies:** None.
- **Used By:** `app_database.dart`, `translation_service.dart`, `history_screen.dart`.

---

### `lib/core/theme/app_colors.dart`
- **Role:** Centralized styling and brand color definitions.
- **Classes:**
  - `AppColors`: Static constants including `background` (`#F7F9FC`), `primary` (`#5B84A6`), `primaryDark` (`#4C7598`), `textPrimary` (`#1E293B`), `textSecondary` (`#6B7A90`), `textHint` (`#BAC5D5`), `cardBg` (`Colors.white`), `readyBg` (`#E3F7EB`), and `readyGreen` (`#22C55E`).
- **Dependencies:** `package:flutter/material.dart`.
- **Used By:** All UI screens and core widgets across `lib/`.

---

### `lib/core/widgets/card_decoration.dart`
- **Role:** Uniform visual presentation for card surfaces throughout the application.
- **Functions:**
  - `BoxDecoration cardDecoration()`: Returns standard `BoxDecoration` with `AppColors.cardBg`, `BorderRadius.circular(20)`, and soft drop shadow.
- **Dependencies:** `lib/core/theme/app_colors.dart`.
- **Used By:** `language_selector_row.dart`, `talk_translate_view.dart`, `text_translate_view.dart`, `extras_view.dart`, `learn_teacher_screen.dart`.

---

### `lib/core/widgets/language_selector_row.dart`
- **Role:** Reusable language selection toolbar with animated swap functionality.
- **Classes / Widgets:**
  - `LanguageSelectorRow` (`StatelessWidget`): Renders side-by-side dropdown buttons displaying language flags, localized names, and a circular swap action button.
- **Key Methods:**
  - `Widget _buildDropdown(AppLanguage current, ValueChanged<AppLanguage> onChanged)`: Dropdown container bound to `supportedLanguages`.
- **Dependencies:** `lib/core/models/app_language.dart`, `lib/core/theme/app_colors.dart`, `lib/core/widgets/card_decoration.dart`.
- **Used By:** `talk_translate_view.dart`, `text_translate_view.dart`, `camera_translate_view.dart`.

---

### `lib/core/widgets/shared_top_bar.dart`
- **Role:** Top navigation app bar present on all primary views.
- **Classes / Widgets:**
  - `SharedTopBar` (`StatelessWidget`): Displays large bold screen title, subtitle status indicator, Pro membership pill button, and Settings gear icon.
- **Dependencies:** `lib/core/theme/app_colors.dart`, `lib/shared/pro_sheet.dart`.
- **Used By:** `talk_translate_view.dart`, `text_translate_view.dart`, `camera_translate_view.dart`, `extras_view.dart`.

---

### `lib/data/app_database.dart`
- **Role:** Application data store, local cache, settings persistence, and built-in offline dictionary.
- **Classes:**
  - `AppDatabase` (`ChangeNotifier`, Singleton):
    - **Properties:** `history` (`List<TranslationRecord>`), `downloadedPacks` (`Set<String>`), `offlineCache` (`Map<String, String>`), `forceOfflineMode` (`bool`), `isProUser` (`bool`), `ttsVoiceGender` (`String`, `'male'` / `'female'`), `enableMultilingualSpeech` (`bool`).
    - `_builtInDictionary`: Rich multi-language dictionary for 100+ common greetings, emergency phrases, travel inquiries, and numbers.
- **Key Methods:**
  - `Future<void> init()`: Loads saved language packs, offline toggles, and voice settings from `SharedPreferences`.
  - `void saveRecord(TranslationRecord record)`: Inserts record to top of history, caches in `offlineCache`, and triggers `notifyListeners()`.
  - `void toggleFavorite(String id)`: Inverts favorite flag on matching history record.
  - `void clearHistory()`: Wipes in-memory history list.
  - `Future<void> addDownloadedPack(String code)` / `removeDownloadedPack(String code)`: Updates and persists downloaded ML pack IDs.
  - `Future<void> setTtsVoiceGender(String gender)`: Updates and persists voice preference (`'male'` / `'female'`).
  - `String? lookupOffline(String text, String fromCode, String toCode)`: 4-tier offline phrase matching (exact match, reverse lookup, composite phrase extraction, word-by-word fallback).
- **Dependencies:** `package:shared_preferences`, `lib/core/models/translation_record.dart`.
- **Used By:** `main.dart`, `translation_service.dart`, `settings_modal.dart`, `offline_mode_screen.dart`, `history_screen.dart`.

---

### `lib/data/neural_tts_service.dart`
- **Role:** Studio-quality neural voice synthesis service.
- **Classes:**
  - `NeuralTtsService` (Singleton): Wraps `FlutterEdgeTts` and `AudioPlayer` to deliver Microsoft Studio Neural voice audio (`ar-SA-HamedNeural`, `ar-SA-ZariyahNeural`, `en-US-GuyNeural`, `en-US-JennyNeural`, etc.).
- **Key Methods:**
  - `String getVoiceName(String langCode, bool isMale)`: Resolves appropriate neural voice identifier matching language and gender.
  - `Future<bool> speak({required String text, required String langCode})`: Synthesizes MP3 byte stream and streams it through `AudioPlayer`.
- **Dependencies:** `package:flutter_edge_tts`, `package:audioplayers`, `lib/data/app_database.dart`.
- **Used By:** `translation_service.dart`.

---

### `lib/data/offline_voice_service.dart`
- **Role:** Pure on-device speech-to-text engine using Sherpa ONNX runtime and Whisper Tiny models.
- **Classes:**
  - `OfflineVoiceService` (Singleton):
    - Manages downloading, verification, initialization, and execution of quantized ONNX models (`tiny-encoder.int8.onnx`, `tiny-decoder.int8.onnx`, `tiny-tokens.txt`).
- **Key Methods:**
  - `void initBindings()`: Initializes Sherpa-onnx native C++ bindings.
  - `Future<bool> isVoiceModelReady()`: Validates presence and non-zero byte size of all ONNX model files.
  - `Future<bool> downloadVoiceModel({Function(double, String)? onProgress})`: Streams model files from HuggingFace with progress reporting.
  - `Future<bool> deleteVoiceModel()`: Removes downloaded model directory to free device storage.
  - `Future<bool> startRecording()`: Initiates 16kHz Mono PCM WAV recording via `package:record`.
  - `Future<String?> stopRecordingAndTranscribe({required String langCode})`: Stops recording, reads WAV samples, runs ONNX offline recognition, and returns transcription.
- **Dependencies:** `package:sherpa_onnx`, `package:record`, `package:path_provider`, `package:http`.
- **Used By:** `talk_translate_view.dart`, `offline_mode_screen.dart`.

---

### `lib/data/translation_service.dart`
- **Role:** Unified central facade orchestrating all translation, OCR, STT, and TTS operations across the entire app.
- **Classes:**
  - `TranslationService` (Singleton):
    - Coordinates Cloud Translation, Google ML Kit on-device translation, `AppDatabase.lookupOffline`, Camera OCR text recognition, Speech-To-Text sessions, and TTS audio synthesis.
- **Key Methods:**
  - `Future<Map<String, dynamic>?> captureAndRecognizeBlocks({bool fromCamera = true})`: Captures photo and extracts text blocks with bounding boxes via `TextRecognizer`.
  - `Future<bool> hasInternetConnection()`: Fast socket DNS probe to `google.com` (1200ms timeout).
  - `Future<String> translate({required String text, required String fromCode, required String toCode, String mode})`: Hybrid routing: attempts Cloud translation, falls back to Google ML Kit on-device model, then built-in offline dictionary.
  - `Future<void> speak(String text, String speechCode)`: Prioritizes `NeuralTtsService` studio voices; gracefully falls back to native `FlutterTts`.
  - `Future<bool> initSpeech({Function(dynamic)? onError, Function(String)? onStatus})`: Initializes native platform SpeechToText.
  - `Future<bool> isAiModelDownloaded(String langCode)` / `downloadAiModel(String langCode)` / `deleteAiModel(String langCode)`: Manages on-device ML Kit language model packs.
- **Dependencies:** `package:google_mlkit_translation`, `package:google_mlkit_text_recognition`, `package:translator`, `package:flutter_tts`, `package:speech_to_text`, `package:image_picker`, `lib/data/neural_tts_service.dart`, `lib/data/app_database.dart`, `lib/core/models/app_language.dart`.
- **Used By:** All primary features (`talk_translate_view`, `text_translate_view`, `camera_translate_view`, `keyboard_translator_screen`, `history_screen`, `offline_mode_screen`).

---

### `lib/features/navigation/main_navigation_screen.dart`
- **Role:** Root application scaffold and bottom navigation shell.
- **Classes / Widgets:**
  - `MainNavigationScreen` (`StatefulWidget`): Contains an `IndexedStack` preserving state across 4 main views: Text, Talk, Camera, and Extras.
  - `static final ValueNotifier<int> tabNotifier`: Enables programmatic tab switching from anywhere in the app via `MainNavigationScreen.switchTo(index)`.
- **Dependencies:** `lib/core/theme/app_colors.dart`, `features/text_translate`, `features/talk_translate`, `features/camera_translate`, `features/extras`.
- **Used By:** `main.dart`.

---

### `lib/features/talk_translate/talk_translate_view.dart`
- **Role:** Real-time voice translation interface with continuous non-stop speech recognition, live translation streaming, auto-scrolling, and Split DUAL face-to-face mode.
- **Classes / Widgets:**
  - `TalkTranslateView` (`StatefulWidget`):
    - Manages live speech input, Wi-Fi vs Local AI auto-detection, continuous restart loop for infinite dictation, and smooth auto-scrolling containers.
- **Key State Variables & Methods:**
  - `_spokenScrollController`, `_translatedScrollController`, `_speakerTwoSpokenScrollController`, `_speakerTwoTranslatedScrollController`: Controls auto-scrolling of lengthy dictations.
  - `void _scrollToBottom(ScrollController controller)`: Smoothly animates text containers to newest recognized words.
  - `Future<bool> _startContinuousOnlineListen({required bool speakerTwo})`: Initiates platform STT session with custom restart timer and word segment accumulation (`_commitCurrentSessionWords`).
  - `void _scheduleContinuousRestart(...)`: Forcefully restarts speech recognition on silence or buffer end to allow hours of continuous speaking without manual restarts.
  - `void _liveTranslate(...)`: 180ms debounced live streaming translation during speech.
  - `Widget _buildSplitConversationScreen()`: 180° inverted dual-screen UI for two people seated across a table.
- **Dependencies:** `package:speech_to_text`, `lib/data/translation_service.dart`, `lib/data/offline_voice_service.dart`, `lib/data/app_database.dart`, `lib/core/widgets/shared_top_bar.dart`, `lib/core/widgets/language_selector_row.dart`.
- **Used By:** `main_navigation_screen.dart`.

---

### `lib/features/text_translate/text_translate_view.dart`
- **Role:** Instant text translation view with tone selection (Natural, Formal, Casual, Business) and alternative formulations.
- **Classes / Widgets:**
  - `TextTranslateView` (`StatefulWidget`):
    - 600ms debounced text input translation, smart tone generator, favorite toggling, clipboard copy, and voice playback.
- **Dependencies:** `lib/data/translation_service.dart`, `lib/data/app_database.dart`, `lib/core/widgets/shared_top_bar.dart`, `lib/core/widgets/language_selector_row.dart`.
- **Used By:** `main_navigation_screen.dart`.

---

### `lib/features/camera_translate/camera_solutions_compare_view.dart`
- **Role:** Interactive multi-solution OCR comparison lab implementing 3 production-grade solutions with live toggle buttons to eliminate viewfinder crowding, filter on-screen keyboard artifacts, and cluster text blocks.
- **Classes / Enums / Models:**
  - `CameraSolutionMode` (`enum`): `smartLens` (Solution 1: paragraph merging & noise filtering), `interactiveSheet` (Solution 2: glowing subtle focus outline with bottom sheet), `readerList` (Solution 3: structured document card list with TTS & clipboard export), `rawBaseline` (unfiltered baseline for side-by-side comparison).
  - `OcrTranslatedItem`: Holds `id`, `originalText`, `translatedText`, `boundingBox`, and `isNoise` flag.
  - `CameraSolutionsCompareView` (`StatefulWidget`): Complete testbed containing live mode switcher, parallel translation batching, `InteractiveViewer` zoom, and high-res image sharing.
- **Key Methods & Logic:**
  - `bool _isNoiseOrKeyboardArtifact(String text)`: Algorithmic noise filter discarding single isolated characters (except valid words), pure numbers/dates, and keyboard keys (`GIF`, `ESC`, `TAB`, `DF`, `HJ K`, etc.).
  - `Future<void> _pickAndProcessImage(bool useCamera)`: Extracts raw lines alongside paragraph-merged smart blocks, translating in parallel batches of 10 items via `Future.wait`.
  - `void _showDetailBottomSheet(BuildContext context, OcrTranslatedItem item)`: Elegant modal presenting original & translated text, speech synthesis, and clipboard copy.
  - `Widget _buildSolutionsControlBar()`: Segmented button row providing instantaneous switching between the 3 solutions on the exact same photo.
- **Dependencies:** `package:google_mlkit_text_recognition`, `package:image_picker`, `package:share_plus`, `package:path_provider`, `lib/data/translation_service.dart`, `lib/core/widgets/shared_top_bar.dart`, `lib/core/widgets/language_selector_row.dart`, `lib/core/theme/app_colors.dart`.
- **Used By:** `camera_translate_view.dart`.

---

### `lib/features/camera_translate/camera_translate_view.dart`
- **Role:** Top-level feature wrapper mounting `CameraSolutionsCompareView` into `MainNavigationScreen`.
- **Classes / Widgets:**
  - `CameraTranslateView` (`StatelessWidget`): Shell widget that instantiates `CameraSolutionsCompareView`.
- **Dependencies:** `lib/features/camera_translate/camera_solutions_compare_view.dart`.
- **Used By:** `main_navigation_screen.dart`.

---

### `lib/features/extras/extras_view.dart`
- **Role:** Navigation hub providing access to auxiliary features: Learn, Keyboard Translator, Offline Mode, and History.
- **Classes / Widgets:**
  - `ExtrasView` (`StatelessWidget`): Menu card list styled with iOS Cupertino navigation transitions.
- **Dependencies:** `features/history`, `features/keyboard`, `features/learn`, `features/offline_mode`, `lib/core/widgets/shared_top_bar.dart`.
- **Used By:** `main_navigation_screen.dart`.

---

### `lib/features/history/history_screen.dart`
- **Role:** History and favorites manager for past translations.
- **Classes / Widgets:**
  - `HistoryScreen` (`StatefulWidget`): Filterable list (All vs Favorites), item deletion, speech playback, and clipboard copying.
- **Dependencies:** `lib/data/app_database.dart`, `lib/data/translation_service.dart`.
- **Used By:** `extras_view.dart`.

---

### `lib/features/keyboard/keyboard_translator_screen.dart`
- **Role:** Interactive simulation of in-app translation keyboard with chat preview and quick phrases.
- **Classes / Widgets:**
  - `KeyboardTranslatorScreen` (`StatefulWidget`): Dual-tab interface demonstrating in-keyboard translation and quick phrases.
- **Dependencies:** `lib/data/translation_service.dart`, `lib/core/models/app_language.dart`.
- **Used By:** `extras_view.dart`.

---

### `lib/features/learn/learn_teacher_screen.dart`
- **Role:** Interactive flashcard study tool for language learners.
- **Classes / Widgets:**
  - `LearnTeacherScreen` (`StatefulWidget`): Tap-to-flip flashcard system with progress indexing.
- **Dependencies:** `lib/core/widgets/card_decoration.dart`, `lib/core/theme/app_colors.dart`.
- **Used By:** `extras_view.dart`.

---

### `lib/features/offline_mode/offline_mode_screen.dart`
- **Role:** Offline assets manager for on-device Neural AI models.
- **Classes / Widgets:**
  - `OfflineModeScreen` (`StatefulWidget`): Manages downloading/deleting Google ML Kit language packs and Whisper Tiny ONNX offline speech model.
- **Dependencies:** `lib/data/translation_service.dart`, `lib/data/offline_voice_service.dart`, `lib/data/app_database.dart`.
- **Used By:** `extras_view.dart`, `talk_translate_view.dart`.

---

### `lib/shared/pro_sheet.dart`
- **Role:** Modal bottom sheet presenting Talk Translate PRO tier capabilities.
- **Functions:**
  - `void showProSheet(BuildContext context)`: Draggable bottom sheet detailing Offline AI, Keyboard Translation, and Unlimited Camera OCR features.
- **Dependencies:** `lib/core/theme/app_colors.dart`.
- **Used By:** `shared_top_bar.dart`.

---

### `lib/shared/settings_modal.dart`
- **Role:** Application settings dialog.
- **Functions:**
  - `void showSettingsModal(BuildContext context)`: Bottom sheet allowing users to toggle Male/Female AI voice, Force Offline mode, and view engine build information.
- **Dependencies:** `lib/data/app_database.dart`, `lib/core/theme/app_colors.dart`.
- **Used By:** `shared_top_bar.dart`.

---

## 5. State Management, Routing & Data Flow
- **Routing:** No third-party router dependency (`go_router` / `auto_route`). Navigation uses standard Flutter declarative/imperative routing:
  - Root tab navigation uses `IndexedStack` driven by `MainNavigationScreen.tabNotifier` (`ValueNotifier<int>`).
  - Secondary screens (History, Learn, Offline Mode, Keyboard) are pushed via `Navigator.push(context, CupertinoPageRoute(...))` for native iOS slide transitions.
  - Modals (Settings, PRO Sheet, Quick Text Input) are opened via `showModalBottomSheet`.
- **State Management:**
  - Global configuration & history: `AppDatabase` singleton extending `ChangeNotifier`. Views react via `notifyListeners()`.
  - Local screen state: `StatefulWidget` with localized `setState` for high-frequency events (audio level meters, debounce timers, text input, camera processing).
- **Data Flow Pipeline:**
  1. User speaks, enters text, or captures an image.
  2. Input flows into `TranslationService`.
  3. `TranslationService` probes internet connectivity:
     - **Online:** Routes to Google Cloud Translator API / Microsoft Edge Neural TTS.
     - **Offline:** Routes to Google ML Kit On-Device Neural Model ➔ Built-in `AppDatabase` dictionary ➔ Sherpa ONNX Whisper model.
  4. Output is committed to `AppDatabase.saveRecord()`, triggering in-memory caching and history storage.

---

## 6. Platform-Specific Configurations

### Android (`android/app/src/main/AndroidManifest.xml`)
- **Permissions:**
  - `android.permission.INTERNET`: Cloud translation and model downloading.
  - `android.permission.RECORD_AUDIO`: Voice input.
  - `android.permission.CAMERA`: Optical OCR translation.
  - `android.permission.BLUETOOTH` / `BLUETOOTH_ADMIN` / `BLUETOOTH_CONNECT`: Bluetooth headset voice input.
- **Service Queries:** `android.speech.RecognitionService` explicitly registered in `<queries>` for Google Speech Services compatibility on Android 11+ (API 30+).

### iOS (`ios/Runner/Info.plist` & `ios/Podfile`)
- **Deployment Target:** `iOS 15.5` across `Podfile`, `project.pbxproj`, and `AppFrameworkInfo.plist` (Mandated by `google_mlkit_commons`).
- **Privacy Permissions (`Info.plist`):**
  - `NSMicrophoneUsageDescription`: Speech recognition and live voice translation.
  - `NSSpeechRecognitionUsageDescription`: Speech transcription.
  - `NSCameraUsageDescription`: Real-time camera text recognition.
  - `NSPhotoLibraryUsageDescription`: Photo gallery image translation.
  - `NSPhotoLibraryAddUsageDescription`: Saving translated images to camera roll.

### CI/CD Cloud Pipeline (`.github/workflows/build_ios.yml`)
- Automated macOS runner workflow building unsigned release `.ipa` packages via GitHub Actions for sideloading on physical iOS devices (iPhone 16 / 17 Pro Max via Sideloadly / Scarlet).

---

## 7. Latest Sync Changelog
1. **2026-10-20:** Created `camera_solutions_compare_view.dart` implementing all 3 OCR solutions (Smart Lens with paragraph merging & keyboard noise filtering, Interactive Focus & Bottom Sheet, and Document Reader List Mode) with independent toggle buttons for live real-device testing and comparison against raw baseline.
2. **2026-10-20:** Optimized camera OCR translation loop to execute in asynchronous parallel batches (`Future.wait`) of 10 lines, preventing UI thread stalls and network timeouts during large document scans.
3. **2026-10-20:** Upgraded `camera_translate_view.dart` to a professional Google Lens-style OCR engine with line-level extraction (`TextLine`), aspect-ratio bounding box alignment via `ui.decodeImageFromList`, `InteractiveViewer` zoom, and tap-to-speak.
4. **2026-10-20:** Created `PROJECT_CONTEXT.md` as the unified codebase source of truth and architectural index.
5. **2026-10-20:** Implemented smooth manual and live auto-scrolling (`ScrollController` + `animateTo: maxScrollExtent`) across all speech and translation cards in `talk_translate_view.dart`.

