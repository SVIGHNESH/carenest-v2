import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/phone.dart';
import '../../data/models/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/booking_draft.dart';
import '../../state/providers.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../map/map_picker_screen.dart';
import '../profile/address_form_screen.dart';
import 'flow_widgets.dart';

/// Step 5: patient details, contact phone and the visit address.
class DetailsScreen extends ConsumerStatefulWidget {
  const DetailsScreen({super.key});

  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends ConsumerState<DetailsScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _condition;
  late final TextEditingController _phone;
  String? _sex;
  Address? _address;
  bool _addressMissing = false;

  @override
  void initState() {
    super.initState();
    final d = ref.read(bookingDraftProvider);
    _name = TextEditingController(text: d.patientName);
    _age = TextEditingController(text: d.patientAge?.toString() ?? '');
    _condition = TextEditingController(text: d.condition);
    _phone = TextEditingController(
      text: parseIndianMobile(d.contactPhone) ?? '',
    );
    _sex = d.patientSex;
    _address = d.address;
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _condition.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickOnMap({required bool current}) async {
    final pending = await context.push<PendingLocation>(
      '/map',
      extra: MapPickerArgs(startWithCurrentLocation: current),
    );
    if (pending == null || !mounted) return;
    await context.push<Address>(
      '/address-details',
      extra: AddressFormArgs.forBooking(pending),
    );
    if (!mounted) return;
    setState(() {
      _address = ref.read(bookingDraftProvider).address;
      _addressMissing = false;
    });
  }

  void _continue() {
    final valid = _form.currentState!.validate();
    if (_address == null) setState(() => _addressMissing = true);
    if (!valid || _address == null) return;
    final ctl = ref.read(bookingDraftProvider.notifier);
    ctl.setPatientDetails(
      name: _name.text.trim(),
      age: int.tryParse(_age.text.trim()),
      sex: _sex,
      condition: _condition.text.trim(),
      phone: toE164(_phone.text)!,
    );
    ctl.selectAddress(_address!);
    context.push('/book/review');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final addresses = ref.watch(addressesProvider);
    final draftAddress = ref.watch(
      bookingDraftProvider.select((d) => d.address),
    );

    // Preselect the default saved address the first time they load.
    ref.listen(addressesProvider, (_, next) {
      final list = next.asData?.value;
      if (list == null || list.isEmpty || _address != null) return;
      setState(
        () => _address = list.firstWhere(
          (a) => a.isDefault,
          orElse: () => list.first,
        ),
      );
    });

    final saved = addresses.asData?.value ?? const <Address>[];
    final shown = <Address>[
      ...saved,
      if (draftAddress != null && !saved.any((a) => a.id == draftAddress.id))
        draftAddress,
    ];

    return FlowScaffold(
      step: 5,
      title: l.stepDetailsTitle,
      bottom: BottomActionBar(
        child: CnButton(label: l.continueLabel, onPressed: _continue),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: CnSpace.page,
          children: [
            Semantics(
              header: true,
              child: Text(l.patientDetails, style: t.titleLarge),
            ),
            const SizedBox(height: CnSpace.lg),
            CnTextField(
              controller: _name,
              label: l.patientName,
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l.nameRequired : null,
            ),
            const SizedBox(height: CnSpace.md),
            CnTextField(
              controller: _age,
              label: l.patientAge,
              keyboardType: TextInputType.number,
              maxLength: 3,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = int.tryParse(v.trim());
                return (n == null || n < 0 || n > 120) ? l.ageInvalid : null;
              },
            ),
            const SizedBox(height: CnSpace.md),
            Text(l.patientSex, style: t.labelMedium),
            const SizedBox(height: CnSpace.sm),
            SexChooser(value: _sex, onChanged: (v) => setState(() => _sex = v)),
            const SizedBox(height: CnSpace.md),
            CnTextField(
              controller: _condition,
              label: l.conditionNotes,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: CnSpace.md),
            CnTextField(
              controller: _phone,
              label: l.contactPhone,
              helper: l.contactPhoneHelp,
              prefixText: '+91  ',
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              maxLength: 14,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l.phoneRequired
                  : (parseIndianMobile(v) == null ? l.phoneInvalid : null),
            ),
            const SizedBox(height: CnSpace.xl),
            Semantics(
              header: true,
              child: Text(l.whereShouldNurseCome, style: t.titleLarge),
            ),
            const SizedBox(height: CnSpace.md),
            AsyncAddressList(
              addresses: addresses,
              shown: shown,
              selected: _address,
              onSelect: (a) => setState(() {
                _address = a;
                _addressMissing = false;
              }),
              onRetry: () => ref.invalidate(addressesProvider),
            ),
            const SizedBox(height: CnSpace.sm),
            Row(
              children: [
                Expanded(
                  child: CnButton(
                    label: l.currentLocation,
                    icon: Icons.my_location,
                    kind: CnButtonKind.secondary,
                    onPressed: () => _pickOnMap(current: true),
                  ),
                ),
                const SizedBox(width: CnSpace.sm),
                Expanded(
                  child: CnButton(
                    label: l.pickOnMap,
                    icon: Icons.map_outlined,
                    kind: CnButtonKind.secondary,
                    onPressed: () => _pickOnMap(current: false),
                  ),
                ),
              ],
            ),
            if (_addressMissing) ...[
              const SizedBox(height: CnSpace.md),
              CnBanner(message: l.addressRequired, tone: Tone.danger),
            ],
          ],
        ),
      ),
    );
  }
}

