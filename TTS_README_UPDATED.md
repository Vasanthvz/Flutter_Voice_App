# Updated TTS Functionality

This project has been updated to use a simplified TTS approach with the following changes:

## Changes Made

1. **Simplified TTS Server**: The application now uses a simplified TTS Flask server (`tts_flask_server.py`) running on port 8002, which uses Google's gTTS library to generate speech. This eliminates the need for complex model downloads and dependencies.

2. **Updated Client Code**: 
   - `lib/services/indic_tts_service.dart` has been updated to communicate with the simplified server
   - `lib/providers/app_state.dart` has been modified to handle playback using audioplayers
   - `lib/screens/home_screen.dart` has been updated to show server status instead of downloaded models

## How to Use

1. **Start the TTS Server**:
   ```
   cd server
   python tts_flask_server.py
   ```
   The server will run on port 8002 and provide TTS capabilities for all supported languages.

2. **Using in the App**:
   - Select a language from the dropdown
   - Enter text to be spoken
   - Press "Speak" to convert the text to speech

3. **Supported Languages**:
   - English (en)
   - Hindi (hi)
   - Tamil (ta)
   - Telugu (te)
   - Malayalam (ml)
   - Bengali (bn)
   - Marathi (mr)
   - Gujarati (gu)
   - Kannada (kn)
   - Punjabi (pa)
   - Urdu (ur)

## Troubleshooting

If the TTS functionality is not working:

1. Make sure the TTS server is running (you should see "Starting TTS server on port 8002" in the terminal)
2. Check if you can access the server by opening `http://localhost:8002/ping` in your browser
3. If the server is running but the app shows "TTS Server is not available", try restarting the app

## Technical Details

- The simplified implementation uses Google's gTTS (Google Text-to-Speech) service
- Audio files are saved to the device's temporary directory
- The app uses the audioplayers package to play the generated speech
- No model downloads are required as gTTS handles the speech generation 