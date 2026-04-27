import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../animations/story_transition.dart';
import '../interactions/interaction_handler.dart';
import '../models/wish_model.dart';
import '../services/wish_repository.dart';
import '../widgets/adaptive_scaffold.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.wishId});

  final String wishId;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final WishRepository _repository;
  late final ConfettiController _confetti;

  WishModel? _wish;
  InteractionHandler? _interaction;
  int _index = 0;
  bool _holdReveal = false;
  bool _swipeReveal = false;
  bool _tapReveal = false;
  bool _shakeReveal = false;

  @override
  void initState() {
    super.initState();
    _repository = WishRepository(FirebaseFirestore.instance);
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    unawaited(_loadWish());
  }

  Future<void> _loadWish() async {
    final wish = await _repository.getWish(widget.wishId);
    _interaction = InteractionHandler(
      onTap: () {
        setState(() => _tapReveal = true);
      },
      onSwipeLeft: () {
        setState(() => _swipeReveal = true);
        _next();
      },
      onSwipeRight: () {
        setState(() => _swipeReveal = true);
        _previous();
      },
      onLongPress: () => setState(() => _holdReveal = true),
      onShake: () {
        _confetti.play();
        setState(() => _shakeReveal = true);
      },
    )..startShakeListening();

    if (mounted) setState(() => _wish = wish);
  }

  @override
  void dispose() {
    _interaction?.dispose();
    _confetti.dispose();
    super.dispose();
  }

  void _next() {
    final wish = _wish;
    if (wish == null) return;
    if (_index < wish.pages.length - 1) {
      setState(() {
        _index++;
        _resetRevealStates();
      });
    }
  }

  void _previous() {
    if (_index > 0) {
      setState(() {
        _index--;
        _resetRevealStates();
      });
    }
  }

  void _resetRevealStates() {
    _holdReveal = false;
    _swipeReveal = false;
    _tapReveal = false;
    _shakeReveal = false;
  }

  void _runButton(ButtonActionType action) {
    switch (action) {
      case ButtonActionType.nextPage:
        _next();
        break;
      case ButtonActionType.previousPage:
        _previous();
        break;
      case ButtonActionType.toggleReveal:
        setState(() => _tapReveal = !_tapReveal);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final wish = _wish;
    if (wish == null) {
      return const AdaptiveScaffold(title: 'Loading Wish', body: Center(child: CircularProgressIndicator()));
    }

    if (wish.pages.isEmpty) {
      return const AdaptiveScaffold(title: 'Wish Experience', body: Center(child: Text('No pages to display')));
    }
    final page = wish.pages[_index.clamp(0, wish.pages.length - 1)];

    return AdaptiveScaffold(
      title: 'Wish Experience',
      body: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390, maxHeight: 700),
                child: GestureDetector(
                  onTap: _interaction?.onTap,
                  onLongPress: _interaction?.onLongPress,
                  onHorizontalDragEnd: (details) {
                    if (details.velocity.pixelsPerSecond.dx < 0) {
                      _interaction?.onSwipeLeft?.call();
                    } else {
                      _interaction?.onSwipeRight?.call();
                    }
                  },
                  child: StoryTransition(animationType: wish.animationType, child: _buildPage(page)),
                ),
              ),
            ),
          ),
          ConfettiWidget(confettiController: _confetti, blastDirectionality: BlastDirectionality.explosive),
          if (!wish.isPremium)
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(8)),
                child: const Text('Created with Wisheyy'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPage(WishPageModel page) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _background(page),
        _finishOverlay(page.finish),
        ...page.components.map((c) {
          final visible = _isVisible(c);
          if (!visible) return const SizedBox.shrink();
          return Positioned(
            left: c.x,
            top: c.y,
            child: SizedBox(
              width: c.width,
              height: c.height,
              child: switch (c.type) {
                WishComponentType.text => Text(
                    c.value,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                WishComponentType.image => c.value.startsWith('http') ? Image.network(c.value, fit: BoxFit.cover) : const SizedBox.shrink(),
                WishComponentType.button => FilledButton.icon(
                    onPressed: () => _runButton(c.actionType),
                    icon: Icon(_triggerIcon(c.revealTrigger), size: 16),
                    label: Text(c.value),
                  ),
              },
            ),
          );
        }),
      ],
    );
  }

  bool _isVisible(WishComponentModel c) {
    switch (c.revealTrigger) {
      case RevealTrigger.none:
        return true;
      case RevealTrigger.tap:
        return _tapReveal;
      case RevealTrigger.hold:
        return _holdReveal;
      case RevealTrigger.swipe:
        return _swipeReveal;
      case RevealTrigger.shake:
        return _shakeReveal;
    }
  }

  IconData _triggerIcon(RevealTrigger t) {
    switch (t) {
      case RevealTrigger.none:
        return Icons.smart_button;
      case RevealTrigger.tap:
        return Icons.touch_app;
      case RevealTrigger.hold:
        return Icons.pan_tool_alt;
      case RevealTrigger.swipe:
        return Icons.swipe;
      case RevealTrigger.shake:
        return Icons.vibration;
    }
  }

  Widget _background(WishPageModel page) {
    switch (page.backgroundType) {
      case WishBackgroundType.solid:
        return ColoredBox(color: _hex(page.solidColor));
      case WishBackgroundType.gradient:
        return DecoratedBox(
          decoration: BoxDecoration(gradient: LinearGradient(colors: [_hex(page.gradientStart), _hex(page.gradientEnd)])),
        );
      case WishBackgroundType.image:
        if (page.backgroundImageUrl == null) return const ColoredBox(color: Colors.black12);
        return Image.network(page.backgroundImageUrl!, fit: BoxFit.cover);
      case WishBackgroundType.video:
        return const Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: Colors.black38)),
            Center(child: Icon(Icons.play_circle_fill_rounded, size: 90, color: Colors.white70)),
          ],
        );
    }
  }

  Widget _finishOverlay(FinishType finish) {
    switch (finish) {
      case FinishType.normal:
        return const SizedBox.shrink();
      case FinishType.matte:
        return ColoredBox(color: Colors.black.withOpacity(0.16));
      case FinishType.metallic:
        return IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.14), Colors.transparent, Colors.white.withOpacity(0.08)],
              ),
            ),
          ),
        );
    }
  }

  Color _hex(String value) => Color(int.parse('0xFF${value.replaceAll('#', '')}'));
}
