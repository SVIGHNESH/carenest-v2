import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../services/geo.dart';
import '../../services/location_service.dart';
import '../../state/booking_draft.dart';
import '../../state/providers.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'pin_map.dart';

/// Pilot city centre, used when there is no pin and no location permission.
const defaultMapCenter = GeoPoint(28.3670, 79.4304);

class MapPickerArgs {
  const MapPickerArgs({this.initial, this.startWithCurrentLocation = false});
  final GeoPoint? initial;
  final bool startWithCurrentLocation;
}

/// Screen "Set location": search, move the map under the pin, use current
/// location, then Confirm. Pops with a [PendingLocation].
class MapPickerScreen extends ConsumerStatefulWidget {
  const MapPickerScreen({super.key, this.args = const MapPickerArgs()});
  final MapPickerArgs args;

  @override
  ConsumerState<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends ConsumerState<MapPickerScreen> {
  final _search = TextEditingController();
  late GeoPoint _pin = widget.args.initial ?? defaultMapCenter;
  late GeoPoint _target = _pin;
  ResolvedPlace? _resolved;
  bool _resolving = false;
  bool _resolveFailed = false;
  List<PlaceSuggestion> _suggestions = const [];
  bool _searching = false;
  Timer? _debounce;
  int _token = 0;
  String? _locationMessage;
  String _session = _newSession();

  static String _newSession() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.args.startWithCurrentLocation) {
        _useCurrentLocation();
      } else {
        _reverse(_pin);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _reverse(GeoPoint p) async {
    final my = ++_token;
    setState(() {
      _resolving = true;
      _resolveFailed = false;
    });
    try {
      final r = await ref.read(placesServiceProvider).reverseGeocode(p);
      if (!mounted || my != _token) return;
      setState(() {
        _resolved = r;
        _resolveFailed = r == null;
        _resolving = false;
      });
    } catch (_) {
      if (!mounted || my != _token) return;
      setState(() {
        _resolved = null;
        _resolveFailed = true;
        _resolving = false;
      });
    }
  }

  void _onMoved(GeoPoint p) {
    _pin = p;
    _reverse(p);
  }

  void _onQuery(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searching = true);
      try {
        final s = await ref
            .read(placesServiceProvider)
            .autocomplete(q, sessionToken: _session);
        if (mounted) setState(() => _suggestions = s);
      } catch (_) {
        if (mounted) setState(() => _suggestions = const []);
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _pick(PlaceSuggestion s) async {
    FocusScope.of(context).unfocus();
    setState(() => _suggestions = const []);
    _search.text = s.primary;
    try {
      final r = await ref
          .read(placesServiceProvider)
          .details(s.id, sessionToken: _session);
      _session = _newSession();
      if (!mounted) return;
      setState(() {
        _pin = r.point;
        _target = r.point;
        _resolved = r;
        _resolveFailed = false;
        _token++;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _locationMessage = AppLocalizations.of(context).searchFailed,
        );
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    final l = AppLocalizations.of(context);
    setState(() => _locationMessage = null);
    try {
      final p = await ref.read(locationServiceProvider).current();
      if (!mounted) return;
      setState(() {
        _pin = p;
        _target = p;
      });
      _reverse(p);
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _locationMessage = switch (e.failure) {
          LocationFailure.denied => l.locationDenied,
          LocationFailure.deniedForever => l.locationDeniedForever,
          LocationFailure.serviceOff => l.locationOff,
          LocationFailure.unavailable => l.locationUnavailable,
        };
      });
      _reverse(_pin);
    }
  }

  void _confirm() {
    final r = _resolved;
    final pending = PendingLocation(
      latitude: _pin.lat,
      longitude: _pin.lng,
      areaLine: r?.areaLine ?? '',
      city: r?.city ?? '',
      state: r?.state ?? '',
      pincode: r?.pincode ?? '',
    );
    context.pop(pending);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.cn;
    final t = Theme.of(context).textTheme;
    final summary = _resolved?.summary ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(l.setLocation)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              children: [
                CnTextField(
                  controller: _search,
                  label: l.searchPlaces,
                  textInputAction: TextInputAction.search,
                  onChanged: _onQuery,
                  suffix: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : const Icon(Icons.search),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: CnButton(
                    label: l.useCurrentLocation,
                    icon: Icons.my_location,
                    kind: CnButtonKind.text,
                    expand: false,
                    onPressed: _useCurrentLocation,
                  ),
                ),
                if (_locationMessage != null)
                  CnBanner(message: _locationMessage!, tone: Tone.warning),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: PinMap(target: _target, onMoved: _onMoved),
                ),
                if (_suggestions.isNotEmpty)
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 0,
                    child: Material(
                      color: c.surface,
                      elevation: 3,
                      borderRadius: BorderRadius.circular(CnSpace.radius),
                      child: ListView(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        children: [
                          for (final s in _suggestions)
                            ListTile(
                              minVerticalPadding: 10,
                              leading: const Icon(Icons.place_outlined),
                              title: Text(s.primary),
                              subtitle: s.secondary.isEmpty
                                  ? null
                                  : Text(s.secondary),
                              onTap: () => _pick(s),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          BottomActionBar(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Row(
                    children: [
                      Icon(Icons.place_outlined, color: c.accentText),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _resolving
                              ? l.findingAddress
                              : summary.isNotEmpty
                              ? summary
                              : (_resolveFailed
                                    ? l.addressNotFound
                                    : _pin.label),
                          style: t.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                CnButton(
                  label: l.confirmLocation,
                  onPressed: _resolving ? null : _confirm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
