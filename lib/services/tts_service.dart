import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class TTSService {
  // Default base URL for the TTS server
  final String _baseUrl;
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  TTSService({String? baseUrl}) : _baseUrl = baseUrl ?? 'http://localhost:8002';
  
  /// Tests the connection to the TTS server
  Future<bool> testConnection({Duration? timeout}) async {
    try {
      print('Testing TTS connection to $_baseUrl');
      final response = await http.get(
        Uri.parse('$_baseUrl/tts/test'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout ?? const Duration(seconds: 3));
      
      print('TTS test response: ${response.statusCode}');
      if (response.statusCode == 200) {
        print('TTS service response: ${response.body}');
        return true;
      }
      return false;
    } catch (e) {
      print('TTS connection test failed: $e');
      return false;
    }
  }
  
  /// Gets the list of available languages
  Future<List<String>> getAvailableLanguages({Duration? timeout}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/tts/available_models'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout ?? const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['supported_languages']);
      } else {
        throw Exception('Failed to get languages: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting TTS languages: $e');
      throw Exception('Error getting available languages: $e');
    }
  }
  
  /// Converts text to speech
  Future<void> textToSpeech(String text, String language, {Duration? timeout}) async {
    if (text.isEmpty) {
      throw Exception('Text cannot be empty');
    }
    
    try {
      // Clean up any previous audio
      await _audioPlayer.stop();
      
      // Make API request to TTS service
      final response = await http.post(
        Uri.parse('$_baseUrl/tts/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'language': language,
        }),
      ).timeout(timeout ?? const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        if (kIsWeb) {
          // For web, create audio source from bytes
          await _audioPlayer.setAudioSource(
            BytesSource(response.bodyBytes),
          );
        } else {
          // For mobile, save to temporary file and play
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/tts_output.mp3');
          await tempFile.writeAsBytes(response.bodyBytes);
          
          // Play the audio file
          await _audioPlayer.setFilePath(tempFile.path);
        }
        
        // Start playback
        await _audioPlayer.play();
      } else {
        throw Exception('TTS request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('TTS error: $e');
      throw Exception('TTS error: $e');
    }
  }
  
  /// Stops any ongoing TTS playback
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      print('Error stopping TTS: $e');
    }
  }
  
  /// Disposes resources
  void dispose() {
    _audioPlayer.dispose();
  }
}

/// Custom audio source for web
class BytesSource extends StreamAudioSource {
  final Uint8List _bytes;
  
  BytesSource(this._bytes);
  
  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/mp3',
    );
  }
} 