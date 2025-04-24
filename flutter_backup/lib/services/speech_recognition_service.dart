import 'dart:io';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'api_service.dart';
import 'dart:async';
import '../models/language.dart';

class SpeechRecognitionService {
  final _audioRecorder = Record();
  final ApiService _apiService;
  String? _currentRecordingPath;
  html.MediaRecorder? _webRecorder;
  html.MediaStream? _stream;
  final List<html.Blob> _audioChunks = [];
  final List<html.MediaStreamTrack> _tracks = [];
  bool _isRecording = false;
  final _transcriptionController = StreamController<TranscriptionResult>.broadcast();

  // Audio constraints for better quality and smaller file size
  static const Map<String, dynamic> audioConstraints = {
    'audio': {
      'channelCount': 1,
      'sampleRate': 16000,
      'sampleSize': 16,
      'echoCancellation': true,
      'noiseSuppression': true,
      'autoGainControl': true,
    }
  };

  Stream<TranscriptionResult> get transcriptionStream => _transcriptionController.stream;

  SpeechRecognitionService(this._apiService);

  bool get isRecording => _isRecording;

  Future<void> initialize() async {
    if (!kIsWeb) return;

    try {
      print('Requesting microphone access with optimized settings...');
      final constraints = {
        'audio': {
          'channelCount': 1,
          'sampleRate': 16000,
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        }
      };

      _stream = await html.window.navigator.mediaDevices?.getUserMedia(constraints);
      print('Microphone access granted with optimized settings');

      if (_stream != null) {
        final tracks = _stream!.getAudioTracks();
        print('Got ${tracks.length} audio tracks');
      }
    } catch (e) {
      print('Error initializing audio: $e');
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
    if (!kIsWeb) return;

    try {
      print('Setting up MediaRecorder event listeners');
      _audioChunks.clear();

      if (_stream == null) {
        print('Requesting microphone access with optimized settings...');
        final constraints = {
          'audio': {
            'channelCount': 1,
            'sampleRate': 16000,
            'echoCancellation': true,
            'noiseSuppression': true,
            'autoGainControl': true,
          }
        };

        _stream = await html.window.navigator.mediaDevices?.getUserMedia(constraints);
        print('Microphone access granted with optimized settings');

        if (_stream != null) {
          final tracks = _stream!.getAudioTracks();
          print('Got ${tracks.length} audio tracks');
        }
      }

      final options = <String, dynamic>{
        'mimeType': 'audio/webm;codecs=opus',
        'audioBitsPerSecond': 16000
      };

      _webRecorder = html.MediaRecorder(_stream!, options as Map<String, dynamic>?);

      _webRecorder!.addEventListener('dataavailable', (event) {
        final blob = (event as html.BlobEvent).data;
        if (blob != null && blob.size > 0) {
          print('Received audio chunk of size: ${blob.size} bytes');
          _audioChunks.add(blob);
        }
      });

      print('Starting MediaRecorder with optimized settings');
      _webRecorder!.start(1000); // Collect chunks every second
      print('Recording started successfully with optimized settings');
    } catch (e) {
      print('Error starting recording: $e');
      await _stopAllTracks();
      rethrow;
    }
  }

  Future<void> stopRecordingAndTranscribe([Language? language]) async {
    if (!kIsWeb || _webRecorder == null) return;

    try {
      print('Stopping recording...');
      final completer = Completer<void>();

      _webRecorder!.addEventListener('stop', (event) async {
        try {
          if (_audioChunks.isEmpty) {
            throw Exception('No audio data recorded');
          }

          print('Number of audio chunks: ${_audioChunks.length}');
          final blob = html.Blob(_audioChunks, 'audio/webm;codecs=opus');
          print('Created final blob of size: ${blob.size} bytes');

          print('Sending audio for transcription...');
          final result = await _apiService.transcribeWebAudio(blob, language: language);
          _transcriptionController.add(result);
        } catch (e) {
          print('Error processing audio: $e');
          _transcriptionController.addError(e);
        } finally {
          completer.complete();
        }
      });

      _webRecorder!.stop();
      await _stopAllTracks();
      await completer.future;
    } catch (e) {
      print('Error stopping recording: $e');
      _transcriptionController.addError(e);
    } finally {
      _webRecorder = null;
      _audioChunks.clear();
    }
  }

  void dispose() {
    _audioRecorder.dispose();
    if (_currentRecordingPath != null) {
      File(_currentRecordingPath!).exists().then((exists) {
        if (exists) {
          File(_currentRecordingPath!).delete();
        }
      });
    }
    if (_isRecording) {
      stopRecordingAndTranscribe();
    }
    _stopAllTracks();
    _transcriptionController.close();
    _stream = null;
    _webRecorder = null;
    _audioChunks.clear();
  }
} 