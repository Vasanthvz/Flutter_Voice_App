// This file is only imported conditionally when on web platform
import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/language.dart';
import '../models/transcription_result.dart';

class WebSpeechService {
  final String baseUrl;
  html.MediaStream? _stream;
  html.MediaRecorder? _mediaRecorder;
  final List<html.Blob> _audioChunks = [];
  bool _isRecording = false;
  final _transcriptionController = StreamController<TranscriptionResult>.broadcast();
  
  Stream<TranscriptionResult> get transcriptionStream => _transcriptionController.stream;
  
  WebSpeechService({required this.baseUrl});
  
  bool get isRecording => _isRecording;
  
  Future<void> initialize() async {
    try {
      print('Initializing WebSpeechService...');
      // Request microphone permission with optimized settings for Whisper
      final Map<String, dynamic> constraints = {
        'audio': {
          'channelCount': 1,          // Mono audio
          'sampleRate': 16000,        // 16kHz sample rate (optimal for Whisper)
          'echoCancellation': true,   // Reduce echo
          'noiseSuppression': true,   // Reduce background noise
          'autoGainControl': true,    // Automatically adjust volume
        }
      };
      
      _stream = await html.window.navigator.mediaDevices?.getUserMedia(constraints);
      print('Microphone access granted with optimized settings');
      
      if (_stream != null) {
        final tracks = _stream!.getAudioTracks();
        print('Got ${tracks.length} audio tracks');
        
        // Release the mic immediately
        await _stopAllTracks();
      }
    } catch (e) {
      print('Error initializing WebSpeechService: $e');
      rethrow;
    }
  }
  
  Future<void> _stopAllTracks() async {
    if (_stream != null) {
      final tracks = _stream!.getAudioTracks();
      for (var track in tracks) {
        track.stop();
      }
      _stream = null;
    }
  }
  
  Future<void> startRecording() async {
    try {
      print('Starting web audio recording...');
      _audioChunks.clear();
      
      // Request microphone access if we don't have it
      if (_stream == null) {
        final Map<String, dynamic> constraints = {
          'audio': {
            'channelCount': 1,
            'sampleRate': 16000,
            'echoCancellation': true,
            'noiseSuppression': true,
            'autoGainControl': true,
          }
        };
        
        _stream = await html.window.navigator.mediaDevices?.getUserMedia(constraints);
        print('Microphone access granted');
      }
      
      // Set up the media recorder with opus codec for compatibility
      final options = <String, dynamic>{
        'mimeType': 'audio/webm;codecs=opus',
        'audioBitsPerSecond': 16000
      };
      
      _mediaRecorder = html.MediaRecorder(_stream!, options);
      
      // Add event listeners
      _mediaRecorder!.addEventListener('dataavailable', (event) {
        final blob = (event as html.BlobEvent).data;
        if (blob != null && blob.size > 0) {
          print('Received audio chunk of size: ${blob.size} bytes');
          _audioChunks.add(blob);
        }
      });
      
      _mediaRecorder!.start(1000); // Collect chunks every second
      _isRecording = true;
      print('Web audio recording started successfully');
    } catch (e) {
      print('Error starting web recording: $e');
      await _stopAllTracks();
      rethrow;
    }
  }
  
  Future<void> stopRecordingAndTranscribe([Language? language]) async {
    if (!_isRecording || _mediaRecorder == null) {
      print('Not recording or MediaRecorder is null');
      return;
    }
    
    try {
      print('Stopping web audio recording...');
      final completer = Completer<void>();
      
      _mediaRecorder!.addEventListener('stop', (event) async {
        try {
          if (_audioChunks.isEmpty) {
            throw Exception('No audio data recorded');
          }
          
          print('Number of audio chunks: ${_audioChunks.length}');
          final blob = html.Blob(_audioChunks, 'audio/webm;codecs=opus');
          print('Created final blob of size: ${blob.size} bytes');
          
          // Send the audio for transcription
          await _transcribeAudioBlob(blob, language);
        } catch (e) {
          print('Error processing audio: $e');
          _transcriptionController.addError(e);
        } finally {
          completer.complete();
        }
      });
      
      _mediaRecorder!.stop();
      _isRecording = false;
      await _stopAllTracks();
      await completer.future;
    } catch (e) {
      print('Error stopping web recording: $e');
      _transcriptionController.addError(e);
    } finally {
      _mediaRecorder = null;
      _audioChunks.clear();
    }
  }
  
  Future<void> _transcribeAudioBlob(html.Blob audioBlob, Language? language) async {
    print('Preparing to transcribe audio blob...');
    print('Audio blob size: ${audioBlob.size} bytes');
    
    try {
      // Create FormData
      final formData = html.FormData();
      formData.appendBlob('file', audioBlob, 'recording.webm');
      
      // Set up the URL with language parameter if provided
      final url = language != null 
          ? '$baseUrl/transcribe/realtime/?language=${language.code}'
          : '$baseUrl/transcribe/realtime/';
      
      print('Sending transcription request to: $url');
      
      // Create and set up XMLHttpRequest
      final request = html.HttpRequest();
      request.open('POST', url);
      request.timeout = 30000; // 30 second timeout
      
      final completer = Completer<void>();
      
      request.onLoad.listen((event) {
        if (request.status == 200) {
          try {
            final jsonResponse = jsonDecode(request.responseText!);
            print('Received transcription response: $jsonResponse');
            
            if (jsonResponse['text'] != null) {
              final text = jsonResponse['text'] as String;
              final detectedLanguage = jsonResponse['detected_language'] as String? ?? language?.code ?? 'en';
              
              print('Transcription: $text');
              print('Detected language: $detectedLanguage');
              
              _transcriptionController.add(TranscriptionResult(
                text: text,
                detectedLanguage: detectedLanguage,
              ));
            } else {
              throw Exception('Invalid response format: missing text field');
            }
          } catch (e) {
            print('Error parsing transcription response: $e');
            _transcriptionController.addError(e);
          }
        } else {
          print('Transcription request failed: ${request.status} - ${request.statusText}');
          _transcriptionController.addError(
              Exception('Server error: ${request.status} - ${request.statusText}'));
        }
        completer.complete();
      });
      
      request.onError.listen((event) {
        print('Transcription request error: ${request.statusText}');
        _transcriptionController.addError(Exception('Request error: ${request.statusText}'));
        completer.complete();
      });
      
      request.onTimeout.listen((event) {
        print('Transcription request timed out');
        _transcriptionController.addError(Exception('Request timed out'));
        completer.complete();
      });
      
      // Send the request
      request.send(formData);
      await completer.future;
      
    } catch (e) {
      print('Error during transcription: $e');
      _transcriptionController.addError(e);
    }
  }
  
  void dispose() {
    _stopAllTracks();
    if (_isRecording) {
      stopRecordingAndTranscribe();
    }
    _transcriptionController.close();
    _mediaRecorder = null;
    _audioChunks.clear();
  }
} 