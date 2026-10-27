import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/phone.dart';
import '../../data/api/api_exception.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/auth_controller.dart';
import '../../state/providers.dart';
import '../../ui/error_text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../auth/login_screen.dart';
import '../auth/otp_screen.dart' show otpLength;

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _code = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).sendDeleteOtp();
      if (mounted) setState(() => _sent = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    if (_code.text.length != otpLength) {
      setState(() => _error = l.otpInvalid);
      return;
    }
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteConfirmTitle),
        content: Text(l.deleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.keep),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.deleteAccount),
          ),
        ],
      ),
    );
    if (sure != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).deleteAccount(_code.text);
      ref.read(authControllerProvider.notifier).accountDeleted();
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
    final phone = ref.watch(authControllerProvider).user?.phone;
    return Scaffold(
      appBar: AppBar(title: Text(l.deleteAccount)),
      body: ListView(
        padding: CnSpace.page,
        children: [
          Text(l.deleteAccountTitle, style: t.titleLarge),
          const SizedBox(height: CnSpace.md),
          Text(l.deleteAccountExplain, style: t.bodyLarge),
          const SizedBox(height: CnSpace.md),
          Text(l.deleteAccountUpcoming, style: t.bodyMedium),
          const SizedBox(height: CnSpace.xl),
          if (!_sent)
            CnButton(
              label: l.sendCode,
              kind: CnButtonKind.secondary,
              onPressed: _sendCode,
              loading: _busy,
            )
          else ...[
            Text(l.otpSentTo(maskPhone(phone)), style: t.bodyMedium),
            const SizedBox(height: CnSpace.md),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: otpLength,
              inputFormatters: const [DigitsFormatter(otpLength)],
              style: t.headlineMedium?.copyWith(letterSpacing: 10),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                labelText: l.otpLabel,
                counterText: '',
              ),
            ),
            const SizedBox(height: CnSpace.lg),
            CnButton(
              label: l.deleteMyAccount,
              kind: CnButtonKind.danger,
              onPressed: _delete,
              loading: _busy,
            ),
            CnButton(
              label: l.resendCode,
              kind: CnButtonKind.text,
              onPressed: _busy ? null : _sendCode,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: CnSpace.lg),
            CnBanner(message: _error!, tone: Tone.danger),
          ],
        ],
      ),
    );
  }
}
