import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:meow_food_butler/models/experience_card.dart';

class ExperiencePhoto extends StatelessWidget {
  final ExperienceCard experience;
  final String? photoUrl;
  final String? photoPath;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;

  const ExperiencePhoto({
    super.key,
    required this.experience,
    this.photoUrl,
    this.photoPath,
    required this.width,
    required this.height,
    required this.borderRadius,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget fallbackIcon(IconData icon) {
      return Container(
        width: width,
        height: height,
        color: colorScheme.primaryContainer,
        child: Icon(icon, color: colorScheme.onPrimaryContainer),
      );
    }

    final resolvedPhotoUrl =
        photoUrl ?? _firstPhotoForExperience(experience.photoUrls);
    final resolvedPhotoPath =
        photoPath ?? _firstPhotoForExperience(experience.photoPaths);

    Widget imageForUrl(String url, {Widget? fallback}) {
      return Image.network(
        key: ValueKey(url),
        url,
        width: width,
        height: height,
        fit: fit,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (context, error, stackTrace) {
          return fallback ?? fallbackIcon(Icons.broken_image_outlined);
        },
      );
    }

    final imageKey =
        resolvedPhotoPath ?? resolvedPhotoUrl ?? 'empty-${experience.id}';

    return ClipRRect(
      key: ValueKey(imageKey),
      borderRadius: BorderRadius.circular(borderRadius),
      child: resolvedPhotoUrl != null
          ? imageForUrl(
              resolvedPhotoUrl,
              fallback: resolvedPhotoPath == null
                  ? null
                  : _StoragePathImage(
                      path: resolvedPhotoPath,
                      width: width,
                      height: height,
                      fit: fit,
                      fallback: fallbackIcon(Icons.broken_image_outlined),
                    ),
            )
          : resolvedPhotoPath != null
          ? _StoragePathImage(
              path: resolvedPhotoPath,
              width: width,
              height: height,
              fit: fit,
              fallback: fallbackIcon(Icons.broken_image_outlined),
            )
          : fallbackIcon(Icons.restaurant),
    );
  }

  String? _firstPhotoForExperience(List<String> photos) {
    if (photos.isEmpty) return null;

    final id = experience.id;
    if (id == null) return photos.first;

    for (final photo in photos) {
      if (_photoBelongsToExperience(photo, id)) return photo;
    }

    return null;
  }

  bool _photoBelongsToExperience(String photo, String id) {
    final decoded = Uri.decodeFull(photo);
    return decoded.contains('/experiences/$id/') ||
        decoded.contains('experiences/$id/');
  }
}

class _StoragePathImage extends StatefulWidget {
  final String path;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget fallback;

  const _StoragePathImage({
    required this.path,
    required this.width,
    required this.height,
    required this.fit,
    required this.fallback,
  });

  @override
  State<_StoragePathImage> createState() => _StoragePathImageState();
}

class _StoragePathImageState extends State<_StoragePathImage> {
  late Future<String> _urlFuture;

  @override
  void initState() {
    super.initState();
    _urlFuture = FirebaseStorage.instance.ref(widget.path).getDownloadURL();
  }

  @override
  void didUpdateWidget(_StoragePathImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _urlFuture = FirebaseStorage.instance.ref(widget.path).getDownloadURL();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _urlFuture,
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (url == null) return widget.fallback;

        return Image.network(
          key: ValueKey(url),
          url,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
          errorBuilder: (context, error, stackTrace) => widget.fallback,
        );
      },
    );
  }
}
