import 'dart:convert';

import 'package:http/http.dart' as http;

class NearbyPlace {
  final String placeId;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;

  const NearbyPlace({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  static NearbyPlace? fromMap(Map<String, dynamic> map) {
    final displayName = map['displayName'] as Map<String, dynamic>?;
    final location = map['location'] as Map<String, dynamic>?;
    final placeId = map['id'] as String?;
    final latitude = (location?['latitude'] as num?)?.toDouble();
    final longitude = (location?['longitude'] as num?)?.toDouble();

    if (placeId == null || latitude == null || longitude == null) {
      return null;
    }

    return NearbyPlace(
      placeId: placeId,
      name: (displayName?['text'] as String?) ?? 'Unknown restaurant',
      address: map['formattedAddress'] as String?,
      latitude: latitude,
      longitude: longitude,
    );
  }
}

class NearbyPlacesService {
  static const String _apiKey = 'AIzaSyCMd1wINmFXLfqbiVwh-zdorui6R-wPgKU';

  bool get hasApiKey => _apiKey.isNotEmpty;

  Future<List<NearbyPlace>> restaurantsNear({
    required double latitude,
    required double longitude,
  }) async {
    if (!hasApiKey) return const [];

    final response = await http.post(
      Uri.parse('https://places.googleapis.com/v1/places:searchNearby'),
      headers: const {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask':
            'places.id,places.displayName,places.formattedAddress,places.location',
      },
      body: jsonEncode({
        'includedTypes': ['restaurant'],
        'maxResultCount': 10,
        'locationRestriction': {
          'circle': {
            'center': {'latitude': latitude, 'longitude': longitude},
            'radius': 150.0,
          },
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NearbyPlacesException(
        _errorMessage('Places request failed', response),
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final places = data['places'] as List<dynamic>? ?? const [];

    return places
        .whereType<Map<String, dynamic>>()
        .map(NearbyPlace.fromMap)
        .nonNulls
        .toList();
  }

  Future<List<NearbyPlace>> searchRestaurants(String query) async {
    final trimmedQuery = query.trim();
    if (!hasApiKey || trimmedQuery.length < 2) return const [];

    final response = await http.post(
      Uri.parse('https://places.googleapis.com/v1/places:searchText'),
      headers: const {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask':
            'places.id,places.displayName,places.formattedAddress,places.location',
      },
      body: jsonEncode({
        'textQuery': trimmedQuery,
        'includedType': 'restaurant',
        'maxResultCount': 8,
        'languageCode': 'zh-TW',
        'regionCode': 'TW',
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NearbyPlacesException(
        _errorMessage('Places search failed', response),
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final places = data['places'] as List<dynamic>? ?? const [];

    return places
        .whereType<Map<String, dynamic>>()
        .map(NearbyPlace.fromMap)
        .nonNulls
        .toList();
  }

  String _errorMessage(String prefix, http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final error = data['error'] as Map<String, dynamic>?;
      final message = error?['message'] as String?;
      if (message != null && message.isNotEmpty) {
        return '$prefix (${response.statusCode}): $message';
      }
    } catch (_) {
      // Fall through to a compact fallback below.
    }

    return '$prefix (${response.statusCode}).';
  }
}

class NearbyPlacesException implements Exception {
  final String message;

  const NearbyPlacesException(this.message);
}
