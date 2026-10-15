// DDE-Mart provider app — static config (original).

class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://admin.hometry.in/api/v1',
  );

  /// Audience checked against GET /app-config min_versions.
  static const audience = 'provider';

  static const appName = 'Hometry Provider';
}
