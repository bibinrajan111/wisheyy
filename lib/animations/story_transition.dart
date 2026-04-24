import 'package:flutter/material.dart';

import '../models/wish_model.dart';

class StoryTransition extends StatelessWidget {
  const StoryTransition({
    super.key,
    required this.animationType,
    required this.child,
  });

  final AnimationType animationType;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    switch (animationType) {
      case AnimationType.fade:
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: child,
        );
      case AnimationType.slide:
        return TweenAnimationBuilder<Offset>(
          duration: const Duration(milliseconds: 350),
          tween: Tween(begin: const Offset(0.2, 0), end: Offset.zero),
          builder: (_, offset, c) => Transform.translate(
            offset: Offset(offset.dx * 200, 0),
            child: Opacity(opacity: 1 - offset.dx.abs(), child: c),
          ),
          child: child,
        );
      case AnimationType.zoom:
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 350),
          tween: Tween(begin: 0.92, end: 1),
          builder: (_, scale, c) => Transform.scale(scale: scale, child: c),
          child: child,
        );
    }
  }
}
