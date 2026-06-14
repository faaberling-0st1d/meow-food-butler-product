import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:meow_food_butler/models/experience_card.dart';
import 'package:meow_food_butler/models/food_card.dart';
import 'package:meow_food_butler/views/saved/food_card_detail.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

enum MapSheetMode { imported, myPlaces }

class RestaurantListSheet extends StatefulWidget {
  static const double minSize = 0.07;
  static const double middleSize = 0.42;
  static const double initialSize = minSize;
  static const double maxSize = 0.86;
  static const List<double> snapSizes = [minSize, middleSize, maxSize];

  final DraggableScrollableController controller;
  final List<ExperienceCard> experiences;
  final MapSheetMode mode;
  final int importedCount;
  final int myPlacesCount;
  final String? selectedExperienceId;
  final String Function(ExperienceCard experience) markerIdFor;
  final ValueChanged<MapSheetMode> onModeChanged;
  final ValueChanged<ExperienceCard> onExperienceSelected;
  final ValueChanged<ExperienceCard> onExperienceDetailRequested;
  const RestaurantListSheet({
    super.key,
    required this.controller,
    required this.experiences,
    required this.mode,
    required this.importedCount,
    required this.myPlacesCount,
    required this.selectedExperienceId,
    required this.markerIdFor,
    required this.onModeChanged,
    required this.onExperienceSelected,
    required this.onExperienceDetailRequested,
  });

  @override
  State<RestaurantListSheet> createState() => _RestaurantListSheetState();
}

class _RestaurantListSheetState extends State<RestaurantListSheet> {
  static const double _headerScrollExtent = 132;
  static const double _estimatedCardExtent = 134;

  ScrollController? _scrollController;
  String? _lastAutoScrolledId;

