/// OAuth Configuration for Google and Facebook
///
/// IMPORTANT: The Google Web Client ID (serverClientId) is REQUIRED for mobile OAuth
/// This is the SAME Client ID used in your backend (.env GOOGLE_CLIENT_ID)
///
/// Get from Google Cloud Console: https://console.cloud.google.com
/// - Project → Credentials → OAuth 2.0 Client IDs
/// - Look for "Web application" type (format: xxxxx.apps.googleusercontent.com)
///
/// You can pass it via environment variable:
/// flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=your-id.apps.googleusercontent.com
///
/// Or replace the default value below.

class OAuthConfig {
  /// Google OAuth Server Client ID (Web Application from Google Cloud Console)
  /// This is CRITICAL for getting ID tokens in mobile apps
  /// Must match the GOOGLE_CLIENT_ID in Backend .env file
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    // Backend Web Client ID - Get this from Google Cloud Console
    defaultValue:
        '891015623935-f9dmcdek9blg8gusgetuu52bor903lv8.apps.googleusercontent.com',
  );

  /// Facebook App ID
  static const String facebookAppId = String.fromEnvironment(
    'FACEBOOK_APP_ID',
    defaultValue: '1234567890', // Replace with your Facebook App ID
  );

  /// Validate configuration
  static bool get isGoogleConfigured => googleServerClientId.isNotEmpty;
  static bool get isFacebookConfigured => facebookAppId.isNotEmpty;

  /// Debug helper - Call this in main.dart to verify setup
  static void printConfig() {
    print('\n🔐 ═══════════════════════════════════════════════════════');
    print('   OAuth Configuration Status');
    print('═══════════════════════════════════════════════════════');
    print(
      '   Google Server Client ID: ${isGoogleConfigured ? "✓ Configured" : "✗ MISSING (REQUIRED)"}',
    );
    if (!isGoogleConfigured) {
      print('   ⚠️  Google login will FAIL! Set via:');
      print(
        '       flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=your-id.apps.googleusercontent.com',
      );
    }
    print(
      '   Facebook App ID: ${isFacebookConfigured ? "✓ Configured" : "⚠️  Optional"}',
    );
    print('═══════════════════════════════════════════════════════\n');
  }
}
