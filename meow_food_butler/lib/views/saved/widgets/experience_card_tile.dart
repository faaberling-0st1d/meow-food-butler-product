import 'package:flutter/material.dart';
import 'package:meow_food_butler/models/experience_card.dart';
import 'package:meow_food_butler/views/saved/widgets/experience_photo.dart';

/// A single dining-experience card, shared by the Saved screen list and the chat
/// assistant (`/latest-card`). Tapping it is the caller's responsibility via
/// [onTap] (both call sites push `ExperienceDetailScreen`).
///
/// [onEdit] / [onDelete] are optional: the edit/delete popup only appears when at
/// least one is provided, so the chat can show a tap-only card.
class ExperienceCardTile extends StatelessWidget {
  final ExperienceCard experience;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ExperienceCardTile({
    super.key,
    required this.experience,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  bool get _showMenu => onEdit != null || onDelete != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateText = _formatTaiwanDate(experience.createdTime.toDate());

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExperiencePhoto(
                    key: ValueKey(
                      '${experience.id}-${experience.photoPaths.firstOrNull ?? experience.photoUrls.firstOrNull ?? 'empty'}',
                    ),
                    experience: experience,
                    width: 56,
                    height: 56,
                    borderRadius: 14,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          experience.placeTitle ?? 'Unknown Food Spot',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _MiniStarRow(rating: experience.personalRating),
                            const SizedBox(width: 4),
                            Text(
                              experience.personalRating.toStringAsFixed(1),
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: Colors.amber.shade800,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              dateText,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_showMenu)
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') {
                          onEdit?.call();
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

                          if (confirm == true) {
                            onDelete?.call();
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        if (onEdit != null)
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        if (onDelete != null)
                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                ],
              ),
              if (experience.personalNote?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  experience.personalNote!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              if (experience.personalTags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: experience.personalTags
                      .map(
                        (tag) => Chip(
                          label: Text('#$tag'),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _formatTaiwanDate(DateTime date) {
  final taiwanTime = date.toUtc().add(const Duration(hours: 8));
  final year = taiwanTime.year.toString();
  final month = taiwanTime.month.toString().padLeft(2, '0');
  final day = taiwanTime.day.toString().padLeft(2, '0');
  return '$year/$month/$day';
}

class _MiniStarRow extends StatelessWidget {
  final double rating;

  const _MiniStarRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        5,
        (index) => Padding(
          padding: const EdgeInsets.only(right: 1),
          child: _MiniPartialStar(fill: (rating - index).clamp(0.0, 1.0)),
        ),
      ),
    );
  }
}

class _MiniPartialStar extends StatelessWidget {
  final double fill;

  const _MiniPartialStar({required this.fill});

  @override
  Widget build(BuildContext context) {
    const size = 14.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Icon(Icons.star_border, size: size, color: Colors.blueGrey.shade200),
          ClipRect(
            clipper: _WidthClipper(fill),
            child: Icon(Icons.star, size: size, color: Colors.amber.shade600),
          ),
        ],
      ),
    );
  }
}

class _WidthClipper extends CustomClipper<Rect> {
  final double factor;

  const _WidthClipper(this.factor);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * factor, size.height);
  }

  @override
  bool shouldReclip(_WidthClipper oldClipper) => oldClipper.factor != factor;
}
