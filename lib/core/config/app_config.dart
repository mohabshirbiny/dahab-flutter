/// Build-time configuration.
///
/// Point the app at a backend with
/// `flutter run -d chrome --dart-define=API_BASE_URL=https://api.example.com/api/v1`
/// (the same flag works for `flutter build web`). The default is the local
/// Laravel server started with `php artisan serve`.
abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8000/api/v1');

  /// Sent as `X-Device-Platform`; the backend hashes it with `X-Device-Id`.
  static const devicePlatform = 'web';

  static const requestTimeout = Duration(seconds: 30);
}
