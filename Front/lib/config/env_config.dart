/// Environment configuration (dev / staging / prod).
/// Usage: flutter run --dart-define=ENV=prod
/// Default: dev
class EnvConfig {
  static const String env = String.fromEnvironment(
    'ENV',
    defaultValue: 'dev',
  );

  static bool get isDev => env == 'dev';
  static bool get isStaging => env == 'staging';
  static bool get isProd => env == 'prod';
}
