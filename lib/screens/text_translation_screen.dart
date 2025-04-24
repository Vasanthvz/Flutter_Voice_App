import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/translation_service.dart';
import '../services/tts_service.dart';
import '../models/language.dart';

class TextTranslationScreen extends StatefulWidget {
  const TextTranslationScreen({super.key});

  @override
  State<TextTranslationScreen> createState() => _TextTranslationScreenState();
}

class _TextTranslationScreenState extends State<TextTranslationScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _textController = TextEditingController();
  final ApiService _apiService = ApiService();
  final TranslationService _translationService = TranslationService(ApiService());
  final TTSService _ttsService = TTSService();
  Language? _sourceLanguage;
  Language? _targetLanguage;
  String _translatedText = '';
  bool _isTranslating = false;
  bool _isOffline = true;
  bool _isSpeaking = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    
    // Set default languages
    _sourceLanguage = Language.english;
    _targetLanguage = Language.hindi;
    
    // Initialize services
    _initializeServices();
  }
  
  Future<void> _initializeServices() async {
    try {
      // Get saved server URL from preferences
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('server_url');
      
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _apiService.setCustomBaseUrl(savedUrl);
        _translationService.setServerUrl(savedUrl);
      }
      
      // Check if TTS service is available
      bool isAvailable = await _ttsService.testConnection();
      setState(() {
        _isOffline = !isAvailable;
        if (!isAvailable) {
          _errorMessage = 'TTS service is not available';
        } else {
          _errorMessage = '';
        }
      });
    } catch (e) {
      setState(() {
        _isOffline = true;
        _errorMessage = 'Error initializing services: $e';
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  Future<void> _translate() async {
    if (_textController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter text to translate')),
      );
      return;
    }

    if (_sourceLanguage == null || _targetLanguage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both source and target languages')),
      );
      return;
    }

    setState(() {
      _isTranslating = true;
      _errorMessage = '';
    });

    try {
      // Test server connection before translating
      final isServerAvailable = await _apiService.pingServer();
      if (!isServerAvailable) {
        throw Exception('Translation server is not available. Please check your connection.');
      }

      final translation = await _translationService.translateText(
        text: _textController.text,
        sourceLanguage: _sourceLanguage!,
        targetLanguage: _targetLanguage!,
      );
      setState(() {
        _translatedText = translation;
        _isTranslating = false;
      });
    } catch (e) {
      setState(() {
        _isTranslating = false;
        _errorMessage = 'Translation error: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Translation error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _swapLanguages() {
    setState(() {
      final temp = _sourceLanguage;
      _sourceLanguage = _targetLanguage;
      _targetLanguage = temp;
      if (_translatedText.isNotEmpty) {
        final tempText = _textController.text;
        _textController.text = _translatedText;
        _translatedText = tempText;
      }
    });
  }

  void _copyToClipboard() {
    if (_translatedText.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _translatedText));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Translation copied to clipboard')),
      );
    }
  }

  Future<void> _speakTranslation() async {
    if (_translatedText.isEmpty || _targetLanguage == null) return;

    if (_isSpeaking) {
      // If already speaking, stop it
      await _ttsService.stop();
      setState(() {
        _isSpeaking = false;
      });
      return;
    }

    setState(() {
      _isSpeaking = true;
      _errorMessage = '';
    });

    try {
      await _ttsService.textToSpeech(
        _translatedText,
        _targetLanguage!.code,
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to speak text: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to speak text: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSpeaking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text(
          'Text to Voice',
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
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: !_isOffline ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: !_isOffline ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  !_isOffline ? Icons.cloud_done : Icons.cloud_off,
                  color: !_isOffline ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  !_isOffline ? 'TTS Online' : 'TTS Offline',
                  style: TextStyle(
                    color: !_isOffline ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFF1E1E2E),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Source text input
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
                                color: const Color(0xFF6366F1).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                              ),
                              child: const Text(
                                'Source Text',
                                style: TextStyle(
                                  color: Color(0xFF6366F1),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _textController,
                          maxLines: 5,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Enter text to translate...',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                            filled: true,
                            fillColor: const Color(0xFF323248),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Language selection
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
                                onPressed: _swapLanguages,
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
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _isTranslating ? null : _translate,
                          icon: Icon(_isTranslating ? Icons.hourglass_empty : Icons.translate),
                          label: Text(_isTranslating ? 'Translating...' : 'Translate'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Translated text
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
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      _isSpeaking ? Icons.stop : Icons.volume_up,
                                      color: Colors.green[300],
                                    ),
                                    onPressed: _speakTranslation,
                                    tooltip: _isSpeaking ? 'Stop Speaking' : 'Speak Translation',
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.copy, color: Colors.green[300]),
                                    onPressed: _copyToClipboard,
                                    tooltip: 'Copy to Clipboard',
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.withOpacity(0.3)),
                            ),
                            child: Text(
                              _translatedText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
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