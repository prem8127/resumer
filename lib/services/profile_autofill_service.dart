import 'dart:convert';

import '../models/models.dart';

/// Builds the JavaScript injected into the in-app job-site browser.
///
/// The script:
///   1. Detects application-form fields by type, name, id, placeholder,
///      autocomplete and aria-label heuristics (works on plain HTML, React
///      and Vue forms via native value setters + input/change events).
///   2. Fills them with the user's profile data. Password fields are never
///      touched — the app deliberately does not store credentials; the user
///      types those once and the WebView session keeps them logged in.
///   3. When [autoSubmit] is on, clicks a genuine application submit button
///      after filling — guarded against search boxes, login and newsletter
///      forms so nothing unrelated gets submitted.
class ProfileAutofillService {
  static const resultMarker = 'RESUMER_AUTOFILL:';

  /// Builds the injection script for one page load.
  String buildScript({required User user, required bool autoSubmit}) {
    final payload = jsonEncode({
      'name': user.name.trim(),
      'email': user.email.trim(),
      'phone': user.phone.trim(),
      'location': user.location.trim(),
    });
    return '''
(function() {
  if (window.__resumerAutofillDone) return;
  window.__resumerAutofillDone = true;
  var DATA = $payload;

  function fieldSignature(el) {
    return [
      el.name, el.id, el.placeholder,
      el.getAttribute('autocomplete'),
      el.getAttribute('aria-label'),
      el.getAttribute('title'),
      el.className,
      el.labels && el.labels.length ? el.labels[0].textContent : ''
    ].filter(Boolean).join(' ').toLowerCase();
  }

  function classify(el) {
    var t = (el.getAttribute('type') || '').toLowerCase();
    if (t === 'email') return 'email';
    if (t === 'tel') return 'phone';
    if (t === 'password') return null;
    var sig = fieldSignature(el);
    if (!sig) return null;
    if (/e-?mail/.test(sig)) return 'email';
    if (/\\b(phone|mobile|tel|whatsapp)\\b/.test(sig)) return 'phone';
    if (/(location|city\\b|town\\b|address\\b)/.test(sig)) return 'location';
    if (/(full[- _]?name|\\bname\\b|your name|first[- _]?name|last[- _]?name|given[- _]?name|surname)/.test(sig)) {
      return 'name';
    }
    return null;
  }

  function visible(el) {
    var rect = el.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) return false;
    var style = window.getComputedStyle(el);
    return style.visibility !== 'hidden' && style.display !== 'none';
  }

  function setValue(el, value) {
    var proto = el instanceof HTMLTextAreaElement
        ? HTMLTextAreaElement.prototype
        : HTMLInputElement.prototype;
    var setter = Object.getOwnPropertyDescriptor(proto, 'value');
    if (setter && setter.set) {
      setter.set.call(el, value);
    } else {
      el.value = value;
    }
    el.dispatchEvent(new Event('input', {bubbles: true}));
    el.dispatchEvent(new Event('change', {bubbles: true}));
    el.dispatchEvent(new Event('blur', {bubbles: true}));
  }

  var filled = 0;
  var touchedForm = null;
  document.querySelectorAll('input:not([type=hidden]):not([type=checkbox]):not([type=radio]):not([type=file]), textarea')
      .forEach(function(el) {
        if (el.disabled || el.readOnly || el.value) return;
        if (!visible(el)) return;
        var kind = classify(el);
        if (!kind || !DATA[kind]) return;
        setValue(el, DATA[kind]);
        filled++;
        touchedForm = touchedForm || el.form || el.closest('form');
      });

  var submitted = false;
  var SUBMIT_RE = /(\\bapply(\\s+now)?\\b|submit application|send application|start application)/i;
  var GUARD_RE = /(search|sign[- ]?in|log[- ]?in|subscribe|newsletter|password|save|cancel|back\\b|upload|\\bsign[- ]?up\\b)/i;

  function buttonLabel(b) {
    return ((b.innerText || b.textContent || b.value || '') + ' ' +
            b.getAttribute('aria-label') + ' ' + b.className).trim();
  }

  if ($autoSubmit && filled > 0) {
    var candidates = [];
    document.querySelectorAll('button, input[type=submit], [role=button]')
        .forEach(function(b) {
          if (b.disabled || !visible(b)) return;
          var label = buttonLabel(b);
          if (!label) return;
          if (GUARD_RE.test(label)) return;
          if (SUBMIT_RE.test(label)) candidates.push(b);
        });
    var formButton = null;
    if (touchedForm) {
      formButton = touchedForm.querySelector('button[type=submit], input[type=submit]');
      if (formButton && (formButton.disabled || !visible(formButton))) {
        formButton = null;
      }
    }
    var target = formButton || (candidates.length === 1 ? candidates[0] : null);
    if (target) {
      submitted = true;
      setTimeout(function() { target.click(); }, 600);
    }
  }

  console.log('$resultMarker' + JSON.stringify({
    filled: filled,
    submitted: submitted,
    url: location.href.slice(0, 300)
  }));
})();
''';
  }
}
