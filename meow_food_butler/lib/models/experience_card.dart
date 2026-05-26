import 'food_card.dart';

class ExperienceCard {
  String? id;
  final String? originalURL;
  final List<String?> AITags;
  final double personalRating;
  final RestaurantInfo restaurantInfo;
  Timestamp? _createdTime;
  Timestamp get createdTime => _createdTime ?? Timestamp.now();
  final bool isDone;

  ExperienceCard({
    this.id,
    this.originalURL,
    required this.AITags,
    required this.personalRating,
    required this.restaurantInfo,
    Timestamp? createdTime,
    this.isDone = false,
  }) : _createdTime = createdTime;

  factory ExperienceCard.fromMap(Map<String, dynamic> map, String id) {
    return ExperienceCard._(
    );
  }

  Map<String, dynamic> toMap() {
    return {
    };
  }

  @override
  bool operator ==(Object other);

  @override
  int get hashCode => id.hashCode;
}

