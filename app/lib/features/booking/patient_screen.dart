import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/auth_controller.dart';
import '../../state/booking_draft.dart';
import '../../state/providers.dart';
import '../../ui/async_body.dart';
import '../../ui/status.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'flow_widgets.dart';

/// Step 1: who is the visit for.
class PatientScreen extends ConsumerStatefulWidget {
  const PatientScreen({super.key});

  @override
  ConsumerState<PatientScreen> createState() => _PatientScreenState();
}

class _PatientScreenState extends ConsumerState<PatientScreen> {
  /// null = myself.
  int? _memberId;

  @override
  void initState() {
    super.initState();
    _memberId = ref.read(bookingDraftProvider).member?.id;
  }

  Future<void> _addMember() async {
    final created = await context.push<FamilyMember>('/profile/family/edit');
    if (created != null && mounted) {
      ref.invalidate(familyProvider);
      setState(() => _memberId = created.id);
    }
  }

  void _continue(List<FamilyMember> members) {
    final user = ref.read(authControllerProvider).user;
    final draftCtl = ref.read(bookingDraftProvider.notifier);
    final fallbackPhone = user?.phone ?? '';
    final member = members.where((m) => m.id == _memberId).firstOrNull;
    if (member == null) {
      draftCtl.setPatientSelf(name: user?.name ?? '', phone: fallbackPhone);
    } else {
      draftCtl.setPatientMember(member, fallbackPhone: fallbackPhone);
    }
    context.push('/book/when');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final user = ref.watch(authControllerProvider).user;
    final family = ref.watch(familyProvider);
    final members = family.asData?.value ?? const <FamilyMember>[];

    return FlowScaffold(
      step: 1,
      title: l.stepPatientTitle,
      bottom: BottomActionBar(
        child: CnButton(
          label: l.continueLabel,
          onPressed: family.hasValue ? () => _continue(members) : null,
        ),
      ),
      body: AsyncBody<List<FamilyMember>>(
        value: family,
        onRefresh: () async {
          ref.invalidate(familyProvider);
          await ref
              .read(familyProvider.future)
              .catchError((_) => <FamilyMember>[]);
        },
        builder: (context, list) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: CnSpace.page,
          children: [
            Semantics(
              header: true,
              child: Text(
                l.whoIsVisitFor,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: CnSpace.lg),
            SelectTile(
              title: l.myself,
              subtitle: user?.name,
              leading: InitialsAvatar(name: user?.name ?? '', size: 40),
              selected: _memberId == null,
              onTap: () => setState(() => _memberId = null),
            ),
            for (final m in list) ...[
              const SizedBox(height: CnSpace.sm),
              SelectTile(
                title: m.name,
                subtitle: '${m.relation}, ${m.age}, ${sexLabel(l, m.sex)}',
                leading: InitialsAvatar(name: m.name, size: 40),
                selected: _memberId == m.id,
                onTap: () => setState(() => _memberId = m.id),
              ),
            ],
            const SizedBox(height: CnSpace.sm),
            CnButton(
              label: l.addFamilyMemberPlus,
              icon: Icons.add,
              kind: CnButtonKind.secondary,
              onPressed: _addMember,
            ),
          ],
        ),
      ),
    );
  }
}
