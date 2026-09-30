import 'package:flutter_test/flutter_test.dart';
import 'package:resumer_app/models/models.dart';
import 'package:resumer_app/services/profile_autofill_service.dart';

const _user = User(
  name: 'Priya Sharma',
  email: 'priya@example.com',
  headline: 'Aspiring product engineer',
  phone: '+91 98765 43210',
  location: 'Bengaluru, India',
);

void main() {
  test('embeds the profile payload and field heuristics', () {
    final script = ProfileAutofillService().buildScript(
      user: _user,
      autoSubmit: false,
    );

    expect(script, contains('RESUMER_AUTOFILL:'));
    expect(script, contains('"email":"priya@example.com"'));
    expect(script, contains('"name":"Priya Sharma"'));
    expect(script, contains('"phone":"+91 98765 43210"'));
    // Field detection covers type, autocomplete, placeholders and labels.
    expect(script, contains("el.getAttribute('autocomplete')"));
    expect(script, contains('e-?mail'));
    expect(script, contains('phone|mobile|tel'));
    // Passwords are never filled.
    expect(script, contains("t === 'password'"));
  });

  test('auto-submit flag is inlined as a JS boolean literal', () {
    final service = ProfileAutofillService();
    expect(service.buildScript(user: _user, autoSubmit: true),
        contains('if (true && filled > 0)'));
    expect(service.buildScript(user: _user, autoSubmit: false),
        contains('if (false && filled > 0)'));
  });

  test('script is idempotent per page via a run-once guard', () {
    final script = ProfileAutofillService().buildScript(
      user: _user,
      autoSubmit: true,
    );
    expect(script, contains('__resumerAutofillDone'));
  });
}
