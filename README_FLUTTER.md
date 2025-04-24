# Whisper Flutter App

A Flutter application that provides real-time speech-to-text transcription and translation to Indian languages using OpenAI's Whisper model and AI4Bharat's translation model.

## Features

- Real-time speech-to-text transcription
- Multi-language translation support
- Offline mode support
- Modern Material Design UI
- Cross-platform compatibility

## Supported Languages

### Transcription
- English (en)
- Hindi (hi)
- Tamil (ta)
- Malayalam (ml)
- Bengali (bn)
- Marathi (mr)
- Urdu (ur)
- Nepali (ne)
- Sinhala (si)

### Translation
- English ↔ All supported Indian languages
- Hindi ↔ All supported Indian languages
- Tamil ↔ All supported Indian languages
- Malayalam ↔ All supported Indian languages
- Bengali ↔ All supported Indian languages
- Marathi ↔ All supported Indian languages
- Urdu ↔ All supported Indian languages
- Nepali ↔ All supported Indian languages
- Sinhala ↔ All supported Indian languages

## Project Structure

```
lib/
├── main.dart                 # Main application entry point
├── models/
│   └── language.dart         # Language model and enums
├── screens/
│   ├── home_screen.dart      # Main home screen
│   ├── voice_to_text_screen.dart  # Speech-to-text screen
│   └── text_translation_screen.dart # Translation screen
└── services/
    ├── api_service.dart      # API communication service
    ├── speech_recognition_service.dart  # Speech recognition service
    └── translation_service.dart  # Translation service
```

## Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.2
  record: ^4.4.4
  path_provider: ^2.1.2
  permission_handler: ^11.2.0
  http: ^1.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0
```

## Setup Instructions

1. Clone the repository
2. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```
3. Ensure the Python server is running on `localhost:8001`
4. Run the app:
   ```bash
   flutter run
   ```

## Environment Requirements

- Flutter SDK: >=3.2.0 <4.0.0
- Dart SDK: >=3.2.0 <4.0.0
- Python server running on port 8001
- Microphone permissions for speech recognition

## API Endpoints

The app communicates with the following server endpoints:

- `/transcribe/realtime/`: Real-time speech-to-text transcription
- `/translate/`: Text translation between languages
- `/translate_batch/`: Batch translation of multiple texts

## Offline Mode

The app supports offline mode for both transcription and translation. In offline mode:
- Transcription uses the locally loaded Whisper model
- Translation uses the locally loaded AI4Bharat model
- No internet connection is required

## Error Handling

The app includes comprehensive error handling for:
- Network connectivity issues
- Server errors
- Permission denials
- Invalid language selections
- Audio recording failures

## Performance Optimization

- Translation results are cached for faster repeated translations
- Audio processing is optimized for real-time transcription
- UI updates are debounced to prevent excessive rebuilds

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details. 