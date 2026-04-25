import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/wish_model.dart';
import '../services/share_service.dart';
import '../services/storage_service.dart';
import '../services/wish_repository.dart';
import '../widgets/adaptive_scaffold.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.templateType});

  final TemplateType templateType;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final _picker = ImagePicker();
  final _messageController = TextEditingController();
  final _componentTextController = TextEditingController();
  final _startColorController = TextEditingController(text: '#6E56F8');
  final _endColorController = TextEditingController(text: '#140B33');

  final _messages = <String>[];
  final _picked = <XFile>[];
  final _pages = <WishPageModel>[];

  int _currentPage = 0;
  String? _selectedComponentId;
  AnimationType _animationType = AnimationType.fade;
  String _theme = '#6E56F8';
  bool _openWhenMode = false;
  bool _saving = false;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _pages.add(_createPage());
  }

  WishPageModel _createPage() {
    return WishPageModel(
      id: const Uuid().v4(),
      backgroundType: WishBackgroundType.gradient,
      gradientStart: _startColorController.text,
      gradientEnd: _endColorController.text,
      components: const [],
    );
  }

  Future<void> _pickImage() async {
    if (_picked.length >= 10) return;

    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;
    setState(() => _picked.add(image));
  }

  Future<void> _addBackgroundImageToCurrentPage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;
    setState(() => _picked.add(image));

    final page = _pages[_currentPage];
    final updated = page.copyWith(backgroundType: WishBackgroundType.image, backgroundImageUrl: image.path);
    setState(() => _pages[_currentPage] = updated);
  }

  void _addPage() {
    setState(() {
      _pages.add(_createPage());
      _currentPage = _pages.length - 1;
      _selectedComponentId = null;
    });
  }

  void _addComponent(WishComponentType type) {
    final page = _pages[_currentPage];
    final defaultValue = switch (type) {
      WishComponentType.text => _componentTextController.text.trim().isEmpty
          ? 'Your message here'
          : _componentTextController.text.trim(),
      WishComponentType.image => _picked.isNotEmpty ? _picked.first.path : '',
      WishComponentType.button => 'Tap me',
    };

    final component = WishComponentModel(
      id: const Uuid().v4(),
      type: type,
      value: defaultValue,
      x: 40,
      y: 40,
      width: type == WishComponentType.text ? 220 : 170,
      height: type == WishComponentType.image ? 140 : 60,
    );

    setState(() {
      _pages[_currentPage] = page.copyWith(components: [...page.components, component]);
      _selectedComponentId = component.id;
    });
  }

  void _updateSelectedComponent(WishComponentModel Function(WishComponentModel) map) {
    final selectedId = _selectedComponentId;
    if (selectedId == null) return;
    final page = _pages[_currentPage];
    final components = page.components
        .map((c) => c.id == selectedId ? map(c) : c)
        .toList(growable: false);
    setState(() => _pages[_currentPage] = page.copyWith(components: components));
  }

  Future<void> _saveWish() async {
    if (_pages.isEmpty || _pages.every((p) => p.components.isEmpty)) {
      _showMessage('Please add at least one component to a page.');
      return;
    }

    setState(() => _saving = true);

    try {
      final id = const Uuid().v4();
      final storage = StorageService(FirebaseStorage.instance);
      final repository = WishRepository(FirebaseFirestore.instance);
      final urls = <String>[];

      for (var i = 0; i < _picked.length; i++) {
        final bytes = await _picked[i].readAsBytes();
        urls.add(await storage.uploadWishImage(wishId: id, file: bytes, index: i));
      }

      final pages = _pages.map((page) {
        var mappedImage = page.backgroundImageUrl;
        if (mappedImage != null && mappedImage.isNotEmpty && !mappedImage.startsWith('http')) {
          final idx = _picked.indexWhere((f) => f.path == mappedImage);
          if (idx >= 0 && idx < urls.length) {
            mappedImage = urls[idx];
          }
        }

        final components = page.components.map((component) {
          if (component.type != WishComponentType.image || component.value.startsWith('http')) {
            return component;
          }
          final idx = _picked.indexWhere((f) => f.path == component.value);
          if (idx >= 0 && idx < urls.length) {
            return component.copyWith(value: urls[idx]);
          }
          return component;
        }).toList();

        return page.copyWith(backgroundImageUrl: mappedImage, components: components);
      }).toList();

      final fallbackMessages = pages
          .map((p) => p.components.where((c) => c.type == WishComponentType.text).map((e) => e.value).join(' '))
          .where((text) => text.trim().isNotEmpty)
          .toList();

      final wish = WishModel(
        id: id,
        templateType: widget.templateType,
        photos: urls,
        messages: fallbackMessages.isNotEmpty ? fallbackMessages : ['A special wish for you'],
        theme: _theme,
        animationType: _animationType,
        musicUrl: null,
        interactionConfig: InteractionConfig(
          tapEnabled: true,
          swipeEnabled: true,
          holdEnabled: _openWhenMode,
          shakeEnabled: widget.templateType == TemplateType.birthday || _openWhenMode,
        ),
        createdAt: DateTime.now(),
        pages: pages,
        isPremium: _isPremium,
      );

      await repository.saveWish(wish);
      if (!mounted) return;

      final shareUrl = ShareService().buildWishUrl(id);
      _showMessage('Ready to share: $shareUrl');
      context.go('/player/$id');
    } catch (e) {
      _showMessage('Unable to create wish right now. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _componentTextController.dispose();
    _startColorController.dispose();
    _endColorController.dispose();
    super.dispose();
  }

  Color _parseHex(String hex, {Color fallback = const Color(0xFF6E56F8)}) {
    final raw = hex.replaceAll('#', '').trim();
    if (raw.length != 6) return fallback;
    return Color(int.parse('0xFF$raw'));
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];

    return AdaptiveScaffold(
      title: 'Editor • ${widget.templateType.name}',
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _addPage,
                      icon: const Icon(Icons.add_box_outlined),
                      label: const Text('Add Page'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text('Media (${_picked.length})'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _addComponent(WishComponentType.text),
                      icon: const Icon(Icons.text_fields_rounded),
                      label: const Text('Text'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _addComponent(WishComponentType.image),
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Image'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _addComponent(WishComponentType.button),
                      icon: const Icon(Icons.smart_button_outlined),
                      label: const Text('Button'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _componentTextController,
                  decoration: const InputDecoration(labelText: 'Text component content'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: List.generate(_pages.length, (index) {
                    return ChoiceChip(
                      label: Text('Page ${index + 1}'),
                      selected: _currentPage == index,
                      onSelected: (_) => setState(() {
                        _currentPage = index;
                        _selectedComponentId = null;
                      }),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _startColorController,
                        decoration: const InputDecoration(labelText: 'Gradient Start'),
                        onChanged: (v) => setState(() {
                          _pages[_currentPage] = page.copyWith(gradientStart: v);
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _endColorController,
                        decoration: const InputDecoration(labelText: 'Gradient End'),
                        onChanged: (v) => setState(() {
                          _pages[_currentPage] = page.copyWith(gradientEnd: v);
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    SegmentedButton<WishBackgroundType>(
                      segments: const [
                        ButtonSegment(value: WishBackgroundType.gradient, label: Text('Gradient')),
                        ButtonSegment(value: WishBackgroundType.image, label: Text('Image')),
                      ],
                      selected: {page.backgroundType},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _pages[_currentPage] = page.copyWith(backgroundType: selection.first);
                        });
                      },
                    ),
                    if (page.backgroundType == WishBackgroundType.image)
                      OutlinedButton.icon(
                        onPressed: _addBackgroundImageToCurrentPage,
                        icon: const Icon(Icons.wallpaper_outlined),
                        label: const Text('Set BG Image'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    labelText: 'Quick message (adds a text component)',
                  ),
                  onSubmitted: (value) {
                    if (value.trim().isEmpty) return;
                    _messages.add(value.trim());
                    _componentTextController.text = value.trim();
                    _addComponent(WishComponentType.text);
                    _messageController.clear();
                  },
                ),
                const SizedBox(height: 12),
                if (_selectedComponentId != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Selected component controls'),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Lock selected component'),
                            value: page.components
                                .firstWhere((c) => c.id == _selectedComponentId)
                                .locked,
                            onChanged: (value) => _updateSelectedComponent(
                              (c) => c.copyWith(locked: value),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                DropdownButtonFormField<AnimationType>(
                  value: _animationType,
                  decoration: const InputDecoration(labelText: 'Animation Type'),
                  items: AnimationType.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                      .toList(),
                  onChanged: (value) => setState(() => _animationType = value!),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(labelText: 'Theme Color HEX'),
                  onChanged: (value) => _theme = value,
                ),
                SwitchListTile.adaptive(
                  title: const Text('Premium creation (no watermark)'),
                  value: _isPremium,
                  onChanged: (v) => setState(() => _isPremium = v),
                ),
                if (widget.templateType == TemplateType.romantic)
                  SwitchListTile.adaptive(
                    title: const Text('Enable premium “Open When…” mode'),
                    subtitle: const Text('Tap open + hold reveal + shake surprise'),
                    value: _openWhenMode,
                    onChanged: (v) => setState(() => _openWhenMode = v),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _saveWish,
                  child: Text(_saving ? 'Creating...' : 'Create Wish'),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
              child: _EditorPreview(
                page: page,
                selectedComponentId: _selectedComponentId,
                parseHex: _parseHex,
                onSelect: (id) => setState(() => _selectedComponentId = id),
                onDrag: (id, delta) {
                  final component = page.components.firstWhere((c) => c.id == id);
                  if (component.locked) return;
                  _updateSelectedComponent(
                    (c) => c.copyWith(x: (c.x + delta.dx).clamp(0, 280), y: (c.y + delta.dy).clamp(0, 460)),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorPreview extends StatelessWidget {
  const _EditorPreview({
    required this.page,
    required this.selectedComponentId,
    required this.parseHex,
    required this.onSelect,
    required this.onDrag,
  });

  final WishPageModel page;
  final String? selectedComponentId;
  final Color Function(String hex, {Color fallback}) parseHex;
  final ValueChanged<String> onSelect;
  final void Function(String id, Offset delta) onDrag;

  @override
  Widget build(BuildContext context) {
    final gradient = LinearGradient(
      colors: [parseHex(page.gradientStart), parseHex(page.gradientEnd, fallback: const Color(0xFF120B28))],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: Container(
          decoration: BoxDecoration(gradient: page.backgroundType == WishBackgroundType.gradient ? gradient : null),
          child: Stack(
            children: [
              if (page.backgroundType == WishBackgroundType.image && page.backgroundImageUrl != null)
                Positioned.fill(
                  child: Image.network(
                    page.backgroundImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black38),
                  ),
                ),
              for (final component in page.components)
                Positioned(
                  left: component.x,
                  top: component.y,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      if (selectedComponentId == component.id) {
                        onDrag(component.id, details.delta);
                      }
                    },
                    onTap: () => onSelect(component.id),
                    child: Container(
                      width: component.width,
                      height: component.height,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selectedComponentId == component.id ? Colors.amber : Colors.white54,
                          width: selectedComponentId == component.id ? 2 : 1,
                        ),
                        color: Colors.black.withOpacity(0.35),
                      ),
                      child: _componentWidget(component),
                    ),
                  ),
                ),
              Positioned(
                right: 8,
                top: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text('Live Preview', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _componentWidget(WishComponentModel component) {
    switch (component.type) {
      case WishComponentType.text:
        return Text(
          component.value,
          style: const TextStyle(fontWeight: FontWeight.w700),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        );
      case WishComponentType.image:
        if (component.value.startsWith('http')) {
          return Image.network(component.value, fit: BoxFit.cover);
        }
        return const Center(child: Icon(Icons.image_outlined));
      case WishComponentType.button:
        return Center(
          child: FilledButton(
            onPressed: () {},
            child: Text(component.value),
          ),
        );
    }
  }
}
