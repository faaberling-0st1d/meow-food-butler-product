import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_util' as js_util;

class CurrentMapPosition {
  final double latitude;
  final double longitude;

  const CurrentMapPosition({required this.latitude, required this.longitude});
}

Future<CurrentMapPosition?> getCurrentMapPosition() async {
  final completer = Completer<CurrentMapPosition?>();

  void completeOnce(CurrentMapPosition? position) {
    if (!completer.isCompleted) {
      completer.complete(position);
    }
  }

  try {
    js_util.callMethod<void>(
      html.window.navigator.geolocation,
      'getCurrentPosition',
      [
        js_util.allowInterop((dynamic position) {
          final coords = js_util.getProperty<Object?>(position, 'coords');
          final latitude = _readNumber(coords, 'latitude');
          final longitude = _readNumber(coords, 'longitude');

          if (latitude == null || longitude == null) {
            completeOnce(null);
            return;
          }

          completeOnce(
            CurrentMapPosition(latitude: latitude, longitude: longitude),
          );
        }),
        js_util.allowInterop((dynamic _) {
          completeOnce(null);
        }),
        js_util.jsify({
          'enableHighAccuracy': true,
          'timeout': 10000,
          'maximumAge': 15000,
        }),
      ],
    );
  } catch (_) {
    completeOnce(null);
  }

  return completer.future.timeout(
    const Duration(seconds: 12),
    onTimeout: () => null,
  );
}

double? _readNumber(Object? object, String key) {
  if (object == null) return null;

  final value = js_util.getProperty<Object?>(object, key);
  if (value is num) return value.toDouble();

  return double.tryParse(value?.toString() ?? '');
}
