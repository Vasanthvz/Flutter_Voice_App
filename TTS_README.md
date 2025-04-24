# Text-to-Voice Feature

This application now includes simplified text-to-voice functionality using Google TTS.

## Features

1. **Text Translation with Speech Output**
   - Translate text between multiple languages
   - Listen to the translated text using Text-to-Speech
   
2. **Supported Languages**
   - English
   - Hindi 
   - Tamil
   - Telugu
   - Malayalam
   - Bengali
   - Marathi
   - Gujarati
   - Kannada
   - Punjabi
   - Urdu

## How to Use

1. **Start the Server**
   ```
   cd server
   python main.py
   ```
   This will start the server on port 8001.

2. **Launch the App**
   - Select "Text to Voice" from the main menu
   - Enter text in the source language
   - Select source and target languages
   - Click "Translate"
   - Once translation is complete, click the speaker icon to hear the translated text

## Implementation Details

- The server uses Google's gTTS (Google Text-to-Speech) service for generating speech
- The Flutter application communicates with the server via HTTP requests
- Audio is played directly within the app using the audioplayers package

## Troubleshooting

If speech is not working:
1. Make sure the server is running
2. Check that your device has an internet connection (required for Google TTS)
3. Ensure the device has audio output capability 