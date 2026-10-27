import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/api/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/geo.dart';
import '../../state/booking_draft.dart';
import '../../state/providers.dart';
import '../../ui/error_text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../booking/details_screen.dart';
import '../map/map_picker_screen.dart';

enum AddressFormMode { booking, profileNew, edit }

class AddressFormArgs {
  const AddressFormArgs._(this.mode, this.pending, this.existing);
  factory AddressFormArgs.forBooking(PendingLocation p) =>
      AddressFormArgs._(AddressFormMode.booking, p, null);
  factory AddressFormArgs.forNew(PendingLocation p) =>
      AddressFormArgs._(AddressFormMode.profileNew, p, null);
  factory AddressFormArgs.forEdit(Address a) =>
      AddressFormArgs._(AddressFormMode.edit, null, a);

  final AddressFormMode mode;
  final PendingLocation? pending;
  final Address? existing;
}

/// "Address details": the map gives the area, the user adds house number and landmark.
class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({super.key, required this.args});
  final AddressFormArgs args;

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _house;
  late final TextEditingController _landmark;
  late final TextEditingController _area;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _pincode;
  late double _lat;
  late double _lng;
  String _label = 'Home';
  late bool _flag;
  bool _busy = false;
  String? _error;

  AddressFormMode get _mode => widget.args.mode;

  @override
  void initState() {
    super.initState();
    final e = widget.args.existing;
    final p = widget.args.pending;
    _house = TextEditingController(text: e?.house ?? '');
    _landmark = TextEditingController(text: e?.landmark ?? '');
    _area = TextEditingController(text: e?.areaLine ?? p?.areaLine ?? '');
    _city = TextEditingController(text: e?.city ?? p?.city ?? '');
    _state = TextEditingController(text: e?.state ?? p?.state ?? '');
    _pincode = TextEditingController(text: e?.pincode ?? p?.pincode ?? '');
    _lat = e?.latitude ?? p!.latitude;
    _lng = e?.longitude ?? p!.longitude;
    _label = e?.label ?? 'Home';
    // booking: "save for next time" (on by default); otherwise "set as default".
    _flag = _mode == AddressFormMode.booking ? true : (e?.isDefault ?? false);
  }

  @override
  void dispose() {
    for (final c in [_house, _landmark, _area, _city, _state, _pincode]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _changeLocation() async {
    final p = await context.push<PendingLocation>(
      '/map',
      extra: MapPickerArgs(initial: GeoPoint(_lat, _lng)),
    );
    if (p == null || !mounted) return;
    setState(() {
      _lat = p.latitude;
      _lng = p.longitude;
      _area.text = p.areaLine;
      _city.text = p.city;
      _state.text = p.state;
      _pincode.text = p.pincode;
    });
  }

  AddressInput _input() => AddressInput(
    label: _label,
    house: _house.text.trim(),
    areaLine: _area.text.trim(),
    city: _city.text.trim(),
    state: _state.text.trim(),
    pincode: _pincode.text.trim(),
    landmark: _landmark.text,
    latitude: _lat,
    longitude: _lng,
    isDefault: _mode != AddressFormMode.booking && _flag,
  );

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(profileRepositoryProvider);
    try {
      final Address saved;
      if (_mode == AddressFormMode.edit) {
        saved = await repo.updateAddress(
          widget.args.existing!.id,
          _input().toJson(),
        );
      } else {
        saved = await repo.addAddress(_input());
      }
      if (_mode == AddressFormMode.booking) {
        ref
            .read(bookingDraftProvider.notifier)
            .useCreatedAddress(saved, temporary: !_flag);
      }
      ref.invalidate(addressesProvider);
      if (mounted) context.pop(saved);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.cn;
    final t = Theme.of(context).textTheme;
    final summary = [
      _area.text,
      _city.text,
      _state.text,
      _pincode.text,
    ].where((s) => s.trim().isNotEmpty).join(', ');
    final needsArea = summary.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _mode == AddressFormMode.edit ? l.editAddress : l.addressDetails,
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: CnButton(
          label: switch (_mode) {
            AddressFormMode.booking => l.useThisAddress,
            _ => l.saveAddress,
          },
          onPressed: _submit,
          loading: _busy,
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: CnSpace.page,
          children: [
            CnCard(
              child: Row(
                children: [
                  Icon(Icons.place_outlined, color: c.accentText),
                  const SizedBox(width: CnSpace.md),
                  Expanded(
                    child: Text(
                      summary.isEmpty ? GeoPoint(_lat, _lng).label : summary,
                      style: t.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  CnButton(
                    label: l.change,
                    kind: CnButtonKind.text,
                    expand: false,
                    onPressed: _changeLocation,
                  ),
                ],
              ),
            ),
            const SizedBox(height: CnSpace.lg),
            CnTextField(
              controller: _house,
              label: l.houseOrFlat,
              autofocus: _mode != AddressFormMode.edit,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l.houseRequired : null,
            ),
            const SizedBox(height: CnSpace.md),
            CnTextField(
              controller: _landmark,
              label: l.landmarkOptional,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: CnSpace.lg),
            Text(l.saveAs, style: t.labelMedium),
            const SizedBox(height: CnSpace.sm),
            Wrap(
              spacing: CnSpace.sm,
              children: [
                for (final lab in const ['Home', 'Work', 'Other'])
                  ChoiceChip(
                    label: Text(addressLabel(l, lab)),
                    selected: _label == lab,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _label = lab),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    labelStyle: t.labelLarge?.copyWith(
                      color: _label == lab ? c.accentText : c.fg,
                    ),
                    selectedColor: c.accentSoft,
                    backgroundColor: c.surface,
                    side: BorderSide(
                      color: _label == lab ? c.accent : c.borderStrong,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: CnSpace.md),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _flag,
              onChanged: (v) => setState(() => _flag = v ?? false),
              title: Text(
                _mode == AddressFormMode.booking
                    ? l.saveForNextTime
                    : l.setAsDefault,
              ),
            ),
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: needsArea,
                title: Text(l.editAreaDetails, style: t.titleSmall),
                children: [
                  CnTextField(
                    controller: _area,
                    label: l.areaStreet,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: CnSpace.md),
                  CnTextField(
                    controller: _city,
                    label: l.city,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: CnSpace.md),
                  CnTextField(
                    controller: _state,
                    label: l.stateLabel,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: CnSpace.md),
                  CnTextField(
                    controller: _pincode,
                    label: l.pincode,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: CnSpace.md),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: CnSpace.md),
              CnBanner(message: _error!, tone: Tone.danger),
            ],
          ],
        ),
      ),
    );
  }
}
