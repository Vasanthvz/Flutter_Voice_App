import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';
import '../models/language.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class TextToVoiceScreen extends StatefulWidget {
  const TextToVoiceScreen({super.key});

  @override
  State<TextToVoiceScreen> createState() => _TextToVoiceScreenState();
}

class _TextToVoiceScreenState extends State<TextToVoiceScreen> {
  final TextEditingController _textController = TextEditingController();
  final ApiService _apiService = ApiService();
  final TTSService _ttsService = TTSService();
  String _translatedText = '';
  bool _isTranslating = false;
  bool _isSpeaking = false;
  Language? _sourceLanguage = Language.english;
  Language? _targetLanguage = Language.hindi;
  String _errorMessage = '';

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _translateText() async {
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
      final translation = await _apiService.translateText(
        _textController.text,
        _sourceLanguage!.code,
        _targetLanguage!.code,
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

  Future<void> _speakTranslatedText(AppState appState) async {
    if (_translatedText.isEmpty || _targetLanguage == null) {
      return;
    }

    if (_isSpeaking) {
      // If already speaking, stop it
      await appState.stopSpeaking();
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
      await appState.speak(_translatedText, _targetLanguage!.code);
    } catch (e) {
      setState(() {
        _errorMessage = 'TTS error: ${e.toString()}';
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

  void _copyToClipboard() {
    if (_translatedText.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _translatedText));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Translation copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Scaffold(
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
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
                            Center(
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isTranslating ? null : _translateText,
                                  icon: Icon(_isTranslating ? Icons.hourglass_empty : Icons.translate),
                                  label: Text(
                                    _isTranslating ? 'Translating...' : 'Translate',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6366F1),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    elevation: 4,
                                  ),
                                ),
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
                                        onPressed: () => _speakTranslatedText(appState),
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
      },
    );
  }
} 