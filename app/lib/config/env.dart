/// Build-time configuration, set with `--dart-define=NAME=value`.
class Env {
  const Env._();

  /// Android emulator reaches the host machine at 10.0.2.2.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// Empty means "no Google key": the app uses fake places and a simulated map.
  static const mapsApiKey = String.fromEnvironment('MAPS_API_KEY');

  /// Placeholder until the client publishes the page.
  static const privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://example.com/privacy',
  );

  static bool get hasMapsKey => mapsApiKey.isNotEmpty;
}
