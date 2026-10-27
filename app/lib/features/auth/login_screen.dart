import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/phone.dart';
import '../../data/api/api_exception.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/providers.dart';
import '../../ui/error_text.dart';
import '../../ui/widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  String? _validate(String? v) {
    final l = AppLocalizations.of(context);
    if (v == null || v.trim().isEmpty) return l.phoneRequired;
    return parseIndianMobile(v) == null ? l.phoneInvalid : null;
  }

  Future<void> _send() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    final e164 = toE164(_phone.text)!;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).sendOtp(e164);
      if (mounted) context.push('/otp', extra: e164);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: BrandMark(size: 64),
              ),
              const SizedBox(height: 28),
              Semantics(
                header: true,
                child: Text(l.loginTitle, style: t.headlineMedium),
              ),
              const SizedBox(height: 8),
              Text(l.loginSubtitle, style: t.bodyLarge),
              const SizedBox(height: 32),
              CnTextField(
                controller: _phone,
                label: l.phoneLabel,
                prefixText: '+91  ',
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                maxLength: 14,
                autofocus: true,
                validator: _validate,
                errorText: _error,
                onSubmitted: (_) => _send(),
              ),
              const SizedBox(height: 20),
              CnButton(label: l.sendCode, onPressed: _send, loading: _busy),
              const SizedBox(height: 16),
              Text(
                l.loginHint,
                style: t.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Digits only, up to [max].
class DigitsFormatter extends TextInputFormatter {
  const DigitsFormatter(this.max);
  final int max;
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue old,
    TextEditingValue next,
  ) {
    final d = next.text.replaceAll(RegExp(r'\D'), '');
    final cut = d.length > max ? d.substring(0, max) : d;
    return TextEditingValue(
      text: cut,
      selection: TextSelection.collapsed(offset: cut.length),
    );
  }
}
