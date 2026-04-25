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

    if (mounted) {
      setState(() => _wish = wish);
    }
  }

  void _next() {
    final wish = _wish;
    if (wish == null) return;
    final totalPages = wish.pages.isNotEmpty ? wish.pages.length : wish.messages.length;
    if (_index < totalPages - 1) {
      setState(() {
        _holdReveal = false;
        _index++;
      });
    }
  }

  void _previous() {
    if (_index > 0) {
      setState(() {
        _holdReveal = false;
        _index--;
      });
    }
  }

  @override
  void dispose() {
    _interaction?.dispose();
    _confetti.dispose();
    super.dispose();
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
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          GestureDetector(
            onTap: wish.interactionConfig.tapEnabled ? _interaction?.onTap : null,
            onHorizontalDragEnd: (details) {
              if (!wish.interactionConfig.swipeEnabled) return;
              if (details.velocity.pixelsPerSecond.dx < 0) {
                _interaction?.onSwipeLeft?.call();
              } else {
                _interaction?.onSwipeRight?.call();
              }
            },
            onLongPress: wish.interactionConfig.holdEnabled ? _interaction?.onLongPress : null,
            child: SizedBox.expand(
              child: StoryTransition(
                animationType: wish.animationType,
                child: _buildSlide(wish),
              ),
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
              child: Opacity(
                opacity: 0.8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text('Created with Wisheyy'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSlide(WishModel wish) {
    if (wish.pages.isNotEmpty) {
      final page = wish.pages[_index.clamp(0, wish.pages.length - 1)];
      return _buildPageSlide(page, wish);
    }

    final message = wish.messages[_index];
    final showText = !wish.interactionConfig.holdEnabled || _holdReveal;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(int.parse('0xFF${wish.theme.replaceAll('#', '')}')), Colors.black],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (wish.photos.isNotEmpty)
            Image.network(wish.photos[_index % wish.photos.length], fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.35)),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedOpacity(
                opacity: showText ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: Text(
                  showText ? message : 'Hold to reveal…',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageSlide(WishPageModel page, WishModel wish) {
    final start = _parseHex(page.gradientStart, fallback: const Color(0xFF6E56F8));
    final end = _parseHex(page.gradientEnd, fallback: Colors.black);
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: page.backgroundType == WishBackgroundType.gradient
                ? LinearGradient(colors: [start, end], begin: Alignment.topCenter, end: Alignment.bottomCenter)
                : null,
          ),
          child: const SizedBox.expand(),
        ),
        if (page.backgroundType == WishBackgroundType.image && page.backgroundImageUrl != null)
          Image.network(page.backgroundImageUrl!, fit: BoxFit.cover),
        Container(color: Colors.black.withOpacity(0.25)),
        ...page.components.map((component) {
          final showText = !wish.interactionConfig.holdEnabled || _holdReveal;
          return Positioned(
            left: component.x,
            top: component.y,
            child: SizedBox(
              width: component.width,
              height: component.height,
              child: switch (component.type) {
                WishComponentType.text => AnimatedOpacity(
                    opacity: showText ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      showText ? component.value : 'Hold to reveal…',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                WishComponentType.image => component.value.startsWith('http')
                    ? Image.network(component.value, fit: BoxFit.cover)
                    : const SizedBox.shrink(),
                WishComponentType.button => FilledButton(onPressed: () {}, child: Text(component.value)),
              },
            ),
          );
        }),
      ],
    );
  }

  Color _parseHex(String hex, {Color fallback = Colors.white}) {
    final raw = hex.replaceAll('#', '').trim();
    if (raw.length != 6) return fallback;
    return Color(int.parse('0xFF$raw'));
  }
}
