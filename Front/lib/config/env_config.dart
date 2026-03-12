/// Configuration par environnement (dev / staging / prod).
/// Utilisation: flutter run --dart-define=ENV=prod
/// Par défaut: dev
class EnvConfig {
  static const String env = String.fromEnvironment(
    'ENV',
    defaultValue: 'dev',
  );

  static bool get isDev => env == 'dev';
  static bool get isStaging => env == 'staging';
  static bool get isProd => env == 'prod';
}
