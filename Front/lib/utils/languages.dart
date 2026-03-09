class Languages {
  static const List<Map<String, String>> all = [
    {'name': 'Français', 'code': 'fr', 'nativeName': 'Français'},
    {'name': 'Anglais', 'code': 'en', 'nativeName': 'English'},
    {'name': 'Arabe', 'code': 'ar', 'nativeName': 'العربية'},
    {'name': 'Espagnol', 'code': 'es', 'nativeName': 'Español'},
    {'name': 'Allemand', 'code': 'de', 'nativeName': 'Deutsch'},
    {'name': 'Italien', 'code': 'it', 'nativeName': 'Italiano'},
    {'name': 'Portugais', 'code': 'pt', 'nativeName': 'Português'},
    {'name': 'Russe', 'code': 'ru', 'nativeName': 'Русский'},
    {'name': 'Chinois (Mandarin)', 'code': 'zh', 'nativeName': '中文'},
    {'name': 'Japonais', 'code': 'ja', 'nativeName': '日本語'},
    {'name': 'Coréen', 'code': 'ko', 'nativeName': '한국어'},
    {'name': 'Hindi', 'code': 'hi', 'nativeName': 'हिन्दी'},
    {'name': 'Turc', 'code': 'tr', 'nativeName': 'Türkçe'},
    {'name': 'Néerlandais', 'code': 'nl', 'nativeName': 'Nederlands'},
    {'name': 'Polonais', 'code': 'pl', 'nativeName': 'Polski'},
    {'name': 'Suédois', 'code': 'sv', 'nativeName': 'Svenska'},
    {'name': 'Norvégien', 'code': 'no', 'nativeName': 'Norsk'},
    {'name': 'Danois', 'code': 'da', 'nativeName': 'Dansk'},
    {'name': 'Finnois', 'code': 'fi', 'nativeName': 'Suomi'},
    {'name': 'Grec', 'code': 'el', 'nativeName': 'Ελληνικά'},
    {'name': 'Hébreu', 'code': 'he', 'nativeName': 'עברית'},
    {'name': 'Tchèque', 'code': 'cs', 'nativeName': 'Čeština'},
    {'name': 'Roumain', 'code': 'ro', 'nativeName': 'Română'},
    {'name': 'Hongrois', 'code': 'hu', 'nativeName': 'Magyar'},
    {'name': 'Thaï', 'code': 'th', 'nativeName': 'ไทย'},
    {'name': 'Vietnamien', 'code': 'vi', 'nativeName': 'Tiếng Việt'},
    {'name': 'Indonésien', 'code': 'id', 'nativeName': 'Bahasa Indonesia'},
    {'name': 'Malais', 'code': 'ms', 'nativeName': 'Bahasa Melayu'},
    {'name': 'Tagalog', 'code': 'tl', 'nativeName': 'Tagalog'},
    {'name': 'Swahili', 'code': 'sw', 'nativeName': 'Kiswahili'},
    {'name': 'Ukrainien', 'code': 'uk', 'nativeName': 'Українська'},
    {'name': 'Bulgare', 'code': 'bg', 'nativeName': 'Български'},
    {'name': 'Serbe', 'code': 'sr', 'nativeName': 'Српски'},
    {'name': 'Croate', 'code': 'hr', 'nativeName': 'Hrvatski'},
    {'name': 'Slovaque', 'code': 'sk', 'nativeName': 'Slovenčina'},
    {'name': 'Slovène', 'code': 'sl', 'nativeName': 'Slovenščina'},
    {'name': 'Lituanien', 'code': 'lt', 'nativeName': 'Lietuvių'},
    {'name': 'Letton', 'code': 'lv', 'nativeName': 'Latviešu'},
    {'name': 'Estonien', 'code': 'et', 'nativeName': 'Eesti'},
    {'name': 'Persan', 'code': 'fa', 'nativeName': 'فارسی'},
    {'name': 'Ourdou', 'code': 'ur', 'nativeName': 'اردو'},
    {'name': 'Bengali', 'code': 'bn', 'nativeName': 'বাংলা'},
    {'name': 'Tamoul', 'code': 'ta', 'nativeName': 'தமிழ்'},
    {'name': 'Télougou', 'code': 'te', 'nativeName': 'తెలుగు'},
    {'name': 'Marathi', 'code': 'mr', 'nativeName': 'मराठी'},
    {'name': 'Gujarati', 'code': 'gu', 'nativeName': 'ગુજરાતી'},
    {'name': 'Kannada', 'code': 'kn', 'nativeName': 'ಕನ್ನಡ'},
    {'name': 'Malayalam', 'code': 'ml', 'nativeName': 'മലയാളം'},
    {'name': 'Punjabi', 'code': 'pa', 'nativeName': 'ਪੰਜਾਬੀ'},
  ];

  static List<Map<String, String>> search(String query) {
    if (query.isEmpty) return all;
    final lowerQuery = query.toLowerCase();
    return all
        .where(
          (language) =>
              language['name']!.toLowerCase().contains(lowerQuery) ||
              language['nativeName']!.toLowerCase().contains(lowerQuery) ||
              language['code']!.toLowerCase().contains(lowerQuery),
        )
        .toList();
  }
}
