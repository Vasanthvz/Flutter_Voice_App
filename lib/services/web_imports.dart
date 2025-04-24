// This file is an empty stub used for conditional imports
// It's imported on non-web platforms instead of dart:html

class Blob {
  final int size = 0;
  
  // Add constructor to accept arguments that will be ignored on non-web
  Blob([dynamic chunks, dynamic options]) {}
}

class BlobEvent {
  final Blob? data = null;
}

class MediaRecorder {
  MediaRecorder(dynamic stream, [dynamic options]);
  void addEventListener(String type, Function listener) {}
  void start(int timeslice) {}
  void stop() {}
}

class FormData {
  void appendBlob(String name, dynamic blob, String filename) {}
}

class HttpRequest {
  int status = 0;
  String statusText = '';
  String? responseText;
  void open(String method, String url) {}
  int timeout = 0;
  Stream<dynamic> get onLoad => const Stream.empty();
  Stream<dynamic> get onError => const Stream.empty();
  Stream<dynamic> get onTimeout => const Stream.empty();
  void send([dynamic data]) {}
}

// Mock Navigator class
class Navigator {
  MediaDevices? mediaDevices;
  
  Navigator() {
    mediaDevices = MediaDevices();
  }
}

// Mock MediaDevices class
class MediaDevices {
  Future<dynamic> getUserMedia(dynamic constraints) async {
    // Return a fake media stream on non-web platforms
    return null;
  }
}

// Mock window class
class Window {
  Navigator navigator = Navigator();
}

Window window = Window(); 