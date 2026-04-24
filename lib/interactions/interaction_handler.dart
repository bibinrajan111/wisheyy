import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';

class InteractionHandler {
  InteractionHandler({
    this.onTap,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onLongPress,
    this.onShake,
    this.shakeThreshold = 17,
  });

  final VoidCallback? onTap;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onLongPress;
  final VoidCallback? onShake;
  final double shakeThreshold;

  StreamSubscription<AccelerometerEvent>? _accSub;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);

  void startShakeListening() {
    _accSub ??= accelerometerEventStream().listen((event) {
      final magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      final now = DateTime.now();
      if (magnitude > shakeThreshold && now.difference(_lastShake).inMilliseconds > 900) {
        _lastShake = now;
        onShake?.call();
      }
    });
  }

  void stopShakeListening() {
    _accSub?.cancel();
    _accSub = null;
  }

  void dispose() => stopShakeListening();
}
