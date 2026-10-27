import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/phone.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/providers.dart';
import '../../ui/async_body.dart';
import '../../ui/error_text.dart';
import '../../ui/status.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../booking/details_screen.dart';

class FamilyListScreen extends ConsumerWidget {
  const FamilyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.familyMembers)),
      bottomNavigationBar: BottomActionBar(
        child: CnButton(
          label: l.addFamilyMemberPlus,
          icon: Icons.add,
          onPressed: () async {
            await context.push<FamilyMember>('/profile/family/edit');
            ref.invalidate(familyProvider);
          },
        ),
      ),
      body: AsyncBody<List<FamilyMember>>(
        value: ref.watch(familyProvider),
        onRefresh: () async {
          ref.invalidate(familyProvider);
          await ref
              .read(familyProvider.future)
              .catchError((_) => <FamilyMember>[]);
        },
        isEmpty: (list) => list.isEmpty,
        emptyIcon: Icons.groups_outlined,
        emptyTitle: l.noFamily,
        emptyBody: l.noFamilyBody,
        builder: (context, list) => ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: CnSpace.page,
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: CnSpace.sm),
          itemBuilder: (_, i) {
            final m = list[i];
            return CnCard(
              onTap: () async {
                await context.push<FamilyMember>(
                  '/profile/family/edit',
                  extra: m,
                );
                ref.invalidate(familyProvider);
              },
              semanticLabel:
                  '${m.name}, ${m.relation}, ${m.age}, ${sexLabel(l, m.sex)}',
              child: Row(
                children: [
                  InitialsAvatar(name: m.name, size: 44),
                  const SizedBox(width: CnSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.name,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontSize: 15),
                        ),
                        Text(
                          '${m.relation}, ${m.age}, ${sexLabel(l, m.sex)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: context.cn.subtle),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Add or edit a family member. Pops with the saved member.
class FamilyFormScreen extends ConsumerStatefulWidget {
  const FamilyFormScreen({super.key, this.member});
  final FamilyMember? member;

  @override
  ConsumerState<FamilyFormScreen> createState() => _FamilyFormScreenState();
}

class _FamilyFormScreenState extends ConsumerState<FamilyFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _relation;
  late final TextEditingController _age;
  late final TextEditingController _phone;
  late final TextEditingController _notes;
  String? _sex;
  bool _sexMissing = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    _name = TextEditingController(text: m?.name ?? '');
    _relation = TextEditingController(text: m?.relation ?? '');
    _age = TextEditingController(text: m?.age.toString() ?? '');
    _phone = TextEditingController(
      text: parseIndianMobile(m?.contactPhone ?? '') ?? '',
    );
    _notes = TextEditingController(text: m?.medicalNotes ?? '');
    _sex = m?.sex;
  }

  @override
  void dispose() {
    for (final c in [_name, _relation, _age, _phone, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final valid = _form.currentState!.validate();
    setState(() => _sexMissing = _sex == null);
    if (!valid || _sex == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final input = FamilyInput(
      name: _name.text.trim(),
      relation: _relation.text.trim(),
      age: int.parse(_age.text.trim()),
      sex: _sex!,
      contactPhone: _phone.text.trim().isEmpty ? null : toE164(_phone.text),
      medicalNotes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    try {
      final repo = ref.read(profileRepositoryProvider);
      final saved = widget.member == null
          ? await repo.addFamily(input)
          : await repo.updateFamily(widget.member!.id, input);
      ref.invalidate(familyProvider);
      if (mounted) context.pop(saved);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteMemberTitle(widget.member!.name)),
        content: Text(l.deleteMemberBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.keep),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).deleteFamily(widget.member!.id);
      ref.invalidate(familyProvider);
      if (mounted) context.pop();
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
    final editing = widget.member != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? l.editFamilyMember : l.addFamilyMember),
      ),
      bottomNavigationBar: BottomActionBar(
        child: CnButton(
          label: editing ? l.save : l.addMember,
          onPressed: _save,
          loading: _busy,
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: CnSpace.page,
          children: [
            CnTextField(
              controller: _name,
              label: l.patientName,
              textCapitalization: TextCapitalization.words,
              autofocus: !editing,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l.nameRequired : null,
            ),
            const SizedBox(height: CnSpace.md),
            CnTextField(
              controller: _relation,
              label: l.relation,
              hint: l.relationHint,
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l.relationRequired : null,
            ),
            const SizedBox(height: CnSpace.md),
            CnTextField(
              controller: _age,
              label: l.patientAge,
              keyboardType: TextInputType.number,
              maxLength: 3,
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                return (n == null || n < 0 || n > 120) ? l.ageInvalid : null;
              },
            ),
            const SizedBox(height: CnSpace.md),
            Text(l.patientSex, style: t.labelMedium),
            const SizedBox(height: CnSpace.sm),
            SexChooser(
              value: _sex,
              onChanged: (v) => setState(() {
                _sex = v;
                _sexMissing = false;
              }),
            ),
            if (_sexMissing)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l.sexRequired,
                  style: t.bodySmall?.copyWith(color: context.cn.danger),
                ),
              ),
            const SizedBox(height: CnSpace.md),
            CnTextField(
              controller: _phone,
              label: l.contactPhoneOptional,
              prefixText: '+91  ',
              keyboardType: TextInputType.phone,
              maxLength: 14,
              validator: (v) =>
                  (v == null ||
                      v.trim().isEmpty ||
                      parseIndianMobile(v) != null)
                  ? null
                  : l.phoneInvalid,
            ),
            const SizedBox(height: CnSpace.md),
            CnTextField(
              controller: _notes,
              label: l.medicalNotes,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            if (_error != null) ...[
              const SizedBox(height: CnSpace.md),
              CnBanner(message: _error!, tone: Tone.danger),
            ],
            if (editing) ...[
              const SizedBox(height: CnSpace.xl),
              CnButton(
                label: l.deleteMember,
                kind: CnButtonKind.secondary,
                icon: Icons.delete_outline,
                onPressed: _busy ? null : _delete,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
