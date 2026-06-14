import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

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
    web.window.navigator.geolocation.getCurrentPosition(
      (web.GeolocationPosition position) {
        final coords = position.coords;
        completeOnce(
          CurrentMapPosition(
            latitude: coords.latitude,
            longitude: coords.longitude,
          ),
        );
      }.toJS,
      (web.GeolocationPositionError _) {
        completeOnce(null);
      }.toJS,
      web.PositionOptions(
        enableHighAccuracy: true,
        timeout: 10000,
        maximumAge: 15000,
      ),
    );
  } catch (_) {
    completeOnce(null);
  }

  return completer.future.timeout(
    const Duration(seconds: 12),
    onTimeout: () => null,
  );
}
