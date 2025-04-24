import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/language.dart';
import 'api_service.dart';

class TranslationService {
  final String _baseUrl = 'http://localhost:8001';  // Local server URL
  final ApiService _apiService;

  TranslationService(this._apiService);

  // Map short language codes to full codes with scripts
  String _getFullLanguageCode(String shortCode) {
    final Map<String, String> codeMapping = {
      'en': 'eng_Latn',
      'hi': 'hin_Deva',
      'ta': 'tam_Taml',
      'ml': 'mal_Mlym',
      'bn': 'ben_Beng',
      'mr': 'mar_Deva',
      'ur': 'urd_Arab',
      'ne': 'nep_Deva',
      'si': 'sin_Sinh',
    };
    return codeMapping[shortCode] ?? '${shortCode}_Deva';
  }

  Future<String> translateText({
    required String text,
    required Language sourceLanguage,
    required Language targetLanguage,
  }) async {
    try {
      debugPrint('Translating from ${sourceLanguage.code} to ${targetLanguage.code}');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/translate/'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
        body: utf8.encode(jsonEncode({
          'text': text,
          'source_lang': _getFullLanguageCode(sourceLanguage.code),
          'target_lang': _getFullLanguageCode(targetLanguage.code),
        })),
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final String decodedBody = utf8.decode(response.bodyBytes);
        final result = jsonDecode(decodedBody);
        if (result['error'] != null && result['error'].toString().isNotEmpty) {
          throw Exception(result['error']);
        }
        final translatedText = result['translated_text'] as String;
        debugPrint('Translated text: $translatedText');
        return translatedText;
      } else {
        throw Exception('Translation failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Translation error: $e');
      throw Exception('Translation error: $e');
    }
  }

  Future<List<String>> translateBatch({
    required List<String> texts,
    required Language sourceLanguage,
    required Language targetLanguage,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/translate_batch/'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
        body: utf8.encode(jsonEncode({
          'texts': texts,
          'source_lang': _getFullLanguageCode(sourceLanguage.code),
          'target_lang': _getFullLanguageCode(targetLanguage.code),
        })),
      );

      if (response.statusCode == 200) {
        final String decodedBody = utf8.decode(response.bodyBytes);
        final result = jsonDecode(decodedBody);
        if (result['error'] != null && result['error'].toString().isNotEmpty) {
          throw Exception(result['error']);
        }
        return (result['translated_texts'] as List).cast<String>();
      } else {
        throw Exception('Batch translation failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Batch translation error: $e');
      throw Exception('Batch translation error: $e');
    }
  }
} 