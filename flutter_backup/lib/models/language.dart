enum Language {
  english('en', 'English'),
  hindi('hi', 'Hindi'),
  tamil('ta', 'Tamil'),
  malayalam('ml', 'Malayalam'),
  bengali('bn', 'Bengali'),
  marathi('mr', 'Marathi'),
  urdu('ur', 'Urdu'),
  nepali('ne', 'Nepali'),
  sinhala('si', 'Sinhala');

  final String code;
  final String displayName;

  const Language(this.code, this.displayName);

  static Language? fromCode(String code) {
    return Language.values.firstWhere(
      (lang) => lang.code == code,
      orElse: () => Language.english,
    );
  }
} 