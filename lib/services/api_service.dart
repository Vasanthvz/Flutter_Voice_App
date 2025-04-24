import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:http_parser/http_parser.dart';
import 'dart:async';
import '../models/language.dart';
import '../models/transcription_result.dart';

class ApiService {
  // Dynamic server URL based on platform
  String getBaseUrl() {
    if (kIsWeb) {
      return 'http://localhost:8002'; // Web server URL
    } else {
      return Platform.isAndroid
          ? 'http://10.0.2.2:8002' // Android emulator uses 10.0.2.2 to access localhost
          : 'http://localhost:8002'; // iOS simulator and physical devices use localhost
    }
  }
  
  // Allow overriding the base URL
  void setCustomBaseUrl(String url) {
    _customBaseUrl = url;
  }
  
  // Store custom base URL
  String? _customBaseUrl;
  
  // Get the effective base URL
  String get baseUrl => _customBaseUrl ?? getBaseUrl();

  // Test server connection
  Future<bool> pingServer() async {
    try {
      print('Pinging server at $baseUrl/ping');
      final response = await http.get(
        Uri.parse('$baseUrl/ping'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      print('Ping response: ${response.statusCode} - ${response.body}');
      
      return response.statusCode == 200;
    } catch (e) {
      print('Server ping failed: $e');
      return false;
    }
  }

  // Test transcription with sample data
  Future<Map<String, dynamic>> testTranscriptionEndpoint() async {
    try {
      print('Testing transcription endpoint...');
      
      final testUrl = Uri.parse('$baseUrl/transcribe/test/');
      final response = await http.post(
        testUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'test': true,
          'language': 'en'
        }),
      ).timeout(const Duration(seconds: 10));
      
      print('Test transcription response status: ${response.statusCode}');
      print('Test transcription response body: ${response.body}');
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'status_code': response.statusCode,
          'response': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'status_code': response.statusCode,
          'error': 'Server returned ${response.statusCode} status code',
        };
      }
    } catch (e) {
      print('Test transcription error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<String> transcribeAudio(String audioPath, [String language = 'en']) async {
    try {
      print('Sending audio file to server...');
      print('Audio file path: $audioPath');
      print('Language: $language');
      
      // Check if the file exists
      final file = File(audioPath);
      if (!await file.exists()) {
        throw Exception('Audio file does not exist: $audioPath');
      }

      final fileSize = await file.length();
      print('Audio file size: $fileSize bytes');
      
      if (fileSize == 0) {
        throw Exception('Audio file is empty');
      }
      
      // Create the multipart request with the specific endpoint and language parameter
      final request = http.MultipartRequest(
        'POST', 
        Uri.parse('$baseUrl/transcribe/realtime/').replace(
          queryParameters: {'language': language}
        )
      )
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          audioPath,
          contentType: MediaType('audio', 'wav'),
        ));

      print('Sending request to ${request.url}');
      
      // Send the request with a timeout
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60), // Increase timeout for larger files
        onTimeout: () => throw TimeoutException('Request timed out'),
      );
      
      print('Response status: ${streamedResponse.statusCode}');
      
      // Convert the streamed response to a regular response
      final response = await http.Response.fromStream(streamedResponse);
      final responseBody = response.body;
      
      if (response.statusCode == 200) {
        if (responseBody.isEmpty) {
          throw Exception('Empty response from server');
        }
        
        print('Raw response: $responseBody');
        
        try {
          final jsonResponse = jsonDecode(responseBody);
          
          if (!jsonResponse.containsKey('text')) {
            print('Response missing text field: $jsonResponse');
            throw Exception('Invalid response format: missing text field');
          }
          
          final text = jsonResponse['text'] as String;
          final detectedLang = jsonResponse['detected_language'] as String? ?? 'unknown';
          
          if (text.isEmpty) {
            throw Exception('Empty transcription result');
          }
          
          print('Received transcription: $text (detected language: $detectedLang)');
          return text;
        } catch (e) {
          print('JSON decode error: $e');
          throw Exception('Failed to parse server response: $e');
        }
      } else {
        print('Server error: ${response.statusCode}');
        print('Response body: $responseBody');
        throw Exception('Server error (${response.statusCode}): $responseBody');
      }
    } catch (e) {
      print('Error in transcribeAudio: $e');
      rethrow;
    }
  }

  Future<String> translateText(String text, String sourceLang, String targetLang) async {
    try {
      print('Sending translation request to server...');
      print('Text: $text');
      print('From: $sourceLang to: $targetLang');

      // Simplify language code processing
      final sourceCode = sourceLang.split('_')[0].toLowerCase();
      final targetCode = targetLang.split('_')[0].toLowerCase();

      // Skip translation if languages are the same
      if (sourceCode == targetCode) {
        return text;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/translate/'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'text': text,
          'source_lang': sourceCode,
          'target_lang': targetCode,
        }),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('Translation request timed out');
        },
      );

      print('Translation response status: ${response.statusCode}');
      print('Raw response body: ${response.body}');

      if (response.statusCode == 200) {
        // Properly decode the response using UTF-8
        final String decodedBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decodedBody);
        
        if (data['translated_text'] != null) {
          final translatedText = data['translated_text'].toString();
          print('Successfully translated to: $translatedText');
          return translatedText;
        } else if (data['error'] != null) {
          throw Exception(data['error']);
        } else {
          throw Exception('Invalid translation response format');
        }
      } else {
        throw Exception('Translation failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Translation error: $e');
      rethrow;
    }
  }
} 