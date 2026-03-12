class Languages {
  static const List<Map<String, String>> all = [
    {'name': 'French', 'code': 'fr', 'nativeName': 'Français'},
    {'name': 'English', 'code': 'en', 'nativeName': 'English'},
    {'name': 'Arabic', 'code': 'ar', 'nativeName': 'العربية'},
    {'name': 'Spanish', 'code': 'es', 'nativeName': 'Español'},
    {'name': 'German', 'code': 'de', 'nativeName': 'Deutsch'},
    {'name': 'Italian', 'code': 'it', 'nativeName': 'Italiano'},
    {'name': 'Portuguese', 'code': 'pt', 'nativeName': 'Português'},
    {'name': 'Russian', 'code': 'ru', 'nativeName': 'Русский'},
    {'name': 'Chinese (Mandarin)', 'code': 'zh', 'nativeName': '中文'},
    {'name': 'Japanese', 'code': 'ja', 'nativeName': '日本語'},
    {'name': 'Korean', 'code': 'ko', 'nativeName': '한국어'},
    {'name': 'Hindi', 'code': 'hi', 'nativeName': 'हिन्दी'},
    {'name': 'Turkish', 'code': 'tr', 'nativeName': 'Türkçe'},
    {'name': 'Dutch', 'code': 'nl', 'nativeName': 'Nederlands'},
    {'name': 'Polish', 'code': 'pl', 'nativeName': 'Polski'},
    {'name': 'Swedish', 'code': 'sv', 'nativeName': 'Svenska'},
    {'name': 'Norwegian', 'code': 'no', 'nativeName': 'Norsk'},
    {'name': 'Danish', 'code': 'da', 'nativeName': 'Dansk'},
    {'name': 'Finnish', 'code': 'fi', 'nativeName': 'Suomi'},
    {'name': 'Greek', 'code': 'el', 'nativeName': 'Ελληνικά'},
    {'name': 'Hebrew', 'code': 'he', 'nativeName': 'עברית'},
    {'name': 'Czech', 'code': 'cs', 'nativeName': 'Čeština'},
    {'name': 'Romanian', 'code': 'ro', 'nativeName': 'Română'},
    {'name': 'Hungarian', 'code': 'hu', 'nativeName': 'Magyar'},
    {'name': 'Thai', 'code': 'th', 'nativeName': 'ไทย'},
    {'name': 'Vietnamese', 'code': 'vi', 'nativeName': 'Tiếng Việt'},
    {'name': 'Indonesian', 'code': 'id', 'nativeName': 'Bahasa Indonesia'},
    {'name': 'Malay', 'code': 'ms', 'nativeName': 'Bahasa Melayu'},
    {'name': 'Tagalog', 'code': 'tl', 'nativeName': 'Tagalog'},
    {'name': 'Swahili', 'code': 'sw', 'nativeName': 'Kiswahili'},
    {'name': 'Ukrainian', 'code': 'uk', 'nativeName': 'Українська'},
    {'name': 'Bulgarian', 'code': 'bg', 'nativeName': 'Български'},
    {'name': 'Serbian', 'code': 'sr', 'nativeName': 'Српски'},
    {'name': 'Croatian', 'code': 'hr', 'nativeName': 'Hrvatski'},
    {'name': 'Slovak', 'code': 'sk', 'nativeName': 'Slovenčina'},
    {'name': 'Slovenian', 'code': 'sl', 'nativeName': 'Slovenščina'},
    {'name': 'Lithuanian', 'code': 'lt', 'nativeName': 'Lietuvių'},
    {'name': 'Latvian', 'code': 'lv', 'nativeName': 'Latviešu'},
    {'name': 'Estonian', 'code': 'et', 'nativeName': 'Eesti'},
    {'name': 'Persian', 'code': 'fa', 'nativeName': 'فارسی'},
    {'name': 'Urdu', 'code': 'ur', 'nativeName': 'اردو'},
    {'name': 'Bengali', 'code': 'bn', 'nativeName': 'বাংলা'},
    {'name': 'Tamil', 'code': 'ta', 'nativeName': 'தமிழ்'},
    {'name': 'Telugu', 'code': 'te', 'nativeName': 'తెలుగు'},
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
