/// OAuth Configuration for Google and Facebook
///
/// IMPORTANT:
/// The Google Web Client ID (serverClientId) is REQUIRED for mobile OAuth.
/// This must match your backend GOOGLE_CLIENT_ID (.env file).
///
/// Get it from:
/// https://console.cloud.google.com
/// Project → Credentials → OAuth 2.0 Client IDs
/// Use the "Web application" client ID
///
/// You can also pass it via:
/// flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=your-id.apps.googleusercontent.com

class OAuthConfig {
  /// Google Web Client ID (Web Application from Google Cloud Console)
  /// Must match backend GOOGLE_CLIENT_ID
  static const String googleServerClientId =
      '488329502891-h71m67eo5hmk36q81ds4kkkd6kc3c0ot.apps.googleusercontent.com';

  /// Google configuration validation
  static bool get isGoogleConfigured => googleServerClientId.isNotEmpty;

  /// Debug helper
  static void printConfig() {
    print('\n🔐 ═══════════════════════════════════════════════════════');
    print('   OAuth Configuration Status');
    print('═══════════════════════════════════════════════════════');

    print(
      '   Google Server Client ID: '
      '${isGoogleConfigured ? "✓ Configured" : "✗ MISSING"}',
    );

    if (!isGoogleConfigured) {
      print('   ⚠️ Google login will FAIL!');
    }

    print('═══════════════════════════════════════════════════════\n');
  }
}
