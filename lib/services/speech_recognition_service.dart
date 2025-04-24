import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api_service.dart';
import 'dart:async';
import '../models/language.dart';
import '../models/transcription_result.dart';
// Conditionally import dart:html for web
import 'web_imports.dart' if (dart.library.html) 'dart:html' as html;
import 'dart:convert';

class SpeechRecognitionService {
  final _audioRecorder = AudioRecorder();
  final ApiService _apiService;
  String? _currentRecordingPath;
  bool _isRecording = false;
  final _transcriptionController = StreamController<TranscriptionResult>.broadcast();
  
  // Web-specific properties
  dynamic _webMediaRecorder;
  List<dynamic> _audioChunks = [];
  dynamic _webStream;

  Stream<TranscriptionResult> get transcriptionStream => _transcriptionController.stream;

  SpeechRecognitionService(this._apiService);

  bool get isRecording => _isRecording;

  Future<void> initialize() async {
    if (kIsWeb) {
      try {
        // Initialize web audio
        await _initializeWebAudio();
      } catch (e) {
        print('Error initializing web audio: $e');
        rethrow;
      }
      return;
    }
    
    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw Exception('Microphone permission not granted');
      }

      // Request storage permission for saving recordings
      final storageStatus = await Permission.storage.request();
      if (storageStatus != PermissionStatus.granted) {
        throw Exception('Storage permission not granted');
      }
      
