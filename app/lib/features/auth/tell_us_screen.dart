import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_exception.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/auth_controller.dart';
import '../../state/providers.dart';
import '../../ui/error_text.dart';
import '../../ui/widgets.dart';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Shown once, to new users, after their number is verified.
class TellUsScreen extends ConsumerStatefulWidget {
  const TellUsScreen({super.key, required this.ticket});
  final String ticket;

  @override
  ConsumerState<TellUsScreen> createState() => _TellUsScreenState();
}

class _TellUsScreenState extends ConsumerState<TellUsScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .completeSignup(
            ticket: widget.ticket,
            name: _name.text.trim(),
            email: _email.text.trim(),
          );
      if (mounted) ref.read(authControllerProvider.notifier).signedIn(user);
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l.tellUsTitle),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              Text(l.tellUsSubtitle, style: t.bodyLarge),
              const SizedBox(height: 24),
              CnTextField(
                controller: _name,
                label: l.fullName,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                autofocus: true,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l.nameRequired : null,
              ),
              const SizedBox(height: 16),
              CnTextField(
                controller: _email,
                label: l.emailOptional,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                validator: (v) =>
                    (v == null ||
                        v.trim().isEmpty ||
                        _emailRe.hasMatch(v.trim()))
                    ? null
                    : l.emailInvalid,
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                CnBanner(message: _error!, tone: Tone.danger),
              ],
              const SizedBox(height: 24),
              CnButton(label: l.getStarted, onPressed: _submit, loading: _busy),
            ],
          ),
        ),
      ),
    );
  }
}
