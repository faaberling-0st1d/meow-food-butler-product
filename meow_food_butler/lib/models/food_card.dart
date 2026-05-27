import 'package:flutter/foundation.dart'; // Necessary for JSON datatype integration.

class FoodCard {
  final String? id;                     // Google Place API: 'id' (eg. "ChIJX43...")
  final String? originalURL;            // The parsed source (Instagram, Google Maps, ...)
  final String? formattedAddress;       // Google Place API: 'formattedAddress'
  final double? rating;                 // Google Place API: 'rating'
  final List<DisplayName> displayNames; // Google Place API: 'displayName', handling localized place names.
  final LocationCoordinate? location;   // Coords for our map to render the place.

  FoodCard({
    this.id,
    this.originalURL,
    this.formattedAddress,
    this.rating,
    required this.displayNames,
    this.location,
  });

  factory FoodCard.fromMap(Map<String, dynamic> map) {
    return FoodCard(
      id: map['id'] as String?,
      originalURL: map['originalURL'] as String?,
      formattedAddress: map['formattedAddress'] as String?,
      // API numbers can arrive as int or double; safely cast to double
      rating: (map['rating'] as num?)?.toDouble(),
      displayNames: map['displayName'] != null
          ? [DisplayName.fromMap(map['displayName'] as Map<String, dynamic>)]
          : (map['displayNames'] as List<dynamic>?)
                  ?.map((e) => DisplayName.fromMap(e as Map<String, dynamic>))
                  .toList() ??
              const [],
      location: map['location'] != null
          ? LocationCoordinate.fromMap(map['location'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'originalURL': originalURL,
      'formattedAddress': formattedAddress,
      'rating': rating,
      'displayNames': displayNames.map((e) => e.toMap()).toList(),
      'location': location?.toMap(),
    };
  }

  /// Helper getter to fetch the principal application title fallback string
  String get primaryTitle {
    if (displayNames.isEmpty) return "Unknown Food Spot";
    // Prioritize English or match your target region code if preferred
    final preferredName = displayNames.firstWhere(
      (name) => name.languageCode == 'en',
      orElse: () => displayNames.first,
    );
    return preferredName.title ?? "Unknown Food Spot";
  }

  /// Structural equality overrides are mandatory for structural stack swiping comparisons
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FoodCard &&
        other.id == id &&
        other.originalURL == originalURL &&
        other.formattedAddress == formattedAddress &&
        other.rating == rating &&
        listEquals(other.displayNames, displayNames) &&
        other.location == location;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      originalURL,
      formattedAddress,
      rating,
      Object.hashAll(displayNames),
      location,
    );
  }
}

class DisplayName {
  String? title;
  String? languageCode;

  DisplayName({
    this.title,
    this.languageCode,
  });

  factory DisplayName.fromMap(Map<String, dynamic> map) {
    return DisplayName(
      title: (map['text'] ?? map['title']) as String?,
      languageCode: map['languageCode'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': title,
      'languageCode': languageCode,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DisplayName &&
        other.title == title &&
        other.languageCode == languageCode;
  }

  @override
  int get hashCode => Object.hash(title, languageCode);
}

class LocationCoordinate {
  final double? longitude; // 經
  final double? latitude;   // 緯

  LocationCoordinate({
    required this.longitude,
    required this.latitude,
  });

  factory LocationCoordinate.fromMap(Map<String, dynamic> map) {
    return LocationCoordinate(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationCoordinate &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

// [PLACE API RETURN DATA]
// 
// {
//   "places": [
//     {
//       "formattedAddress": "123 Meat St, Taipei City, Taiwan",
//       "rating": 4.5,
//       "displayName": {
//         "text": "Prime Steakhouse",
//         "languageCode": "en"
//       }
//     },
//   ]
// }
