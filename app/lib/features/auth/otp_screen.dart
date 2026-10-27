import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/phone.dart';
import '../../data/api/api_exception.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/otp_autofill.dart';
import '../../state/auth_controller.dart';
import '../../state/providers.dart';
import '../../ui/error_text.dart';
import '../../ui/widgets.dart';
import 'login_screen.dart';

const otpLength = 6;
const resendSeconds = 60;

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone});

  /// E.164 phone, e.g. +919876543210.
  final String phone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  Timer? _timer;
  int _left = resendSeconds;
  bool _busy = false;
  bool _resending = false;
  String? _error;
  late final OtpAutofill _autofill;

  @override
  void initState() {
    super.initState();
    _startCountdown(resendSeconds);
    _autofill = ref.read(otpAutofillProvider);
    _autofill.start((c) {
      if (!mounted) return;
      _code.text = c.length > otpLength ? c.substring(0, otpLength) : c;
      if (_code.text.length == otpLength) _verify();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autofill.stop();
    _code.dispose();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _left = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left <= 1) {
        t.cancel();
        setState(() => _left = 0);
      } else {
        setState(() => _left--);
      }
    });
  }

  Future<void> _verify() async {
    final l = AppLocalizations.of(context);
    if (_code.text.length != otpLength) {
      setState(() => _error = l.otpInvalid);
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final out = await ref
          .read(authRepositoryProvider)
          .verifyOtp(widget.phone, _code.text);
      if (!mounted) return;
      if (out.needsSignup && out.signupTicket != null) {
        context.pushReplacement('/tell-us', extra: out.signupTicket);
      } else if (out.token != null) {
        ref.read(authControllerProvider.notifier).signedIn(out.token!.user);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendOtp(widget.phone);
      _code.clear();
      if (mounted) _startCountdown(resendSeconds);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = errorMessage(context, e));
      if (e.kind == ApiErrorKind.rateLimited && e.retryAfterSeconds != null) {
        _startCountdown(e.retryAfterSeconds!.clamp(1, 900));
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  String _clock(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.verifyTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            Semantics(
              header: true,
              child: Text(l.otpTitle, style: t.headlineMedium),
            ),
            const SizedBox(height: 8),
            Text(l.otpSentTo(maskPhone(widget.phone)), style: t.bodyLarge),
            Align(
              alignment: Alignment.centerLeft,
              child: CnButton(
                label: l.changeNumber,
                kind: CnButtonKind.text,
                expand: false,
                onPressed: () => context.pop(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: otpLength,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: const [DigitsFormatter(otpLength)],
              style: t.headlineMedium?.copyWith(letterSpacing: 10),
              onChanged: (v) {
                if (_error != null) setState(() => _error = null);
                if (v.length == otpLength) _verify();
              },
              decoration: InputDecoration(
                labelText: l.otpLabel,
                counterText: '',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 20),
            CnButton(label: l.verify, onPressed: _verify, loading: _busy),
            const SizedBox(height: 16),
            Center(
              child: _left > 0
                  ? Semantics(
                      liveRegion: false,
                      child: Text(
                        l.resendIn(_clock(_left)),
                        style: t.bodyMedium?.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    )
                  : CnButton(
                      label: l.resendCode,
                      kind: CnButtonKind.secondary,
                      expand: false,
                      loading: _resending,
                      onPressed: _resend,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
