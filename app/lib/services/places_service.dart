import 'package:dio/dio.dart';

import 'geo.dart';

/// Address search and reverse geocoding. [GooglePlacesService] needs a key;
/// [FakePlacesService] is used automatically when there is none.
abstract class PlacesService {
  bool get isFake;
  Future<List<PlaceSuggestion>> autocomplete(
    String query, {
    required String sessionToken,
  });
  Future<ResolvedPlace> details(String placeId, {required String sessionToken});
  Future<ResolvedPlace?> reverseGeocode(GeoPoint point);
}

class GooglePlacesService implements PlacesService {
  GooglePlacesService(this.apiKey, {Dio? dio}) : _dio = dio ?? Dio();
  final String apiKey;
  final Dio _dio;

  @override
  bool get isFake => false;

  @override
  Future<List<PlaceSuggestion>> autocomplete(
    String query, {
    required String sessionToken,
  }) async {
    if (query.trim().length < 3) return const [];
    final res = await _dio.post<Map<String, dynamic>>(
      'https://places.googleapis.com/v1/places:autocomplete',
      data: {
        'input': query,
        'sessionToken': sessionToken,
        'includedRegionCodes': ['in'],
      },
      options: Options(headers: {'X-Goog-Api-Key': apiKey}),
    );
    final list = (res.data?['suggestions'] as List?) ?? const [];
    return [
      for (final s in list)
        if (s is Map && s['placePrediction'] is Map)
          PlaceSuggestion(
            id: (s['placePrediction'] as Map)['placeId'] as String,
            primary:
                ((s['placePrediction'] as Map)['structuredFormat']
                        as Map?)?['mainText']?['text']
                    as String? ??
                ((s['placePrediction'] as Map)['text'] as Map)['text']
                    as String,
            secondary:
                ((s['placePrediction'] as Map)['structuredFormat']
                        as Map?)?['secondaryText']?['text']
                    as String? ??
                '',
          ),
    ];
  }

  @override
  Future<ResolvedPlace> details(
    String placeId, {
    required String sessionToken,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      'https://places.googleapis.com/v1/places/$placeId',
      queryParameters: {'sessionToken': sessionToken},
      options: Options(
        headers: {
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask': 'location,addressComponents',
        },
      ),
    );
    final d = res.data!;
    final loc = d['location'] as Map;
    final comps = [
      for (final c in (d['addressComponents'] as List? ?? const []))
        (
          types: List<String>.from((c as Map)['types'] as List),
          text: c['longText'] as String? ?? '',
        ),
    ];
    return _fromComponents(
      GeoPoint(
        (loc['latitude'] as num).toDouble(),
        (loc['longitude'] as num).toDouble(),
      ),
      comps,
    );
  }

  @override
  Future<ResolvedPlace?> reverseGeocode(GeoPoint point) async {
    final res = await _dio.get<Map<String, dynamic>>(
      'https://maps.googleapis.com/maps/api/geocode/json',
      queryParameters: {'latlng': '${point.lat},${point.lng}', 'key': apiKey},
    );
    final results = (res.data?['results'] as List?) ?? const [];
    if (results.isEmpty) return null;
    final comps = [
      for (final c in ((results.first as Map)['address_components'] as List))
        (
          types: List<String>.from((c as Map)['types'] as List),
          text: c['long_name'] as String? ?? '',
        ),
    ];
    return _fromComponents(point, comps);
  }

  static ResolvedPlace _fromComponents(
    GeoPoint p,
    List<({List<String> types, String text})> comps,
  ) {
    String pick(List<String> wanted) {
      for (final w in wanted) {
        for (final c in comps) {
          if (c.types.contains(w)) return c.text;
        }
      }
      return '';
    }

    final area = [
      pick(['route']),
      pick(['sublocality_level_1', 'sublocality', 'neighborhood']),
    ].where((e) => e.isNotEmpty).join(', ');
    return ResolvedPlace(
      point: p,
      areaLine: area,
      city: pick([
        'locality',
        'administrative_area_level_3',
        'administrative_area_level_2',
      ]),
      state: pick(['administrative_area_level_1']),
      pincode: pick(['postal_code']),
    );
  }
}

/// A handful of Bareilly and Delhi places so the screens work without a key.
class FakePlacesService implements PlacesService {
  const FakePlacesService();

  static const _places = <String, ResolvedPlace>{
    'fake-sector14': ResolvedPlace(
      point: GeoPoint(28.3670, 79.4304),
      areaLine: 'Sector 14',
      city: 'Bareilly',
      state: 'Uttar Pradesh',
      pincode: '243001',
    ),
    'fake-civil-lines': ResolvedPlace(
      point: GeoPoint(28.3563, 79.4172),
      areaLine: 'Civil Lines',
      city: 'Bareilly',
      state: 'Uttar Pradesh',
      pincode: '243001',
    ),
    'fake-rajendra-nagar': ResolvedPlace(
      point: GeoPoint(28.3790, 79.4390),
      areaLine: 'Rajendra Nagar',
      city: 'Bareilly',
      state: 'Uttar Pradesh',
      pincode: '243122',
    ),
    'fake-connaught': ResolvedPlace(
      point: GeoPoint(28.6315, 77.2167),
      areaLine: 'Connaught Place',
      city: 'New Delhi',
      state: 'Delhi',
      pincode: '110001',
    ),
    'fake-saket': ResolvedPlace(
      point: GeoPoint(28.5245, 77.2066),
      areaLine: 'Saket',
      city: 'New Delhi',
      state: 'Delhi',
      pincode: '110017',
    ),
  };

  @override
  bool get isFake => true;

  @override
  Future<List<PlaceSuggestion>> autocomplete(
    String query, {
    required String sessionToken,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return [
      for (final e in _places.entries)
        if (e.value.areaLine.toLowerCase().contains(q) ||
            e.value.city.toLowerCase().contains(q))
          PlaceSuggestion(
            id: e.key,
            primary: e.value.areaLine,
            secondary: '${e.value.city}, ${e.value.state}',
          ),
    ];
  }

  @override
  Future<ResolvedPlace> details(
    String placeId, {
    required String sessionToken,
  }) async => _places[placeId]!;

  @override
  Future<ResolvedPlace?> reverseGeocode(GeoPoint point) async {
    ResolvedPlace best = _places.values.first;
    for (final p in _places.values) {
      if (p.point.distanceTo(point) < best.point.distanceTo(point)) best = p;
    }
    return ResolvedPlace(
      point: point,
      areaLine: best.areaLine,
      city: best.city,
      state: best.state,
      pincode: best.pincode,
    );
  }
}
