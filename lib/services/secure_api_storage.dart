import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The credentials needed for a RapidAPI request.
///
/// This value is deliberately kept inside the services layer. It must never be
/// rendered, logged, persisted outside secure storage, or attached to errors.
class RapidApiCredentials {
  const RapidApiCredentials({required this.apiKey, required this.host});

  final String apiKey;
  final String host;
}

abstract interface class ApiCredentialStore {
  Future<RapidApiCredentials> getCredentials();
}

class ApiConfigurationException implements Exception {
  const ApiConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Owns all persistent access to the JSearch RapidAPI credentials.
class SecureApiStorage implements ApiCredentialStore {
  SecureApiStorage({
    FlutterSecureStorage? storage,
    String? bundledApiKey,
    String? bundledHost,
  })  : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
            ),
        _bundledApiKey = bundledApiKey ?? _configuredApiKey,
        _bundledHost = bundledHost ?? _configuredHost;

  static final SecureApiStorage instance = SecureApiStorage();

  static const String rapidApiKeyStorageKey = 'rapidapi_key';
  static const String rapidApiHostStorageKey = 'rapidapi_host';

  // Production job searches use the authenticated backend proxy so this key
  // is never bundled into a public web or mobile client.
  static const String _configuredApiKey = String.fromEnvironment(
    'RAPIDAPI_KEY',
    defaultValue: '',
  );
  static const String _configuredHost = String.fromEnvironment(
    'RAPIDAPI_HOST',
    defaultValue: 'jsearch.p.rapidapi.com',
  );

  final FlutterSecureStorage _storage;
  final String _bundledApiKey;
  final String _bundledHost;

  Future<RapidApiCredentials>? _initialization;

  /// Initializes missing values exactly once per process. Existing secure
  /// values are read without being rewritten on each request.
  Future<RapidApiCredentials> initializeIfMissing() =>
      _initialization ??= _initializeIfMissing();

  @override
  Future<RapidApiCredentials> getCredentials() => initializeIfMissing();

  Future<RapidApiCredentials> _initializeIfMissing() async {
    var apiKey = (await _storage.read(key: rapidApiKeyStorageKey))?.trim();
    var host = (await _storage.read(key: rapidApiHostStorageKey))?.trim();

    if (apiKey == null || apiKey.isEmpty) {
      final bundledKey = _bundledApiKey.trim();
      if (bundledKey.isEmpty ||
          bundledKey == 'USE_THE_NEW_REGENERATED_RAPIDAPI_KEY_HERE') {
        throw const ApiConfigurationException(
          'RapidAPI is not configured for this app build.',
        );
      }
      await _storage.write(key: rapidApiKeyStorageKey, value: bundledKey);
      apiKey = bundledKey;
    }

    if (host == null || host.isEmpty) {
      final bundledHost = _bundledHost.trim();
      if (bundledHost.isEmpty) {
        throw const ApiConfigurationException(
          'The RapidAPI host is not configured for this app build.',
        );
      }
      await _storage.write(key: rapidApiHostStorageKey, value: bundledHost);
      host = bundledHost;
    }

    return RapidApiCredentials(apiKey: apiKey, host: host);
  }
}