      // Log successful initialization
      print('SpeechRecognitionService initialized successfully');
    } catch (e) {
      print('Error initializing audio: $e');
      rethrow;
    }
  }
  
  Future<void> _initializeWebAudio() async {
    if (!kIsWeb) return;
    
    try {
      print('Initializing web audio with optimized settings');
      // Define audio constraints optimized for speech recognition
      final constraints = {
        'audio': {
          'channelCount': 1,          // Mono recording
          'sampleRate': 16000,        // 16kHz sample rate (optimal for Whisper)
          'echoCancellation': true,   // Echo cancellation
          'noiseSuppression': true,   // Noise suppression
          'autoGainControl': true,    // Auto gain control
        }
      };
      
      // Request microphone access with optimized settings
      // Use try-catch to handle potential errors
      try {
        _webStream = await html.window.navigator.mediaDevices?.getUserMedia(constraints);
        
        if (_webStream != null) {
          print('Microphone access granted with optimized settings');
          // Release the microphone until recording starts
          await _stopAllWebTracks();
        }
      } catch (e) {
        print('Error requesting microphone permission: $e');
        rethrow;
      }
    } catch (e) {
      print('Error initializing web audio: $e');
      rethrow;
    }
  }
  
  Future<void> _stopAllWebTracks() async {
    if (!kIsWeb || _webStream == null) return;
    
    try {
      final tracks = _webStream.getAudioTracks();
      for (var track in tracks) {
        track.stop();
      }
      _webStream = null;
      print('Web audio tracks stopped');
    } catch (e) {
      print('Error stopping web audio tracks: $e');
    }
  }

  Future<void> startRecording() async {
    if (kIsWeb) {
      await _startWebRecording();
      return;
    }

    try {
      final hasPermission = await _audioRecorder.hasPermission();
      print('Microphone permission status: $hasPermission');
      
      if (hasPermission) {
        // Get application documents directory for saving the recording
        final directory = await getTemporaryDirectory(); // Using temp directory for better performance
        final path = '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';
        _currentRecordingPath = path;
        
        print('Starting recording to: $_currentRecordingPath');
        print('Directory exists: ${await Directory(directory.path).exists()}');
        print('Recording config: WAV format, 16kHz sample rate, mono channel');
        
        // Configure audio recording with parameters matching what the server expects
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,          // Use WAV format
            bitRate: 128000,                    // 128kbps bit rate
            sampleRate: 16000,                  // 16kHz sample rate (very important for Whisper)
            numChannels: 1,                     // Mono recording
          ),
          path: path,
        );
        
        _isRecording = true;
        print('Recording started successfully');
      } else {
        print('Microphone permission not granted');
        throw Exception('Microphone permission not granted');
      }
    } catch (e) {
      print('Error starting recording: $e');
      rethrow;
    }
  }
  
  Future<void> _startWebRecording() async {
    if (!kIsWeb) return;
    
    try {
      print('Starting web audio recording...');
      _audioChunks = [];
      
      // Request microphone access if we don't have it
      if (_webStream == null) {
        final constraints = {
          'audio': {
            'channelCount': 1,
            'sampleRate': 16000,
            'echoCancellation': true,
            'noiseSuppression': true,
            'autoGainControl': true,
          }
        };
        
        try {
          _webStream = await html.window.navigator.mediaDevices?.getUserMedia(constraints);
          print('Microphone access granted for web recording');
        } catch (e) {
          print('Error requesting microphone access: $e');
          throw Exception('Microphone access denied: $e');
        }
      }
      
      // Create media recorder only if the stream is available
      if (_webStream != null) {
        // Configure MediaRecorder with optimal settings
        final options = {
          'mimeType': 'audio/webm;codecs=opus',
          'audioBitsPerSecond': 16000
        };
        
        // Create MediaRecorder
        _webMediaRecorder = html.MediaRecorder(_webStream, options);
        
        // Set up data collection
        _webMediaRecorder.addEventListener('dataavailable', (event) {
          final blob = (event as html.BlobEvent).data;
          if (blob != null && blob.size > 0) {
            print('Received audio chunk of size: ${blob.size} bytes');
            _audioChunks.add(blob);
          }
        });
        
        // Start recording, collecting chunks every second
        _webMediaRecorder.start(1000);
        _isRecording = true;
        print('Web audio recording started successfully');
      } else {
        throw Exception('Could not obtain microphone access');
      }
    } catch (e) {
      print('Error starting web recording: $e');
      await _stopAllWebTracks();
      rethrow;
    }
  }

  Future<void> stopRecordingAndTranscribe([Language? language]) async {
    if (kIsWeb) {
      await _stopWebRecordingAndTranscribe(language);
      return;
    }
    
    if (!_isRecording) {
      print('Not recording, nothing to stop');
      return;
    }

    try {
      print('Stopping recording...');
      final path = await _audioRecorder.stop();
      _isRecording = false;
      
      print('Recording stopped, file saved at: $path');
      
      if (path != null) {
        print('Sending audio file to server for transcription...');
        print('Selected language: ${language?.code ?? "auto"}');
        
        // Check if file exists and has content
        final file = File(path);
        final fileExists = await file.exists();
        final fileSize = fileExists ? await file.length() : 0;
        
        print('File exists: $fileExists, size: $fileSize bytes');
        
        if (!fileExists || fileSize == 0) {
          print('Error: Recording file is empty or does not exist');
          throw Exception('Recording file is empty or does not exist');
        }
        
        try {
          // Verify file format
          print('Verifying file format...');
          final bytes = await file.openRead(0, 12).fold<List<int>>(
            <int>[],
            (previous, element) => previous..addAll(element),
          );
          
          // WAV files should start with RIFF header
          final isWav = bytes.length >= 4 && 
            bytes[0] == 0x52 && // R
            bytes[1] == 0x49 && // I
            bytes[2] == 0x46 && // F
            bytes[3] == 0x46;   // F
            
          print('File appears to be valid WAV format: $isWav');
          
          if (!isWav) {
            print('Warning: File does not appear to be a valid WAV file');
          }
        } catch (e) {
          print('Error verifying file format: $e');
        }
        
        // Pass the language code to the transcription API
        print('Sending transcription request to API...');
        final result = await _apiService.transcribeAudio(
          path, 
          language?.code ?? 'en'
        );
        
        print('Transcription result received: $result');
        
        _transcriptionController.add(TranscriptionResult(
          text: result,
          detectedLanguage: language?.code ?? 'en',
        ));
      } else {
        print('Error: Failed to save recording (path is null)');
        throw Exception('Failed to save recording');
      }
    } catch (e) {
      print('Error stopping recording or transcribing: $e');
      _transcriptionController.addError(e);
    }
  }
  
  Future<void> _stopWebRecordingAndTranscribe([Language? language]) async {
    if (!kIsWeb || !_isRecording || _webMediaRecorder == null) {
      print('Cannot stop web recording: Not recording or MediaRecorder is null');
      return;
    }
    
    try {
      print('Stopping web audio recording...');
      final completer = Completer<void>();
      
      // Handle the 'stop' event to process the collected audio
      _webMediaRecorder.addEventListener('stop', (event) async {
        try {
          if (_audioChunks.isEmpty) {
            throw Exception('No audio data recorded');
          }
          
          print('Number of audio chunks: ${_audioChunks.length}');
          
          // Create blob - handle platform-specific differences
          dynamic blob;
          try {
            // For web platforms
            blob = html.Blob(_audioChunks, 'audio/webm;codecs=opus');
            print('Created final blob of size: ${blob.size} bytes');
          } catch (e) {
            print('Error creating blob (this is normal in debug/non-web mode): $e');
            // For non-web platforms in debug mode, create a fake blob
            completer.complete();
            return;
          }
          
          // Send the audio data to the server for transcription
          await _transcribeWebAudio(blob, language);
        } catch (e) {
          print('Error processing web audio: $e');
          _transcriptionController.addError(e);
        } finally {
          completer.complete();
        }
      });
      
      // Stop the recording
      _webMediaRecorder.stop();
      _isRecording = false;
      
      // Release the microphone
      await _stopAllWebTracks();
      
      // Wait for processing to complete
      await completer.future;
    } catch (e) {
      print('Error stopping web recording: $e');
      _transcriptionController.addError(e);
    } finally {
      _webMediaRecorder = null;
      _audioChunks = [];
    }
  }
  
  Future<void> _transcribeWebAudio(html.Blob audioBlob, Language? language) async {
    try {
      print('Preparing to transcribe web audio...');
      print('Audio blob size: ${audioBlob.size} bytes');
      
      // Create form data for the file upload
      final formData = html.FormData();
      formData.appendBlob('file', audioBlob, 'recording.webm');
      
      // Build the URL with language parameter if provided
      final url = language != null 
          ? '${_apiService.baseUrl}/transcribe/realtime/?language=${language.code}'
          : '${_apiService.baseUrl}/transcribe/realtime/';
      
      print('Sending transcription request to: $url');
      
      // Create XMLHttpRequest
      final request = html.HttpRequest();
      request.open('POST', url);
      request.timeout = 30000; // 30 second timeout
      
      final completer = Completer<void>();
      
      // Handle response
      request.onLoad.listen((event) {
        if (request.status == 200) {
          try {
            // Use dart:convert instead of window.JSON
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
      
      // Handle errors
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
      print('Error during web transcription: $e');
      _transcriptionController.addError(e);
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
    if (kIsWeb) {
      _stopAllWebTracks();
    }
    _transcriptionController.close();
  }
} 