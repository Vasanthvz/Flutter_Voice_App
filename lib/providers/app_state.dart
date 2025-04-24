import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../services/tts_service.dart';

class AppState extends ChangeNotifier {
  late final TTSService _ttsService;
  final String _baseUrl = 'http://localhost:8002';
  
  // Map of language codes to display names
  final Map<String, String> languageNames = {
    'en': 'English',
    'hi': 'Hindi',
    'ta': 'Tamil',
    'te': 'Telugu',
    'ml': 'Malayalam',
    'bn': 'Bengali',
    'mr': 'Marathi',
    'gu': 'Gujarati',
    'kn': 'Kannada',
    'pa': 'Punjabi',
    'ur': 'Urdu',
  };
  
  // List of supported languages (language codes)
  List<String> supportedLanguages = [
    'en', 'hi', 'ta', 'te', 'ml', 'bn', 'mr', 'gu', 'kn', 'pa', 'ur'
  ];
  
  // Track server status
  bool _serverAvailable = false;
  bool get serverAvailable => _serverAvailable;
  bool get isTtsServerAvailable => _serverAvailable;
  
  // Status indicators
  bool _isBusy = false;
  bool get isBusy => _isBusy;
  
  String _errorMessage = '';
  String get errorMessage => _errorMessage;
  
  AppState() {
    _ttsService = TTSService(baseUrl: _baseUrl);
    initializeServices();
  }
  
  Future<void> initializeServices() async {
    try {
      _setBusy(true);
      _setError('');
      
      // Check if the TTS server is available
      _serverAvailable = await _ttsService.testConnection();
      print('TTS server available: $_serverAvailable');
      
    } catch (e) {
      _setError('Error initializing TTS service: $e');
    } finally {
      _setBusy(false);
    }
  }
  
  // Check if TTS is available for a language
  bool isModelDownloaded(String language) {
    // For the simple TTS server, we only need to check server availability
    return _serverAvailable;
  }
  
  // Get display name for a language
  String getLanguageDisplayName(String languageCode) {
    return languageNames[languageCode] ?? languageCode;
  }
  
  // Downloading is no longer required - just check server connection
  Future<void> downloadModel(String language) async {
    if (!supportedLanguages.contains(language)) {
      _setError('Unsupported language: $language');
      return;
    }
    
    try {
      _setBusy(true);
      _setError('');
      
      // Check TTS server connection
      _serverAvailable = await _ttsService.testConnection();
      
    } catch (e) {
      _setError('Error connecting to TTS server: $e');
    } finally {
      _setBusy(false);
    }
  }
  
  // Returns the full list of downloaded models for display purposes
  List<String> get downloadedModels {
    return _serverAvailable ? supportedLanguages : [];
  }
  
  Future<void> speak(String text, String language) async {
    if (text.isEmpty) {
      _setError('Please enter text to speak');
      return;
    }
    
    try {
      _setBusy(true);
      _setError('');
      
      // Stop any current playback
      await stopSpeaking();
      
      // Use TTS service to convert text to speech
      await _ttsService.textToSpeech(text, language);
      
    } catch (e) {
      _setError('Error synthesizing speech: $e');
    } finally {
      _setBusy(false);
    }
  }
  
  Future<void> stopSpeaking() async {
    try {
      await _ttsService.stop();
    } catch (e) {
      debugPrint('Error stopping speech: $e');
    }
  }
  
  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }
  
  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }
} 