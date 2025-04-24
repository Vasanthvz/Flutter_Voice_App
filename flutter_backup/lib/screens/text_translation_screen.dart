import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/translation_service.dart';
import '../models/language.dart';

class TextTranslationScreen extends StatefulWidget {
  const TextTranslationScreen({super.key});

  @override
  State<TextTranslationScreen> createState() => _TextTranslationScreenState();
}

class _TextTranslationScreenState extends State<TextTranslationScreen> {
  final TextEditingController _textController = TextEditingController();
  final TranslationService _translationService = TranslationService(ApiService());
  Language? _sourceLanguage;
  Language? _targetLanguage;
  String _translatedText = '';
  bool _isTranslating = false;
  bool _isOffline = true;

  @override
  void dispose() {
    _textController.dispose();
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
    });

    try {
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
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Translation error: $e')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SpeakEasy',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isOffline ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isOffline ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isOffline ? Icons.cloud_off : Icons.cloud,
                  color: _isOffline ? Colors.green : Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _isOffline ? 'Offline' : 'Online',
                  style: TextStyle(
                    color: _isOffline ? Colors.green : Colors.orange,
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF2A2A2A),
              const Color(0xFF1A1A1A),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.blue.withOpacity(0.3)),
                            ),
                            child: DropdownButton<Language>(
                              value: _sourceLanguage,
                              hint: const Text(
                                'Source Language',
                                style: TextStyle(color: Colors.grey),
                              ),
                              isExpanded: true,
                              dropdownColor: const Color(0xFF2A2A2A),
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
                              underline: Container(),
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
                                setState(() {
                                  _sourceLanguage = newValue;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.15),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.2),
                                blurRadius: 8,
                                spreadRadius: 1,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.swap_horiz,
                              color: Colors.blue,
                            ),
                            onPressed: _swapLanguages,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.blue.withOpacity(0.3)),
                            ),
                            child: DropdownButton<Language>(
                              value: _targetLanguage,
                              hint: const Text(
                                'Target Language',
                                style: TextStyle(color: Colors.grey),
                              ),
                              isExpanded: true,
                              dropdownColor: const Color(0xFF2A2A2A),
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
                              underline: Container(),
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
                                setState(() {
                                  _targetLanguage = newValue;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Stack(
                        children: [
                          TextField(
                            controller: _textController,
                            maxLines: 5,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              letterSpacing: 0.5,
                              height: 1.5,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter text to translate',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 16,
                                letterSpacing: 0.5,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.blue.withOpacity(0.3)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.blue.withOpacity(0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.blue, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.blue.withOpacity(0.05),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _textController.clear();
                                setState(() {
                                  _translatedText = '';
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isTranslating ? null : _translate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 3,
                      ),
                      child: _isTranslating
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Translate',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              if (_translatedText.isNotEmpty) ...[                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withOpacity(0.4), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.1),
                        blurRadius: 12,
                        spreadRadius: 2,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.translate, color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Translation',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.1),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.copy, color: Colors.green, size: 22),
                              onPressed: _copyToClipboard,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withOpacity(0.2)),
                        ),
                        child: Text(
                          _translatedText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.5,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}