import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/food_card.dart';
import '../../models/experience_card.dart';
import '../../view_models/saved_view_model.dart';

import 'experience_entry_sheet.dart'; 
import 'experience_detail_screen.dart';
import 'widgets/experience_photo.dart';

class FoodCardDetail extends StatefulWidget {
  final FoodCard foodCard;
  final List<ExperienceCard> experiences;
  final bool isSaved;
  final VoidCallback onClose;
  final VoidCallback onToggleSave;
  final VoidCallback onAddExperience;
  final bool showOnlineInfoTab;

  const FoodCardDetail({
    super.key,
    required this.foodCard,
    required this.experiences,
    required this.isSaved,
    required this.onClose,
    required this.onToggleSave,
    required this.onAddExperience,
    this.showOnlineInfoTab = true,
  });

  @override
  State<FoodCardDetail> createState() => _FoodCardDetailState();
}

class _FoodCardDetailState extends State<FoodCardDetail> {
  int _currentTabIndex = 0; 
  int _heroPageIndex = 0;
  final PageController _heroPageController = PageController();
  final TextEditingController _tagController = TextEditingController();
  
  final List<String> _mockPros = ['Service fast', 'Fresh food', 'Good portions'];
  final List<String> _mockCons = ['Busy lunch', 'Limited parking'];
  final List<String> _suggestedTags = ['Go-to spot', 'Weekend vibe', 'Cheap eats', 'Group friendly', 'Great value'];
  final List<_DemoMenuItem> _demoMenuItems = const [
    _DemoMenuItem('招牌健康餐盒', '舒肥雞胸、季節蔬菜、紫米飯', 'NT\$ 165'),
    _DemoMenuItem('炙燒牛五花餐盒', '微辣醬汁、溫泉蛋、青花菜', 'NT\$ 210'),
    _DemoMenuItem('低醣鮭魚餐盒', '烤鮭魚、花椰菜米、胡麻沙拉', 'NT\$ 240'),
  ];
  final List<_DemoReview> _demoReviews = const [
    _DemoReview('份量剛好，雞胸不乾，午餐尖峰要提早訂。', 5),
    _DemoReview('菜色清爽，價格偏中上，但外送包裝很穩。', 4),
  ];

