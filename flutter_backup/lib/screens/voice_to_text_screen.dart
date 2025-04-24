import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import '../services/speech_recognition_service.dart';
import '../services/api_service.dart';
import '../models/language.dart';
import 'dart:html' as html;

class VoiceToTextScreen extends StatefulWidget {
  const VoiceToTextScreen({super.key});

  @override
  State<VoiceToTextScreen> createState() => _VoiceToTextScreenState();
}

class _VoiceToTextScreenState extends State<VoiceToTextScreen> with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  late final SpeechRecognitionService _speechService;
  late AnimationController _animationController;
  String _transcribedText = '';
  bool _isRecording = false;
  bool _isInitialized = false;
  String _errorMessage = '';
  Language? _selectedLanguage;
  String _detectedLanguage = '';
  bool _isOffline = true;

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
      onError: (error) => print('Error receiving transcription: $error'),
    );
    _initializeSpeechService();
  }

  Future<void> _requestPermissions() async {
    try {
      await html.window.navigator.mediaDevices?.getUserMedia({'audio': true});
      setState(() {
        _isInitialized = true;
        _errorMessage = '';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Microphone permission denied';
        _isInitialized = false;
      });
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

  @override
  void dispose() {
    _animationController.dispose();
    _speechService.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    try {
      setState(() => _isRecording = !_isRecording);
      
      if (_isRecording) {
        _animationController.repeat(reverse: true);
        await _speechService.startRecording();
      } else {
        _animationController.stop();
        await _speechService.stopRecordingAndTranscribe(_selectedLanguage);
      }
    } catch (e) {
      print('Error toggling recording: $e');
      setState(() => _isRecording = false);
      _animationController.stop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (kIsWeb)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Web version: For best results, use the mobile app',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ],
                  ),
                ),
              if (_errorMessage.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.language, color: Colors.blue, size: 24),
                    const SizedBox(width: 10),
                    DropdownButton<Language>(
                      value: _selectedLanguage,
                      hint: const Text(
                        'Select Language',
                        style: TextStyle(color: Colors.grey),
                      ),
                      dropdownColor: const Color(0xFF2A2A2A),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
                      underline: Container(
                        height: 2,
                        color: Colors.blue.withOpacity(0.3),
                      ),
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
                          _selectedLanguage = newValue;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: _isRecording
                      ? Colors.red.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isRecording ? Icons.mic : Icons.mic_none,
                      color: _isRecording ? Colors.red : Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isRecording ? 'Recording...' : 'Press the mic button to start',
                      style: TextStyle(
                        fontSize: 16,
                        color: _isRecording ? Colors.red : Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.text_fields, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _detectedLanguage.isNotEmpty
                              ? 'Detected Language: ${Language.fromCode(_detectedLanguage)?.displayName ?? _detectedLanguage}'
                              : 'Transcription',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _transcribedText.isEmpty ? 'No text transcribed yet' : _transcribedText,
                      style: TextStyle(
                        color: _transcribedText.isEmpty ? Colors.grey : Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isInitialized ? _toggleRecording : null,
        backgroundColor: _isRecording ? Colors.red : Colors.blue,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _isRecording ? 1.0 + _animationController.value * 0.2 : 1.0,
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
              ),
            );
          },
        ),
      ),
    );
  }
} 