import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:meow_food_butler/models/experience_card.dart';

class ExperiencePhoto extends StatelessWidget {
  final ExperienceCard experience;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;

  const ExperiencePhoto({
    super.key,
    required this.experience,
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

    final photoUrl = experience.photoUrls.isEmpty
        ? null
        : experience.photoUrls.first;
    final photoPath = experience.photoPaths.isEmpty
        ? null
        : experience.photoPaths.first;

    Widget imageForUrl(String url, {Widget? fallback}) {
      return Image.network(
        key: ValueKey(url),
        url,
        width: width,
        height: height,
        fit: fit,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        errorBuilder: (context, error, stackTrace) {
          return fallback ?? fallbackIcon(Icons.broken_image_outlined);
        },
      );
    }

    final imageKey = photoPath ?? photoUrl ?? 'empty-${experience.id}';

    return ClipRRect(
      key: ValueKey(imageKey),
      borderRadius: BorderRadius.circular(borderRadius),
      child: photoUrl != null
          ? imageForUrl(
              photoUrl,
              fallback: photoPath == null
                  ? null
                  : _StoragePathImage(
                      path: photoPath,
                      width: width,
                      height: height,
                      fit: fit,
                      fallback: fallbackIcon(Icons.broken_image_outlined),
                    ),
            )
          : photoPath != null
          ? _StoragePathImage(
              path: photoPath,
              width: width,
              height: height,
              fit: fit,
              fallback: fallbackIcon(Icons.broken_image_outlined),
            )
          : fallbackIcon(Icons.restaurant),
    );
  }
}

class _StoragePathImage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: FirebaseStorage.instance.ref(path).getDownloadURL(),
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(
            width: width,
            height: height,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (url == null) return fallback;

        return Image.network(
          key: ValueKey(url),
          url,
          width: width,
          height: height,
          fit: fit,
          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
          errorBuilder: (context, error, stackTrace) => fallback,
        );
      },
    );
  }
}
