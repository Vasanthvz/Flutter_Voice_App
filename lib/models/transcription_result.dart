class TranscriptionResult {
  final String text;
  final String detectedLanguage;

  TranscriptionResult({
    required this.text,
    required this.detectedLanguage,
  });

  factory TranscriptionResult.fromJson(Map<String, dynamic> json) {
    return TranscriptionResult(
      text: json['text'] as String,
      detectedLanguage: json['detected_language'] as String? ?? 'en',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'detected_language': detectedLanguage,
    };
  }
} 