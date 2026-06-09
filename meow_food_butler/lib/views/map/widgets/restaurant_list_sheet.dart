import 'package:flutter/material.dart';
import '../../../models/experience_card.dart';
import '../../../models/food_card.dart';
import '../../explore/widgets/restaurant_card.dart';
import '../../saved/food_card_detail.dart';

class RestaurantListSheet extends StatelessWidget {
  final List<ExperienceCard> experiences;

  const RestaurantListSheet({
    super.key,
    required this.experiences,
  });

  void _showRestaurantDetail(BuildContext context, ExperienceCard exp) {
    final relatedFoodCard = FoodCard(
      id: exp.foodCardId,
      originalURL: exp.photoUrls.isNotEmpty ? exp.photoUrls.first : exp.originalURL,
      formattedAddress: exp.placeAddress,
      rating: exp.personalRating,
      displayNames: [
        DisplayName(
          title: exp.placeTitle ?? 'Unamed restaurant',
          languageCode: 'zh-TW',
        )
      ],
      location: exp.latitude != null && exp.longitude != null
          ? LocationCoordinate(latitude: exp.latitude, longitude: exp.longitude)
          : null,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9, 
          minChildSize: 0.5,     
          maxChildSize: 0.95,    
          builder: (_, controller) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: FoodCardDetail(
                foodCard: relatedFoodCard,
                experiences: [exp], 
                isSaved: exp.isDone,
                onClose: () => Navigator.pop(context), 
                onToggleSave: () {
                  // TODO: 串接 MapViewModel 的 toggleSaveStatus()
                  debugPrint('點擊了收藏/取消收藏: ${exp.placeTitle}');
                },
                onAddExperience: () {
                  // TODO: 導航至新增體驗表單 (experience_entry_sheet.dart)
                  debugPrint('點擊了新增體驗: ${exp.placeTitle}');
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.35, 
      minChildSize: 0.12,     
      maxChildSize: 0.85,    
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: experiences.isEmpty
              ? _buildEmptyState(scrollController)
              : ListView.builder(
                  controller: scrollController,
                  itemCount: experiences.length + 1,
                  itemBuilder: (context, index) {
                    
                    if (index == 0) {
                      return _buildDragHandle();
                    }

                    final exp = experiences[index - 1];

                    return GestureDetector(
                      onTap: () => _showRestaurantDetail(context, exp),
                      child: RestaurantCard(
                        experience: exp,
                        onNavTap: () {
                          // TODO: 串接 Google Maps 外部導航
                          debugPrint('啟動導航前往: ${exp.placeTitle}');
                        },
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildDragHandle() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          height: 5,
          width: 40,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildEmptyState(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      children: [
        _buildDragHandle(),
        SizedBox(height: 40),
        Icon(Icons.map_outlined, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text(
          "這附近還沒有探索紀錄",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "移動地圖或是新增你的第一筆美食體驗吧！",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}