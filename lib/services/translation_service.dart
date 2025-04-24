import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/language.dart';
import 'api_service.dart';

class TranslationService {
  // Use the API service's dynamic URL handling
  final ApiService _apiService;
  
  // Client-side cache for translations
  static final Map<String, String> _translationCache = {};
  
  // Maximum number of items to keep in cache
  static const int _maxCacheSize = 200;

  TranslationService(this._apiService);

  // Allow setting custom server URL
  void setServerUrl(String url) {
    _apiService.setCustomBaseUrl(url);
  }

  // Map language codes to simpler format for faster processing
  String _getFullLanguageCode(String shortCode) {
    // The server now expects simple codes like 'en', 'hi', etc.
    // No need for complex mapping anymore
    return shortCode.split('_')[0].toLowerCase();
  }
  
  // Get cache key from text and languages
  String _getCacheKey(String text, String sourceLang, String targetLang) {
    return '$text|$sourceLang|$targetLang';
  }
  
  // Add translation to cache
  void _addToCache(String text, String sourceLang, String targetLang, String translation) {
    // Manage cache size - remove oldest entries if needed
    if (_translationCache.length >= _maxCacheSize) {
      final oldestKey = _translationCache.keys.first;
      _translationCache.remove(oldestKey);
    }
    
    final key = _getCacheKey(text, sourceLang, targetLang);
    _translationCache[key] = translation;
  }
  
  // Check if translation is in cache
  String? _getFromCache(String text, String sourceLang, String targetLang) {
    final key = _getCacheKey(text, sourceLang, targetLang);
    return _translationCache[key];
  }

  Future<String> translateText({
    required String text,
    required Language sourceLanguage,
    required Language targetLanguage,
  }) async {
    try {
      debugPrint('Translating from ${sourceLanguage.code} to ${targetLanguage.code}');
      
      final baseUrl = _apiService.baseUrl;
      debugPrint('Using server URL: $baseUrl');
      
      final response = await http.post(
        Uri.parse('$baseUrl/translate/'),
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
        
        // Add to client cache
        _addToCache(text, _getFullLanguageCode(sourceLanguage.code), _getFullLanguageCode(targetLanguage.code), translatedText);
        
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
        Uri.parse('${_apiService.baseUrl}/translate_batch/'),
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