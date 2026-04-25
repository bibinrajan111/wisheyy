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
      onTap: _next,
      onSwipeLeft: _next,
      onSwipeRight: _previous,
      onLongPress: () => setState(() => _holdReveal = true),
      onShake: _confetti.play,
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
    final total = wish.pages.isNotEmpty ? wish.pages.length : wish.messages.length;
    if (_index < total - 1) {
      setState(() {
        _index++;
        _holdReveal = false;
      });
    }
  }

  void _previous() {
    if (_index > 0) {
      setState(() {
        _index--;
        _holdReveal = false;
      });
    }
  }

  void _performButtonAction(ButtonActionType action) {
    switch (action) {
      case ButtonActionType.nextPage:
        _next();
        break;
      case ButtonActionType.previousPage:
        _previous();
        break;
      case ButtonActionType.toggleReveal:
        setState(() => _holdReveal = !_holdReveal);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final wish = _wish;
    if (wish == null) {
      return const AdaptiveScaffold(
        title: 'Loading Wish',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AdaptiveScaffold(
      title: 'Wish Experience',
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400, maxHeight: 710),
                    child: GestureDetector(
                      onTap: wish.interactionConfig.tapEnabled ? _interaction?.onTap : null,
                      onLongPress: wish.interactionConfig.holdEnabled ? _interaction?.onLongPress : null,
                      onHorizontalDragEnd: (details) {
                        if (!wish.interactionConfig.swipeEnabled) return;
                        if (details.velocity.pixelsPerSecond.dx < 0) {
                          _interaction?.onSwipeLeft?.call();
                        } else {
                          _interaction?.onSwipeRight?.call();
                        }
                      },
                      child: StoryTransition(
                        animationType: wish.animationType,
                        child: _buildPage(wish),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: Wrap(
                  spacing: 8,
                  children: [
                    _HintChip(text: wish.interactionConfig.tapLabel, enabled: wish.interactionConfig.tapEnabled),
                    _HintChip(
                      text: wish.interactionConfig.swipeLabel,
                      enabled: wish.interactionConfig.swipeEnabled,
                    ),
                    _HintChip(text: wish.interactionConfig.holdLabel, enabled: wish.interactionConfig.holdEnabled),
                    _HintChip(
                      text: wish.interactionConfig.shakeLabel,
                      enabled: wish.interactionConfig.shakeEnabled,
                    ),
                  ],
                ),
              ),
              ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
              ),
              if (!wish.isPremium)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Created with Wisheyy'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPage(WishModel wish) {
    if (wish.pages.isEmpty) {
      return const ColoredBox(color: Colors.black);
    }
    final page = wish.pages[_index.clamp(0, wish.pages.length - 1)];
    final showText = !wish.interactionConfig.holdEnabled || _holdReveal;

    return Stack(
      fit: StackFit.expand,
      children: [
        _background(page),
        Positioned.fill(child: ColoredBox(color: Colors.black.withOpacity(0.2))),
        ...page.components.map((component) {
          return Positioned(
            left: component.x,
            top: component.y,
            child: SizedBox(
              width: component.width,
              height: component.height,
              child: switch (component.type) {
                WishComponentType.text => AnimatedOpacity(
                    opacity: showText ? 1 : 0,
                    duration: const Duration(milliseconds: 280),
                    child: Text(
                      showText ? component.value : 'Hold to reveal…',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                    ),
                  ),
                WishComponentType.image => component.value.startsWith('http')
                    ? Image.network(component.value, fit: BoxFit.cover)
                    : const SizedBox.shrink(),
                WishComponentType.button => FilledButton(
                    onPressed: () => _performButtonAction(component.actionType),
                    child: Text(component.value),
                  ),
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _background(WishPageModel page) {
    switch (page.backgroundType) {
      case WishBackgroundType.solid:
        return ColoredBox(color: _toColor(page.solidColor));
      case WishBackgroundType.gradient:
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_toColor(page.gradientStart), _toColor(page.gradientEnd)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        );
      case WishBackgroundType.image:
        if (page.backgroundImageUrl == null) return const SizedBox.shrink();
        return Image.network(page.backgroundImageUrl!, fit: BoxFit.cover);
      case WishBackgroundType.video:
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black45),
            Center(
              child: Icon(Icons.play_circle_fill_rounded, size: 86, color: Colors.white.withOpacity(0.85)),
            ),
            const Positioned(
              bottom: 14,
              left: 14,
              child: Text('Video background (premium)', style: TextStyle(color: Colors.white70)),
            ),
          ],
        );
    }
  }

  Color _toColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    return Color(int.parse('0xFF$cleaned'));
  }
}

class _HintChip extends StatelessWidget {
  const _HintChip({required this.text, required this.enabled});

  final String text;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 0.95 : 0.45,
      child: Chip(label: Text(text, style: const TextStyle(fontSize: 12))),
    );
  }
}
