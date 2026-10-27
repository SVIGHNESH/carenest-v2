import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:sms_autofill/sms_autofill.dart';

/// Reads the login code from an incoming SMS (Android SMS Retriever).
abstract class OtpAutofill {
  /// Starts listening; [onCode] gets the digits found in the SMS.
  Future<void> start(void Function(String code) onCode);
  Future<void> stop();
}

class SmsOtpAutofill implements OtpAutofill {
  StreamSubscription<String>? _sub;
  final _api = SmsAutoFill();

  bool get _supported => !kIsWeb && Platform.isAndroid;

  @override
  Future<void> start(void Function(String code) onCode) async {
    if (!_supported) return;
    try {
      await _api.listenForCode();
      _sub = _api.code.listen((c) {
        final digits = RegExp(r'\d{4,8}').firstMatch(c)?.group(0);
        if (digits != null) onCode(digits);
      });
    } catch (_) {
      // Autofill is a convenience; typing still works.
    }
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    if (!_supported) return;
    try {
      await _api.unregisterListener();
    } catch (_) {}
  }
}

class NoOtpAutofill implements OtpAutofill {
  const NoOtpAutofill();
  @override
  Future<void> start(void Function(String code) onCode) async {}
  @override
  Future<void> stop() async {}
}
