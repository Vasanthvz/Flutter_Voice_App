import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import '../services/speech_recognition_service.dart';
import '../services/api_service.dart';
import '../models/language.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import '../services/translation_service.dart';

class VoiceToTextScreen extends StatefulWidget {
  const VoiceToTextScreen({super.key});

  @override
  State<VoiceToTextScreen> createState() => _VoiceToTextScreenState();
}

class _VoiceToTextScreenState extends State<VoiceToTextScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ApiService _apiService = ApiService();
  final TranslationService _translationService = TranslationService(ApiService());
  String _transcribedText = '';
  String _translatedText = '';
  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _isTranslating = false;
  Language? _sourceLanguage;
  Language? _targetLanguage;
  bool _showLanguageSelection = false;
  List<Language> _supportedLanguages = Language.values.toList();
  late final SpeechRecognitionService _speechService;
  late AnimationController _animationController;
  String _detectedLanguage = '';
  bool _isOffline = true;
  bool _isInitialized = false;
  String _errorMessage = '';
  Timer? _translationDebouncer;
  String _lastTranslatedText = '';
  bool _isTranslationInProgress = false;
  bool _isTranscriptionComplete = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _speechService = SpeechRecognitionService(_apiService);
    _speechService.transcriptionStream.listen(
      (result) {
        setState(() {
          _transcribedText = result.text;
          _detectedLanguage = result.detectedLanguage;
        });
      },
      onError: (error) {
        print('Error receiving transcription: $error');
        setState(() {
          _errorMessage = 'Transcription error: $error';
        });
      },
    );
    
    _sourceLanguage = Language.english;
    _targetLanguage = Language.hindi;
    
    _initializeSpeechService();
    _checkServerConnectionSilently();
  }

  Future<void> _requestPermissions() async {
    try {
      if (kIsWeb) {
        _requestWebMicrophonePermission();
      } else {
        final status = await Permission.microphone.request();
        setState(() {
          _isInitialized = status.isGranted;
          _errorMessage = status.isDenied ? 'Microphone permission denied' : '';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error requesting permissions: $e';
        _isInitialized = false;
      });
    }
  }

  void _requestWebMicrophonePermission() {
    if (kIsWeb) {
      try {
        _speechService.initialize().then((_) {
          setState(() {
            _isInitialized = true;
            _errorMessage = '';
          });
        }).catchError((error) {
          print('Error initializing microphone: $error');
          setState(() {
            _isInitialized = false;
            _errorMessage = 'Microphone permission denied';
          });
        });
      } catch (e) {
        print('Error requesting web microphone permission: $e');
        setState(() {
          _errorMessage = 'Error requesting microphone permission: $e';
          _isInitialized = false;
        });
      }
    }
  }

  Future<void> _initializeSpeechService() async {
    try {
      await _requestPermissions();
      if (_isInitialized) {
        await _speechService.initialize();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing: $e';
        _isInitialized = false;
      });
    }
  }

  Future<void> _checkServerConnectionSilently() async {
    try {
      final isConnected = await _apiService.pingServer();
      setState(() {
        _isOffline = !isConnected;
      });
    } catch (e) {
      print('Error checking server connection: $e');
      setState(() {
        _isOffline = true;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _speechService.dispose();
    _stopRecording();
    _translationDebouncer?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (!_isRecording) {
        setState(() {
          _isRecording = true;
          _transcribedText = '';
          _translatedText = '';
        });

        await _speechService.startRecording();
      }
    } catch (e) {
      print('Error starting recording: $e');
      setState(() {
        _isRecording = false;
        _errorMessage = 'Error starting recording: $e';
      });
    }
  }

  Future<void> _stopRecording() async {
    try {
      if (_isRecording) {
        await _speechService.stopRecordingAndTranscribe(_sourceLanguage);
        setState(() {
          _isRecording = false;
          _isTranscriptionComplete = true;
        });
      }
    } catch (e) {
      print('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
        _errorMessage = 'Error stopping recording: $e';
      });
    }
  }

  Future<void> _translateText() async {
    if (_transcribedText.isEmpty || 
        _sourceLanguage == null || 
        _targetLanguage == null || 
        _sourceLanguage!.code == _targetLanguage!.code) {
      return;
    }

    try {
      setState(() {
        _isTranslating = true;
      });

      final translatedText = await _apiService.translateText(
        _transcribedText.trim(),
        _sourceLanguage!.code,
        _targetLanguage!.code,
      );

      if (mounted) {
        setState(() {
          _translatedText = translatedText.trim();
          _isTranslating = false;
        });
      }
    } catch (e) {
      print('Error in translation: $e');
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Translation error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Voice to Text',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: const Color(0xFF1E1E2E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E1E2E),
              Color(0xFF141420),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16.0),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: const Color(0xFF282838),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Source Language',
                                    style: TextStyle(
                                      color: Color(0xFFD1D5DB),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF323248),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                                    ),
                                    child: DropdownButton<Language>(
                                      value: _sourceLanguage,
                                      underline: Container(),
                                      isExpanded: true,
                                      dropdownColor: const Color(0xFF323248),
                                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF6366F1)),
                                      items: Language.values.map((Language language) {
                                        return DropdownMenuItem<Language>(
                                          value: language,
                                          child: Text(
                                            language.displayName,
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (Language? newValue) {
                                        if (newValue != null) {
                                          setState(() {
                                            _sourceLanguage = newValue;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.swap_horiz,
                                  color: Color(0xFF6366F1),
                                ),
                                onPressed: () {
                                  setState(() {
                                    final temp = _sourceLanguage;
                                    _sourceLanguage = _targetLanguage;
                                    _targetLanguage = temp;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Target Language',
                                    style: TextStyle(
                                      color: Color(0xFFD1D5DB),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF323248),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                                    ),
                                    child: DropdownButton<Language>(
                                      value: _targetLanguage,
                                      underline: Container(),
                                      isExpanded: true,
                                      dropdownColor: const Color(0xFF323248),
                                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF6366F1)),
                                      items: Language.values.map((Language language) {
                                        return DropdownMenuItem<Language>(
                                          value: language,
                                          child: Text(
                                            language.displayName,
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (Language? newValue) {
                                        if (newValue != null) {
                                          setState(() {
                                            _targetLanguage = newValue;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: const Color(0xFF282838),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isRecording)
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF6366F1).withOpacity(0.2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withOpacity(0.3),
                                  blurRadius: 12,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.stop_circle,
                                color: Color(0xFF6366F1),
                                size: 70,
                              ),
                              onPressed: _stopRecording,
                            ),
                          )
                        else
                          GestureDetector(
                            onTap: _isInitialized ? _startRecording : null,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isInitialized 
                                    ? const Color(0xFF6366F1).withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.2),
                                boxShadow: _isInitialized
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF6366F1).withOpacity(0.3),
                                          blurRadius: 12,
                                          spreadRadius: 4,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                Icons.mic,
                                color: _isInitialized 
                                    ? const Color(0xFF6366F1)
                                    : Colors.grey,
                                size: 60,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          _isRecording 
                              ? 'Recording... Tap to stop'
                              : _isInitialized 
                                  ? 'Tap to start recording'
                                  : 'Microphone not available',
                          style: TextStyle(
                            color: _isInitialized ? Colors.white : Colors.grey,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_transcribedText.isNotEmpty)
                          Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            color: const Color(0xFF282838),
                            margin: const EdgeInsets.only(bottom: 20),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6366F1).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                                        ),
                                        child: const Text(
                                          'Transcribed Text',
                                          style: TextStyle(
                                            color: Color(0xFF6366F1),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.copy, color: Color(0xFF6366F1)),
                                        onPressed: () => _copyToClipboard(_transcribedText),
                                        tooltip: 'Copy to clipboard',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF323248),
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                                    ),
                                    child: SelectableText(
                                      _transcribedText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  if (_isTranscriptionComplete && _transcribedText.isNotEmpty)
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _translateText,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF6366F1),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(15),
                                          ),
                                          elevation: 4,
                                        ),
                                        icon: const Icon(Icons.translate),
                                        label: Text(
                                          _isTranslating ? 'Translating...' : 'Translate',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        if (_translatedText.isNotEmpty)
                          Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            color: const Color(0xFF282838),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                                        ),
                                        child: const Text(
                                          'Translated Text',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.copy, color: Colors.green),
                                        onPressed: () => _copyToClipboard(_translatedText),
                                        tooltip: 'Copy to clipboard',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF323248),
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                                    ),
                                    child: SelectableText(
                                      _translatedText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 