  @override
  void didUpdateWidget(covariant RestaurantListSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.selectedExperienceId != oldWidget.selectedExperienceId) {
      _scheduleScrollToSelected();
    }
  }

  void _scheduleScrollToSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToSelectedExperience();
    });
  }

  Future<void> _scrollToSelectedExperience() async {
    final selectedId = widget.selectedExperienceId;
    if (selectedId == null || selectedId == _lastAutoScrolledId) return;

    final selectedIndex = widget.experiences.indexWhere(
      (experience) => widget.markerIdFor(experience) == selectedId,
    );
    if (selectedIndex < 0) return;

    _lastAutoScrolledId = selectedId;

    if (widget.controller.isAttached &&
        widget.controller.size < RestaurantListSheet.middleSize) {
      await widget.controller.animateTo(
        RestaurantListSheet.middleSize,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }

    final scrollController = _scrollController;
    if (scrollController == null || !scrollController.hasClients) return;

    final maxScroll = scrollController.position.maxScrollExtent;
    final target = (_headerScrollExtent + selectedIndex * _estimatedCardExtent)
        .clamp(0.0, maxScroll);

    await scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _showRestaurantDetail(BuildContext context, ExperienceCard experience) {
    final relatedFoodCard = FoodCard(
      id: experience.foodCardId,
      originalURL: experience.photoUrls.isNotEmpty
          ? experience.photoUrls.first
          : experience.originalURL,
      formattedAddress: experience.placeAddress,
      rating: experience.personalRating,
      displayNames: [
        DisplayName(
          title: experience.placeTitle ?? 'Unnamed restaurant',
          languageCode: 'en',
        ),
      ],
      location: experience.latitude != null && experience.longitude != null
          ? LocationCoordinate(
              latitude: experience.latitude,
              longitude: experience.longitude,
            )
          : null,
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 1.0,
          minChildSize: 0.5,
          maxChildSize: 1.0,
          builder: (_, controller) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: FoodCardDetail(
                foodCard: relatedFoodCard,
                experiences: [experience],
                isSaved: experience.isDone,
                onClose: () => Navigator.pop(context),
                onToggleSave: () {},
                onAddExperience: () {},
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.bottomCenter,
      child: PointerInterceptor(
        child: DraggableScrollableSheet(
          controller: widget.controller,
          expand: false,
          snap: true,
          snapSizes: RestaurantListSheet.snapSizes,
          initialChildSize: RestaurantListSheet.initialSize,
          minChildSize: RestaurantListSheet.minSize,
          maxChildSize: RestaurantListSheet.maxSize,
          builder: (context, scrollController) {
            _scrollController = scrollController;
            return ScrollConfiguration(
              behavior: const _MapSheetScrollBehavior(),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.18),
                      blurRadius: 22,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: CustomScrollView(
                        controller: scrollController,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        slivers: [
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _SheetHeaderDelegate(
                              count: widget.experiences.length,
                              mode: widget.mode,
                              importedCount: widget.importedCount,
                              myPlacesCount: widget.myPlacesCount,
                              onModeChanged: widget.onModeChanged,
                              controller: widget.controller,
                              backgroundColor: colorScheme.surface,
                            ),
                          ),
                          if (widget.experiences.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: _EmptyMapSheetContent(mode: widget.mode),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                              sliver: SliverList.separated(
                                itemCount: widget.experiences.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final experience = widget.experiences[index];
                                  final selected =
                                      widget.markerIdFor(experience) ==
                                      widget.selectedExperienceId;

                                  return _MapRestaurantCard(
                                    experience: experience,
                                    selected: selected,
                                    mode: widget.mode,
                                    onTap: () {
                                      widget.onExperienceDetailRequested(
                                        experience,
                                      );
                                      _showRestaurantDetail(context, experience);
                                    },
                                    onLocate: () =>
                                        widget.onExperienceSelected(experience),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MapSheetScrollBehavior extends MaterialScrollBehavior {
  const _MapSheetScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

class _SheetHeaderDelegate extends SliverPersistentHeaderDelegate {
  final int count;
  final MapSheetMode mode;
  final int importedCount;
  final int myPlacesCount;
  final ValueChanged<MapSheetMode> onModeChanged;
  final DraggableScrollableController controller;
  final Color backgroundColor;

  const _SheetHeaderDelegate({
    required this.count,
    required this.mode,
    required this.importedCount,
    required this.myPlacesCount,
    required this.onModeChanged,
    required this.controller,
    required this.backgroundColor,
  });

  static const double _height = 132;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: Theme.of(context)
                      .colorScheme
                      .shadow
                      .withValues(alpha: 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: _SheetHeader(
        count: count,
        mode: mode,
        importedCount: importedCount,
        myPlacesCount: myPlacesCount,
        onModeChanged: onModeChanged,
        controller: controller,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SheetHeaderDelegate oldDelegate) {
    return count != oldDelegate.count ||
        mode != oldDelegate.mode ||
        importedCount != oldDelegate.importedCount ||
        myPlacesCount != oldDelegate.myPlacesCount ||
        onModeChanged != oldDelegate.onModeChanged ||
        controller != oldDelegate.controller ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}

class _SheetHeader extends StatelessWidget {
  final int count;
  final MapSheetMode mode;
  final int importedCount;
  final int myPlacesCount;
  final ValueChanged<MapSheetMode> onModeChanged;
  final DraggableScrollableController controller;

  const _SheetHeader({
    required this.count,
    required this.mode,
    required this.importedCount,
    required this.myPlacesCount,
    required this.onModeChanged,
    required this.controller,
  });

  void _dragSheet(BuildContext context, DragUpdateDetails details) {
    if (!controller.isAttached) return;
    final height = MediaQuery.sizeOf(context).height;
    final delta = details.primaryDelta ?? 0;
    final nextSize = (controller.size - delta / height).clamp(
      RestaurantListSheet.minSize,
      RestaurantListSheet.maxSize,
    );
    controller.jumpTo(nextSize);
  }

  void _snapSheet() {
    if (!controller.isAttached) return;
    final current = controller.size;
    final target = RestaurantListSheet.snapSizes.reduce((a, b) {
      return (current - a).abs() < (current - b).abs() ? a : b;
    });
    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = mode == MapSheetMode.imported
        ? '$count imported place${count == 1 ? '' : 's'}'
        : '$count place${count == 1 ? '' : 's'} on your food map';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) => _dragSheet(context, details),
      onVerticalDragEnd: (_) => _snapSheet(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  mode == MapSheetMode.imported
                      ? Icons.auto_awesome
                      : Icons.place,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _MapSheetSegmentedControl(
              mode: mode,
              importedCount: importedCount,
              myPlacesCount: myPlacesCount,
              onChanged: onModeChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _MapSheetSegmentedControl extends StatelessWidget {
  final MapSheetMode mode;
  final int importedCount;
  final int myPlacesCount;
  final ValueChanged<MapSheetMode> onChanged;

  const _MapSheetSegmentedControl({
    required this.mode,
    required this.importedCount,
    required this.myPlacesCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          _SegmentButton(
            label: 'Imported',
            count: importedCount,
            selected: mode == MapSheetMode.imported,
            onTap: () => onChanged(MapSheetMode.imported),
          ),
          _SegmentButton(
            label: 'My Places',
            count: myPlacesCount,
            selected: mode == MapSheetMode.myPlaces,
            onTap: () => onChanged(MapSheetMode.myPlaces),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            '$label  $count',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _MapRestaurantCard extends StatelessWidget {
  final ExperienceCard experience;
  final bool selected;
  final MapSheetMode mode;
  final VoidCallback onTap;
  final VoidCallback onLocate;

  const _MapRestaurantCard({
    required this.experience,
    required this.selected,
    required this.mode,
    required this.onTap,
    required this.onLocate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final imageUrl = experience.photoUrls.isEmpty
        ? null
        : experience.photoUrls.first;

    return AnimatedScale(
      scale: selected ? 1.015 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: selected ? const Offset(0, -0.025) : Offset.zero,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Material(
          color: selected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onLocate,
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                  width: selected ? 2 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.22),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 撌阡???嚗歲閰喟敦鞈?
                  InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(14),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: imageUrl == null
                          ? Container(
                              width: 70,
                              height: 70,
                              color: colorScheme.primary,
                              child: Icon(
                                Icons.restaurant,
                                color: colorScheme.onPrimary,
                              ),
                            )
                          : Image.network(
                              imageUrl,
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                              webHtmlElementStrategy:
                                  WebHtmlElementStrategy.prefer,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                width: 70,
                                height: 70,
                                color: colorScheme.primary,
                                child: Icon(
                                  Icons.restaurant,
                                  color: colorScheme.onPrimary,
                                ),
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // 銝剝???嚗歲閰喟敦鞈?
                  Expanded(
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              experience.placeTitle ?? 'Unnamed restaurant',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  mode == MapSheetMode.imported
                                      ? Icons.link
                                      : Icons.star,
                                  size: 16,
                                  color: mode == MapSheetMode.imported
                                      ? colorScheme.primary
                                      : Colors.amber.shade700,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  mode == MapSheetMode.imported
                                      ? 'From import'
                                      : experience.personalRating
                                            .toStringAsFixed(1),
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: mode == MapSheetMode.imported
                                        ? colorScheme.primary
                                        : Colors.amber.shade800,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (experience.region?.isNotEmpty == true) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    experience.region!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (experience.placeAddress?.isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 5),
                              Text(
                                experience.placeAddress!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            if (experience.personalTags.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children:
                                    experience.personalTags.take(3).map((tag) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surface,
                                      borderRadius: BorderRadius.circular(99),
                                      border: Border.all(
                                        color: colorScheme.outlineVariant,
                                      ),
                                    ),
                                    child: Text(
                                      '#$tag',
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ?喲? icon嚗摰?
                  IconButton(
                    onPressed: onLocate,
                    icon: Icon(
                      Icons.near_me,
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    tooltip: 'Show on map',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyMapSheetContent extends StatelessWidget {
  final MapSheetMode mode;

  const _EmptyMapSheetContent({required this.mode});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isImported = mode == MapSheetMode.imported;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isImported ? Icons.auto_awesome_outlined : Icons.map_outlined,
            size: 58,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            isImported
                ? 'No imported places yet'
                : 'No places on your food map yet',
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            isImported
                ? 'Paste an Instagram or food URL to turn mentioned restaurants into map cards.'
                : 'Log a meal with a place or save a restaurant to show it here.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
