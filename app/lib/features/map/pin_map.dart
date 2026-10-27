import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as g;

import '../../config/env.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/geo.dart';
import '../../ui/tokens.dart';

/// Map with a pin fixed at its centre; the user moves the map under the pin.
/// [target] moves the map from outside (search, current location);
/// [onMoved] reports where the pin ended up after the user moves the map.
class PinMap extends StatelessWidget {
  const PinMap({
    super.key,
    required this.target,
    required this.onMoved,
    this.forceSimulated = false,
  });

  final GeoPoint target;
  final ValueChanged<GeoPoint> onMoved;
  final bool forceSimulated;

  @override
  Widget build(BuildContext context) {
    if (forceSimulated || !Env.hasMapsKey) {
      return SimulatedPinMap(target: target, onMoved: onMoved);
    }
    return _GooglePinMap(target: target, onMoved: onMoved);
  }
}

class _CenterPin extends StatelessWidget {
  const _CenterPin();
  @override
  Widget build(BuildContext context) {
    final c = context.cn;
    return IgnorePointer(
      child: Center(
        child: Transform.translate(
          offset: const Offset(0, -22),
          child: Icon(
            Icons.location_on,
            size: 48,
            color: c.danger,
            shadows: const [Shadow(blurRadius: 6, color: Colors.black26)],
          ),
        ),
      ),
    );
  }
}

class _GooglePinMap extends StatefulWidget {
  const _GooglePinMap({required this.target, required this.onMoved});
  final GeoPoint target;
  final ValueChanged<GeoPoint> onMoved;

  @override
  State<_GooglePinMap> createState() => _GooglePinMapState();
}

class _GooglePinMapState extends State<_GooglePinMap> {
  g.GoogleMapController? _controller;
  late g.LatLng _center = g.LatLng(widget.target.lat, widget.target.lng);
  bool _moving = false;

  @override
  void didUpdateWidget(_GooglePinMap old) {
    super.didUpdateWidget(old);
    final t = widget.target;
    if (t != old.target &&
        (t.lat != _center.latitude || t.lng != _center.longitude)) {
      _controller?.animateCamera(
        g.CameraUpdate.newLatLngZoom(g.LatLng(t.lat, t.lng), 17),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        g.GoogleMap(
          initialCameraPosition: g.CameraPosition(target: _center, zoom: 17),
          onMapCreated: (c) => _controller = c,
          onCameraMoveStarted: () => _moving = true,
          onCameraMove: (p) => _center = p.target,
          onCameraIdle: () {
            if (!_moving) return;
            _moving = false;
            widget.onMoved(GeoPoint(_center.latitude, _center.longitude));
          },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
        const _CenterPin(),
      ],
    );
  }
}

/// Stand-in used when no Google Maps key is configured: a draggable grid
/// with the same centre-pin behaviour and a lat/lng read-out.
class SimulatedPinMap extends StatefulWidget {
  const SimulatedPinMap({
    super.key,
    required this.target,
    required this.onMoved,
  });
  final GeoPoint target;
  final ValueChanged<GeoPoint> onMoved;

  @override
  State<SimulatedPinMap> createState() => _SimulatedPinMapState();
}

class _SimulatedPinMapState extends State<SimulatedPinMap> {
  static const _degreesPerPixel = 0.00002;
  late GeoPoint _center = widget.target;

  @override
  void didUpdateWidget(SimulatedPinMap old) {
    super.didUpdateWidget(old);
    if (widget.target != old.target) _center = widget.target;
  }

  void _pan(Offset delta) {
    final cosLat = math.cos(_center.lat * math.pi / 180).abs().clamp(0.2, 1.0);
    setState(() {
      _center = GeoPoint(
        (_center.lat + delta.dy * _degreesPerPixel).clamp(-85.0, 85.0),
        (_center.lng - delta.dx * _degreesPerPixel / cosLat).clamp(
          -180.0,
          180.0,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cn;
    final l = AppLocalizations.of(context);
    return Semantics(
      label: l.simulatedMapLabel(_center.label),
      child: GestureDetector(
        onPanUpdate: (d) => _pan(d.delta),
        onPanEnd: (_) => widget.onMoved(_center),
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _GridPainter(
                  _center,
                  c.sunken,
                  c.border,
                  c.borderStrong,
                ),
              ),
              const _CenterPin(),
              Positioned(
                left: 12,
                top: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l.simulatedMapNote,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          _center.label,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.center, this.bg, this.line, this.strong);
  final GeoPoint center;
  final Color bg, line, strong;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);
    const step = 48.0;
    const dpp = _SimulatedPinMapState._degreesPerPixel;
    final ox = ((-center.lng / dpp) % step);
    final oy = ((center.lat / dpp) % step);
    final thin = Paint()
      ..color = line
      ..strokeWidth = 1;
    final thick = Paint()
      ..color = strong
      ..strokeWidth = 2;
    var i = 0;
    for (double x = ox - step; x < size.width + step; x += step, i++) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        i % 4 == 0 ? thick : thin,
      );
    }
    i = 0;
    for (double y = oy - step; y < size.height + step; y += step, i++) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        i % 4 == 0 ? thick : thin,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.center != center || old.bg != bg;
}