  @override
  void dispose() {
    _heroPageController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _openExperienceEntrySheet({ExperienceCard? experienceToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      useSafeArea: true,        
      backgroundColor: Colors.transparent, 
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ExperienceEntrySheet(
            initialExperience: experienceToEdit ?? ExperienceCard(
              foodCardId: widget.foodCard.id,
              placeTitle: widget.foodCard.primaryTitle,
              placeAddress: widget.foodCard.formattedAddress,
              latitude: widget.foodCard.location?.latitude,
              longitude: widget.foodCard.location?.longitude,
              personalTags: const [],
              personalRating: 0.0,
            ),
            savedPlaceSuggestions: context.read<SavedViewModel>().experiences,
            onSave: (savedExperience, photos) async {
              if (experienceToEdit == null) {
                await context.read<SavedViewModel>().addExperience(savedExperience, photos: photos);
              } else {
                await context.read<SavedViewModel>().updateExperience(savedExperience, newPhotos: photos);
              }
              
              if (sheetContext.mounted) {
                Navigator.of(sheetContext).pop();
                widget.onAddExperience(); 
              }
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final allExperiences = context.watch<SavedViewModel>().experiences;
    
    final isSpotSavedLive = allExperiences.any((e) => 
      (e.foodCardId ?? e.placeId ?? e.placeTitle) == (widget.foodCard.id ?? widget.foodCard.primaryTitle)
    );

    var currentExperiences = allExperiences.where((e) {
      final key1 = e.foodCardId ?? e.placeId ?? e.placeTitle;
      final key2 = widget.foodCard.id ?? widget.foodCard.primaryTitle;
      return key1 == key2;
    }).toList();

    if (currentExperiences.isEmpty) {
      currentExperiences = List.from(widget.experiences);
    }

    currentExperiences.sort((a, b) {
      if (a.createdTime == null && b.createdTime == null) return 0;
      if (a.createdTime == null) return 1;
      if (b.createdTime == null) return -1;
      return b.createdTime!.compareTo(a.createdTime!); 
    });

    if (!widget.showOnlineInfoTab && currentExperiences.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeroImage(colorScheme, currentExperiences),
              _buildHeader(colorScheme),
              if (widget.showOnlineInfoTab) _buildTabs(colorScheme),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100),
                  child: widget.showOnlineInfoTab 
                    ? AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _currentTabIndex == 0 
                            ? _buildOnlineTab(colorScheme) 
                            : _buildYoursTab(colorScheme, currentExperiences),
                      )
                    : _buildYoursTab(colorScheme, currentExperiences),
                ),
              ),
            ],
          ),
          _buildBottomActionBar(colorScheme, isSpotSavedLive),
        ],
      ),
    );
  }

  Widget _buildHeroImage(
    ColorScheme colorScheme,
    List<ExperienceCard> currentExperiences,
  ) {
    ExperienceCard? heroExperience;
    for (final experience in currentExperiences) {
      if (experience.photoUrls.isNotEmpty || experience.photoPaths.isNotEmpty) {
        heroExperience = experience;
        break;
      }
    }

    final pages = <Widget>[
      _buildRestaurantPhotoPage(colorScheme, heroExperience),
      _buildMenuPreviewPage(colorScheme),
    ];

    return Stack(
      children: [
        SizedBox(
          height: 220,
          width: double.infinity,
          child: PageView(
            controller: _heroPageController,
            onPageChanged: (index) => setState(() => _heroPageIndex = index),
            children: pages,
          ),
        ),
        Container(
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.4), Colors.transparent],
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 12,
          child: Row(
            children: List.generate(
              pages.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: _heroPageIndex == index ? 18 : 7,
                height: 7,
                margin: const EdgeInsets.only(left: 5),
                decoration: BoxDecoration(
                  color: _heroPageIndex == index
                      ? colorScheme.primary
                      : colorScheme.surface.withOpacity(0.82),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 16,
          left: 16,
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorScheme.surface.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, color: colorScheme.onSurface, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRestaurantPhotoPage(
    ColorScheme colorScheme,
    ExperienceCard? heroExperience,
  ) {
    if (heroExperience != null) {
      return ExperiencePhoto(
        experience: heroExperience,
        width: MediaQuery.sizeOf(context).width,
        height: 220,
        borderRadius: 0,
      );
    }

    if (widget.foodCard.originalURL != null) {
      return Image.network(
        widget.foodCard.originalURL!,
        fit: BoxFit.cover,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (context, error, stackTrace) =>
            _buildPhotoFallback(colorScheme),
      );
    }

    return _buildPhotoFallback(colorScheme);
  }

  Widget _buildPhotoFallback(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.restaurant,
          size: 48,
          color: colorScheme.outlineVariant,
        ),
      ),
    );
  }

  Widget _buildMenuPreviewPage(ColorScheme colorScheme) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      color: colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(24, 42, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Menu preview',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _demoMenuItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _demoMenuItems[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            item.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      item.price,
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    final textTheme = Theme.of(context).textTheme;
    final rating = widget.foodCard.rating ?? 4.5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.foodCard.primaryTitle,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    ...List.generate(
                      5,
                      (index) => Icon(
                        Icons.star,
                        size: 16,
                        color: index < rating.round()
                            ? Colors.amber.shade700
                            : colorScheme.outlineVariant,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      rating.toStringAsFixed(1),
                      style: textTheme.labelLarge?.copyWith(
                        color: Colors.amber.shade800,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '426 reviews',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _HeaderFact(
                      icon: Icons.schedule,
                      text: 'Open now · until 20:30',
                      colorScheme: colorScheme,
                    ),
                    _HeaderFact(
                      icon: Icons.phone,
                      text: '03-555-1295',
                      colorScheme: colorScheme,
                    ),
                    _HeaderFact(
                      icon: Icons.payments_outlined,
                      text: '\$\$',
                      colorScheme: colorScheme,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Icon(Icons.assignment_outlined, color: colorScheme.onSurfaceVariant, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary,
            ),
            child: Icon(Icons.navigation, color: colorScheme.onPrimary, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Expanded(child: _buildTabButton("Overview", 0, colorScheme)),
            Expanded(child: _buildTabButton("My Rating", 1, colorScheme)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int index, ColorScheme colorScheme) {
    final isActive = _currentTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive ? [BoxShadow(color: colorScheme.shadow.withOpacity(0.1), blurRadius: 2)] : [],
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isActive ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineTab(ColorScheme colorScheme) {
    return Column(
      key: const ValueKey('online'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildInfoTile(
                icon: Icons.payments_outlined,
                label: 'Price range',
                value: '\$\$ · NT\$160-280',
                colorScheme: colorScheme,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildInfoTile(
                icon: Icons.timer_outlined,
                label: 'Avg. stay',
                value: '35-50 min',
                colorScheme: colorScheme,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ..._mockPros.map((tag) => _buildStatusTag(tag, true, colorScheme)),
            ..._mockCons.map((tag) => _buildStatusTag(tag, false, colorScheme)),
          ],
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('Hours & crowd', Icons.schedule, colorScheme),
        const SizedBox(height: 10),
        _buildHoursCard(colorScheme),
        const SizedBox(height: 18),
        _buildSectionTitle('Reviews', Icons.forum_outlined, colorScheme),
        const SizedBox(height: 10),
        ..._demoReviews.map((review) => _buildReviewCard(review, colorScheme)),
      ],
    );
  }

  Widget _buildRatingSummary(ColorScheme colorScheme, double rating) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                rating.toStringAsFixed(1),
                style: textTheme.titleLarge?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      Icons.star,
                      size: 17,
                      color: index < rating.round()
                          ? Colors.amber.shade700
                          : colorScheme.outlineVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '426 Google reviews · verified by Outscraper',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required ColorScheme colorScheme,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
    String title,
    IconData icon,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildHoursCard(ColorScheme colorScheme) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'Open now',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Mon-Sun 10:30-20:30',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Popular times today',
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _buildPeakBars(colorScheme),
        ],
      ),
    );
  }

  Widget _buildPeakBars(ColorScheme colorScheme) {
    const values = [0.25, 0.48, 0.88, 0.72, 0.38, 0.56];
    const labels = ['10', '11', '12', '13', '14', '18'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(values.length, (index) {
        final isPeak = values[index] > 0.8;
        return Expanded(
          child: Column(
            children: [
              Container(
                height: 54,
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 12 + values[index] * 42,
                  width: 18,
                  decoration: BoxDecoration(
                    color:
                        isPeak ? colorScheme.primary : colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                labels[index],
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildReviewCard(_DemoReview review, ColorScheme colorScheme) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(
                5,
                (index) => Icon(
                  Icons.star,
                  size: 14,
                  color: index < review.rating
                      ? Colors.amber.shade700
                      : colorScheme.outlineVariant,
                ),
              ),
              const Spacer(),
              Text(
                'Google Maps',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.text,
            style: textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTag(String text, bool isPro, ColorScheme colorScheme) {
    final bgColor = isPro ? colorScheme.tertiaryContainer : colorScheme.errorContainer;
    final textColor = isPro ? colorScheme.onTertiaryContainer : colorScheme.onErrorContainer;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }

  Widget _buildYoursTab(ColorScheme colorScheme, List<ExperienceCard> currentExperiences) {
    final textTheme = Theme.of(context).textTheme;
    final visitCount = currentExperiences.length;
    final avgRating = visitCount > 0 
        ? currentExperiences.fold(0.0, (sum, exp) => sum + exp.personalRating) / visitCount 
        : 0.0;

    return Column(
      key: const ValueKey('yours'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("YOUR AVERAGE", style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer)),
              visitCount > 0 ? Row(
                children: [
                  Text(avgRating.toStringAsFixed(1), style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary)),
                  const SizedBox(width: 8),
                  Text("$visitCount visits", style: textTheme.labelMedium?.copyWith(color: colorScheme.onPrimaryContainer)),
                ],
              ) : Text("No ratings yet", style: textTheme.labelMedium?.copyWith(fontStyle: FontStyle.italic, color: colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("YOUR MEALS", style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.outline)),
            GestureDetector(
              onTap: () => _openExperienceEntrySheet(), 
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
                child: Icon(Icons.add, color: colorScheme.onPrimary, size: 18),
              ),
            )
          ],
        ),
        const SizedBox(height: 12),
        if (visitCount == 0)
          GestureDetector(
            onTap: () => _openExperienceEntrySheet(), 
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outlineVariant, width: 1.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.add_circle_outline, size: 28, color: colorScheme.primary),
                  const SizedBox(height: 8),
                  Text("Log your first meal", style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                  Text("Record the dishes you tried and your thoughts!", style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          )
        else
          ...currentExperiences.map((exp) => _buildExperienceItem(exp, colorScheme)),
        
        const SizedBox(height: 24),
        Text("YOUR TAGS", style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.outline)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              Text("#", style: TextStyle(color: colorScheme.outline, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _tagController,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    border: InputBorder.none, 
                    hintText: "Add your own tag", 
                    hintStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.outline)
                  ),
                  onSubmitted: (val) => _handleAddNewTag(),
                ),
              ),
              GestureDetector(
                onTap: _handleAddNewTag,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
                  child: Icon(Icons.arrow_upward, color: colorScheme.onPrimary, size: 12),
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _suggestedTags.map((tag) => GestureDetector(
            onTap: () {
              setState(() {
                if (!_suggestedTags.contains(tag)) _suggestedTags.add(tag);
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border.all(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text("+ #$tag", style: textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildExperienceItem(ExperienceCard exp, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (exp.id == null) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ExperienceDetailScreen(experienceId: exp.id!),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: List.generate(5, (i) => Icon(
                        Icons.star, 
                        size: 14, 
                        color: i < exp.personalRating ? colorScheme.primary : colorScheme.surfaceContainerHigh
                      )),
                    ),
                    Row(
                      children: [
                        Text(
                          _formatRelative(exp.createdTime?.toDate() ?? DateTime.now()),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.outline),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: Icon(Icons.more_vert, size: 16, color: colorScheme.onSurfaceVariant),
                            onSelected: (value) async {
                              if (value == 'edit') {
                                _openExperienceEntrySheet(experienceToEdit: exp);
                              } else if (value == 'delete') {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Delete Meal'),
                                    content: const Text('Are you sure you want to delete this meal record?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(true),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Theme.of(context).colorScheme.error,
                                        ),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true && exp.id != null) {
                                  if (context.mounted) {
                                    await context.read<SavedViewModel>().removeExperience(exp.id!);
                                  }
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              const PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ),
                      ],
                    )
                  ],
                ),
                if (exp.personalNote != null && exp.personalNote!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(exp.personalNote!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface)),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleAddNewTag() {
    if (_tagController.text.trim().isNotEmpty) {
      setState(() {
        _suggestedTags.insert(0, _tagController.text.trim());
        _tagController.clear();
      });
    }
  }

  String _formatRelative(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return "Just now";
    if (diff.inHours == 1) return "1 hr ago";
    if (diff.inHours < 24) return "${diff.inHours} hrs ago";
    if (diff.inDays == 1) return "1 day ago";
    return "${diff.inDays} days ago";
  }

  Widget _buildBottomActionBar(ColorScheme colorScheme, bool isSpotSavedLive) {
    final showSavedStyle = widget.showOnlineInfoTab && isSpotSavedLive;

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: GestureDetector(
          onTap: () => widget.showOnlineInfoTab ? widget.onToggleSave() : _openExperienceEntrySheet(),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: showSavedStyle ? colorScheme.primaryContainer : colorScheme.primary,
              borderRadius: BorderRadius.circular(24),
              border: showSavedStyle ? Border.all(color: colorScheme.outlineVariant) : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.showOnlineInfoTab 
                      ? (isSpotSavedLive ? Icons.bookmark : Icons.bookmark_border)
                      : Icons.add,
                  color: showSavedStyle ? colorScheme.onPrimaryContainer : colorScheme.onPrimary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.showOnlineInfoTab 
                      ? (isSpotSavedLive ? "Saved to your map" : "Save this spot")
                      : "Log another meal here",
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: showSavedStyle ? colorScheme.onPrimaryContainer : colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoMenuItem {
  final String name;
  final String description;
  final String price;

  const _DemoMenuItem(this.name, this.description, this.price);
}

class _DemoReview {
  final String text;
  final int rating;

  const _DemoReview(this.text, this.rating);
}

class _HeaderFact extends StatelessWidget {
  final IconData icon;
  final String text;
  final ColorScheme colorScheme;

  const _HeaderFact({
    required this.icon,
    required this.text,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colorScheme.primary),
          const SizedBox(width: 5),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