/// Saved address choices with loading and error handling.
class AsyncAddressList extends StatelessWidget {
  const AsyncAddressList({
    super.key,
    required this.addresses,
    required this.shown,
    required this.selected,
    required this.onSelect,
    required this.onRetry,
  });
  final AsyncValue<List<Address>> addresses;
  final List<Address> shown;
  final Address? selected;
  final ValueChanged<Address> onSelect;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (addresses.isLoading && shown.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16), child: CnLoading());
    }
    if (addresses.hasError && shown.isEmpty) {
      return CnBanner(
        message: l.couldNotLoadAddresses,
        tone: Tone.warning,
        action: CnButton(
          label: l.tryAgain,
          kind: CnButtonKind.text,
          expand: false,
          onPressed: onRetry,
        ),
      );
    }
    return Column(
      children: [
        for (final a in shown) ...[
          SelectTile(
            title: addressLabel(l, a.label),
            subtitle: a.summary,
            leading: Icon(
              a.label == 'Work' ? Icons.work_outline : Icons.home_outlined,
              color: context.cn.fg2,
            ),
            selected: selected?.id == a.id,
            onTap: () => onSelect(a),
          ),
          const SizedBox(height: CnSpace.sm),
        ],
      ],
    );
  }
}

String addressLabel(AppLocalizations l, String label) => switch (label) {
  'Home' => l.labelHome,
  'Work' => l.labelWork,
  'Other' => l.labelOther,
  _ => label,
};

class SexChooser extends StatelessWidget {
  const SexChooser({super.key, required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.cn;
    final options = {
      'male': l.sexMale,
      'female': l.sexFemale,
      'other': l.sexOther,
    };
    return Wrap(
      spacing: CnSpace.sm,
      runSpacing: CnSpace.sm,
      children: [
        for (final e in options.entries)
          Semantics(
            button: true,
            selected: value == e.key,
            label: e.value,
            excludeSemantics: true,
            onTap: () => onChanged(e.key),
            child: ChoiceChip(
              label: Text(e.value),
              selected: value == e.key,
              showCheckmark: false,
              onSelected: (_) => onChanged(e.key),
              materialTapTargetSize: MaterialTapTargetSize.padded,
              labelStyle: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: value == e.key ? c.accentText : c.fg),
              selectedColor: c.accentSoft,
              backgroundColor: c.surface,
              side: BorderSide(
                color: value == e.key ? c.accent : c.borderStrong,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(CnSpace.radius),
              ),
            ),
          ),
      ],
    );
  }
}
