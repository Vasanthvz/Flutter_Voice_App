import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;
import 'package:http_parser/http_parser.dart';
import 'dart:async';
import '../models/language.dart';

class TranscriptionResult {
  final String text;
  final String detectedLanguage;

  TranscriptionResult({required this.text, required this.detectedLanguage});

  factory TranscriptionResult.fromJson(Map<String, dynamic> json) {
    return TranscriptionResult(
      text: json['text'] as String,
      detectedLanguage: json['detected_language'] as String,
    );
  }
}

class ApiService {
  final String baseUrl = 'http://localhost:8001';

  Future<TranscriptionResult> transcribeWebAudio(html.Blob audioBlob, {Language? language}) async {
    try {
      print('Preparing to send audio chunk for real-time transcription...');
      print('Audio blob size: ${audioBlob.size} bytes');
      print('Audio blob type: ${audioBlob.type}');
      if (language != null) {
        print('Selected language: ${language.displayName} (${language.code})');
      }
      
      if (audioBlob.size == 0) {
        throw Exception('Empty audio chunk received');
      }

      final formData = html.FormData();
      formData.appendBlob('file', audioBlob, 'recording.webm');
      print('Created form data with audio chunk');

      final request = html.HttpRequest();
      final url = language != null 
          ? '$baseUrl/transcribe/realtime/?language=${language.code}'
          : '$baseUrl/transcribe/realtime/';
      request.open('POST', url);
      request.timeout = 30000; // 30 second timeout
      print('Opened connection to server with 30s timeout');
      
      final completer = Completer<TranscriptionResult>();
      
      request.onLoad.listen((e) {
        print('Received response from server');
        print('Response status: ${request.status}');
        if (request.status == 200) {
          try {
            final responseText = request.responseText;
            if (responseText == null || responseText.isEmpty) {
              throw Exception('Empty response from server');
            }
            print('Raw response: $responseText');
            
            final response = jsonDecode(responseText);
            if (!response.containsKey('text') || !response.containsKey('detected_language')) {
              throw Exception('Invalid response format: missing required fields');
            }
            
            final result = TranscriptionResult.fromJson(response);
            if (result.text.isEmpty) {
              throw Exception('Empty transcription result');
            }
            
            print('Successfully parsed transcription: ${result.text}');
            print('Detected language: ${result.detectedLanguage}');
            completer.complete(result);
          } catch (e) {
            print('Error parsing response: $e');
            completer.completeError('Failed to parse server response: $e');
          }
        } else {
          print('Server returned error status: ${request.status}');
          print('Error details: ${request.statusText}');
          print('Response text: ${request.responseText}');
          completer.completeError('Server error (${request.status}): ${request.statusText}');
        }
      });

      request.onError.listen((e) {
        print('Network error occurred: $e');
        completer.completeError('Network error: $e');
      });

      request.onTimeout.listen((_) {
        print('Request timed out after 30 seconds');
        completer.completeError('Request timed out');
      });

      request.upload.onProgress.listen((e) {
        if (e.lengthComputable) {
          final loaded = e.loaded ?? 0;
          final total = e.total ?? 1;
          if (total > 0) {
            final percentComplete = ((loaded / total) * 100).toStringAsFixed(1);
            print('Upload progress: $percentComplete%');
          }
        }
      });

      print('Sending request to server...');
      request.send(formData);
      print('Request sent, waiting for response...');
      
      return await completer.future;
    } catch (e) {
      print('Error in transcribeWebAudio: $e');
      rethrow;
    }
  }

  Future<String> transcribeAudio(String audioPath) async {
    try {
      print('Sending audio file to server...');
      
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/transcribe/'))
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          audioPath,
          contentType: MediaType('audio', 'wav'),
        ));

      final response = await request.send().timeout(
        Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Request timed out'),
      );
      
      final responseBody = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        if (responseBody.isEmpty) {
          throw Exception('Empty response from server');
        }
        
        final jsonResponse = jsonDecode(responseBody);
        if (!jsonResponse.containsKey('text')) {
          throw Exception('Invalid response format: missing text field');
        }
        
        final text = jsonResponse['text'] as String;
        if (text.isEmpty) {
          throw Exception('Empty transcription result');
        }
        
        print('Received transcription: $text');
        return text;
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
} 