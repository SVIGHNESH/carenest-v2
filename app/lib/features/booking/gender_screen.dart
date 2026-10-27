import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/ist.dart';
import '../../data/models/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/booking_draft.dart';
import '../../state/providers.dart';
import '../../ui/async_body.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'flow_widgets.dart';

/// Step 4: male or female nurse, only for genders with a free nurse.
class GenderScreen extends ConsumerStatefulWidget {
  const GenderScreen({super.key});

  @override
  ConsumerState<GenderScreen> createState() => _GenderScreenState();
}

class _GenderScreenState extends ConsumerState<GenderScreen> {
  String? _gender;

  @override
  void initState() {
    super.initState();
    _gender = ref.read(bookingDraftProvider).gender;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final draft = ref.watch(bookingDraftProvider);
    final key = (
      serviceId: draft.service!.id,
      date: isoDate(draft.day!),
      hour: draft.hour!,
      hours: draft.hours!,
    );
    final avail = ref.watch(genderAvailabilityProvider(key));
    final when = whenLabel(
      DateTime(draft.day!.year, draft.day!.month, draft.day!.day, draft.hour!),
    );

    bool ok(GenderAvailability a, String g) => g == 'male' ? a.male : a.female;
    final canContinue =
        avail.asData != null &&
        _gender != null &&
        ok(avail.asData!.value, _gender!);

    return FlowScaffold(
      step: 4,
      title: l.stepNurseTitle,
      bottom: BottomActionBar(
        child: CnButton(
          label: l.continueLabel,
          onPressed: canContinue
              ? () {
                  ref.read(bookingDraftProvider.notifier).setGender(_gender!);
                  context.push('/book/details');
                }
              : null,
        ),
      ),
      body: AsyncBody<GenderAvailability>(
        value: avail,
        onRefresh: () async => ref.invalidate(genderAvailabilityProvider),
        builder: (context, a) {
          final missing = [
            if (!a.female) l.femaleNurse,
            if (!a.male) l.maleNurse,
          ];
          return ListView(
            padding: CnSpace.page,
            children: [
              const FlowSummary(showHours: true),
              const SizedBox(height: CnSpace.xl),
              Semantics(
                header: true,
                child: Text(l.whoWouldYouPrefer, style: t.titleLarge),
              ),
              const SizedBox(height: CnSpace.lg),
              _GenderTile(
                gender: 'female',
                available: a.female,
                selected: _gender == 'female',
                onTap: () => setState(() => _gender = 'female'),
              ),
              const SizedBox(height: CnSpace.sm),
              _GenderTile(
                gender: 'male',
                available: a.male,
                selected: _gender == 'male',
                onTap: () => setState(() => _gender = 'male'),
              ),
              const SizedBox(height: CnSpace.lg),
              if (missing.isNotEmpty) ...[
                CnBanner(
                  message: missing.length == 2
                      ? l.noNurseFreeBoth(when)
                      : l.noNurseFreeFor(missing.first, when),
                  tone: Tone.warning,
                  action: CnButton(
                    label: l.changeDateOrTime,
                    kind: CnButtonKind.secondary,
                    expand: false,
                    onPressed: () => backToWhen(context),
                  ),
                ),
                const SizedBox(height: CnSpace.lg),
              ],
              Text(l.nurseAssignedNote, style: t.bodySmall),
            ],
          );
        },
      ),
    );
  }
}

class _GenderTile extends StatelessWidget {
  const _GenderTile({
    required this.gender,
    required this.available,
    required this.selected,
    required this.onTap,
  });
  final String gender;
  final bool available;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.cn;
    final isFemale = gender == 'female';
    return SelectTile(
      title: isFemale ? l.femaleNurse : l.maleNurse,
      subtitle: available ? l.availableForYourTime : l.notAvailableForThisTime,
      disabled: !available,
      selected: selected && available,
      onTap: onTap,
      leading: ExcludeSemantics(
        child: CircleAvatar(
          radius: 20,
          backgroundColor: available ? c.accentSoft : c.border,
          child: Text(
            isFemale ? 'F' : 'M',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: available ? c.accentText : c.muted,
            ),
          ),
        ),
      ),
    );
  }
}
