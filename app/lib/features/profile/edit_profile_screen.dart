import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/phone.dart';
import '../../data/api/api_exception.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/auth_controller.dart';
import '../../state/providers.dart';
import '../../ui/error_text.dart';
import '../../ui/widgets.dart';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = ref.read(authControllerProvider).user;
    _name = TextEditingController(text: u?.name ?? '');
    _email = TextEditingController(text: u?.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final u = await ref
          .read(profileRepositoryProvider)
          .updateMe(name: _name.text.trim(), email: _email.text.trim());
      ref.read(authControllerProvider.notifier).updateUser(u);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).profileSaved)),
        );
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final user = ref.watch(authControllerProvider).user;
    return Scaffold(
      appBar: AppBar(title: Text(l.editProfile)),
      bottomNavigationBar: BottomActionBar(
        child: CnButton(label: l.save, onPressed: _save, loading: _busy),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: InitialsAvatar(
                name: _name.text.isEmpty ? (user?.name ?? '') : _name.text,
                size: 80,
              ),
            ),
            const SizedBox(height: 24),
            CnTextField(
              controller: _name,
              label: l.fullName,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l.nameRequired : null,
            ),
            const SizedBox(height: 16),
            CnTextField(
              controller: TextEditingController(
                text: displayPhone(user?.phone),
              ),
              label: l.phoneLabel,
              readOnly: true,
              helper: l.phoneCannotChange,
            ),
            const SizedBox(height: 16),
            CnTextField(
              controller: _email,
              label: l.email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              validator: (v) =>
                  (v == null || v.trim().isEmpty || _emailRe.hasMatch(v.trim()))
                  ? null
                  : l.emailInvalid,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              CnBanner(message: _error!, tone: Tone.danger),
            ],
          ],
        ),
      ),
    );
  }
}
