import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resumer_app/services/secure_api_storage.dart';

void main() {
  const storage = FlutterSecureStorage();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('initializes missing credentials once and preserves existing values',
      () async {
    final first = SecureApiStorage(
      storage: storage,
      bundledApiKey: 'new-regenerated-test-key',
      bundledHost: 'jsearch.p.rapidapi.com',
    );

    final initialized = await first.initializeIfMissing();
    expect(initialized.apiKey, 'new-regenerated-test-key');
    expect(initialized.host, 'jsearch.p.rapidapi.com');

    final second = SecureApiStorage(
      storage: storage,
      bundledApiKey: 'must-not-overwrite-existing',
      bundledHost: 'must-not-overwrite-host',
    );
    final reread = await second.initializeIfMissing();

    expect(reread.apiKey, 'new-regenerated-test-key');
    expect(reread.host, 'jsearch.p.rapidapi.com');
  });

  test('does not persist the placeholder as a credential', () async {
    final service = SecureApiStorage(
      storage: storage,
      bundledApiKey: 'USE_THE_NEW_REGENERATED_RAPIDAPI_KEY_HERE',
    );

    await expectLater(
      service.initializeIfMissing(),
      throwsA(isA<ApiConfigurationException>()),
    );
    expect(
      await storage.read(key: SecureApiStorage.rapidApiKeyStorageKey),
      isNull,
    );
  });
}
