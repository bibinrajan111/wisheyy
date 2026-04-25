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

const _palette = <Color>[
  Color(0xFF6E56F8),
  Color(0xFFF15F79),
  Color(0xFF36D1DC),
  Color(0xFF00C9A7),
  Color(0xFF845EC2),
  Color(0xFF1B1A55),
  Color(0xFF111827),
  Color(0xFFE11D48),
  Color(0xFFF59E0B),
  Color(0xFF22C55E),
  Color(0xFF3B82F6),
  Color(0xFF9333EA),
];

enum PreviewDevice { phone, tablet, desktop }

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.templateType});

  final TemplateType templateType;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final _picker = ImagePicker();
  final _componentTextController = TextEditingController();
  final _interactionTapController = TextEditingController(text: 'Tap to continue');
  final _interactionSwipeController = TextEditingController(text: 'Swipe to navigate');
  final _interactionHoldController = TextEditingController(text: 'Hold to reveal');
  final _interactionShakeController = TextEditingController(text: 'Shake for surprise');

  final _picked = <XFile>[];
  final _pages = <WishPageModel>[];

  int _currentPage = 0;
  String? _selectedComponentId;
  AnimationType _animationType = AnimationType.fade;
  bool _saving = false;
  bool _tapEnabled = true;
  bool _swipeEnabled = false;
  bool _holdEnabled = false;
  bool _shakeEnabled = false;
  PreviewDevice _previewDevice = PreviewDevice.phone;

  @override
  void initState() {
    super.initState();
    _pages.add(_defaultPageForTemplate(widget.templateType));
  }

  WishPageModel _defaultPageForTemplate(TemplateType type) {
    final theme = switch (type) {
      TemplateType.romantic => (const Color(0xFFB24592), const Color(0xFFF15F79), 'My Love'),
      TemplateType.birthday => (const Color(0xFF36D1DC), const Color(0xFF5B86E5), 'Happy Birthday!'),
      TemplateType.friendship => (const Color(0xFF00C9A7), const Color(0xFF845EC2), 'To my best friend'),
    };
    return WishPageModel(
      id: const Uuid().v4(),
      backgroundType: WishBackgroundType.gradient,
      solidColor: _toHex(theme.$1),
      gradientStart: _toHex(theme.$1),
      gradientEnd: _toHex(theme.$2),
      components: [
        WishComponentModel(
          id: const Uuid().v4(),
          type: WishComponentType.text,
          value: theme.$3,
          x: 28,
          y: 80,
          width: 280,
          height: 80,
        ),
        WishComponentModel(
          id: const Uuid().v4(),
          type: WishComponentType.text,
          value: 'A special message crafted with Wisheyy',
          x: 28,
          y: 170,
          width: 300,
          height: 100,
        ),
        WishComponentModel(
          id: const Uuid().v4(),
          type: WishComponentType.button,
          value: 'Next',
          actionType: ButtonActionType.nextPage,
          x: 110,
          y: 525,
          width: 140,
          height: 52,
        ),
      ],
    );
  }

  void _addPage() {
    setState(() {
      _pages.add(_defaultPageForTemplate(widget.templateType));
      _currentPage = _pages.length - 1;
      _selectedComponentId = null;
    });
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;
    setState(() => _picked.add(image));
  }

  Future<void> _pickVideoForBackground() async {
    final video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;
    setState(() => _picked.add(video));
    final page = _pages[_currentPage];
    setState(() {
      _pages[_currentPage] = page.copyWith(
        backgroundType: WishBackgroundType.video,
        backgroundVideoUrl: video.path,
      );
    });
  }

  void _addComponent(WishComponentType type) {
    final page = _pages[_currentPage];
    final component = WishComponentModel(
      id: const Uuid().v4(),
      type: type,
      value: switch (type) {
        WishComponentType.text => _componentTextController.text.trim().isEmpty
            ? 'Your text here'
            : _componentTextController.text.trim(),
        WishComponentType.image => _picked.isNotEmpty ? _picked.first.path : '',
        WishComponentType.button => 'Next',
      },
      x: 40,
      y: 120,
      width: type == WishComponentType.image ? 180 : 220,
      height: type == WishComponentType.image ? 140 : 60,
      actionType: ButtonActionType.nextPage,
    );

    setState(() {
      _pages[_currentPage] = page.copyWith(components: [...page.components, component]);
      _selectedComponentId = component.id;
    });
  }

  void _setColorOnPage({required bool isGradientStart, required bool isSolid}) async {
    final selected = await showModalBottomSheet<Color>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ColorPickerSheet(initial: _palette.first),
    );
    if (selected == null) return;

    final page = _pages[_currentPage];
    setState(() {
      if (isSolid) {
        _pages[_currentPage] = page.copyWith(solidColor: _toHex(selected));
      } else if (isGradientStart) {
        _pages[_currentPage] = page.copyWith(gradientStart: _toHex(selected));
      } else {
        _pages[_currentPage] = page.copyWith(gradientEnd: _toHex(selected));
      }
    });
  }

  void _updateSelected(WishComponentModel Function(WishComponentModel c) map) {
    final selectedId = _selectedComponentId;
    if (selectedId == null) return;
    final page = _pages[_currentPage];
    final components = page.components.map((c) => c.id == selectedId ? map(c) : c).toList();
    setState(() => _pages[_currentPage] = page.copyWith(components: components));
  }

  Future<void> _saveWish() async {
    if (_pages.isEmpty) return;
    if (_pages.every((p) => p.components.isEmpty)) {
      _showMessage('Please add at least one component.');
      return;
    }

    setState(() => _saving = true);

    try {
      final id = const Uuid().v4();
      final storage = StorageService(FirebaseStorage.instance);
      final repository = WishRepository(FirebaseFirestore.instance);
      final uploadedByPath = <String, String>{};
      final photos = <String>[];

      for (var i = 0; i < _picked.length; i++) {
        final file = _picked[i];
        final bytes = await file.readAsBytes();
        final isVideo = file.path.toLowerCase().endsWith('.mp4') || file.path.toLowerCase().endsWith('.mov');
        final url = await storage.uploadWishAsset(
          wishId: id,
          file: bytes,
          fileName: '${isVideo ? 'video' : 'asset'}_$i${isVideo ? '.mp4' : '.jpg'}',
          contentType: isVideo ? 'video/mp4' : 'image/jpeg',
        );
        uploadedByPath[file.path] = url;
        if (!isVideo) photos.add(url);
      }

      final mappedPages = _pages.map((page) {
        final components = page.components.map((c) {
          if (c.type == WishComponentType.image && uploadedByPath.containsKey(c.value)) {
            return c.copyWith(value: uploadedByPath[c.value]);
          }
          return c;
        }).toList();
        return page.copyWith(
          backgroundImageUrl: uploadedByPath[page.backgroundImageUrl] ?? page.backgroundImageUrl,
          backgroundVideoUrl: uploadedByPath[page.backgroundVideoUrl] ?? page.backgroundVideoUrl,
          components: components,
        );
      }).toList();

      final isPremium = _holdEnabled || _shakeEnabled || _swipeEnabled ||
          mappedPages.any((p) => p.backgroundType == WishBackgroundType.video);

      final wish = WishModel(
        id: id,
        templateType: widget.templateType,
        photos: photos,
        messages: mappedPages
            .map((p) => p.components.where((c) => c.type == WishComponentType.text).map((e) => e.value).join(' '))
            .where((text) => text.trim().isNotEmpty)
            .toList(),
        theme: mappedPages.first.solidColor,
        animationType: _animationType,
        musicUrl: null,
        interactionConfig: InteractionConfig(
          tapEnabled: _tapEnabled,
          swipeEnabled: _swipeEnabled,
          holdEnabled: _holdEnabled,
          shakeEnabled: _shakeEnabled,
          tapLabel: _interactionTapController.text.trim(),
          swipeLabel: _interactionSwipeController.text.trim(),
          holdLabel: _interactionHoldController.text.trim(),
          shakeLabel: _interactionShakeController.text.trim(),
        ),
        createdAt: DateTime.now(),
        pages: mappedPages,
        isPremium: isPremium,
      );

      await repository.saveWish(wish);
      if (!mounted) return;
      _showMessage('Ready to share: ${ShareService().buildWishUrl(id)}');
      context.go('/player/$id');
    } catch (_) {
      _showMessage('Unable to create wish right now.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _componentTextController.dispose();
    _interactionTapController.dispose();
    _interactionSwipeController.dispose();
    _interactionHoldController.dispose();
    _interactionShakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];

    return AdaptiveScaffold(
      title: 'Editor • ${widget.templateType.name}',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 980;
          final editorPanel = _buildEditorPanel(page);
          final previewPanel = _buildPreviewPanel(page, constraints.maxWidth, isMobile);

          if (isMobile) {
            return ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                previewPanel,
                editorPanel,
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 5, child: editorPanel),
              Expanded(flex: 4, child: previewPanel),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEditorPanel(WishPageModel page) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: ListView(
          padding: const EdgeInsets.all(10),
          children: [
            ExpansionTile(
              initiallyExpanded: true,
              title: const Text('Step 1: Pages & Flow'),
              subtitle: const Text('Mobile-first storytelling flow'),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _addPage,
                      icon: const Icon(Icons.add_box_outlined),
                      label: const Text('Add Next Page'),
                    ),
                    ...List.generate(
                      _pages.length,
                      (index) => ChoiceChip(
                        label: Text('Page ${index + 1}'),
                        selected: _currentPage == index,
                        onSelected: (_) => setState(() {
                          _currentPage = index;
                          _selectedComponentId = null;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const ListTile(
                  leading: Icon(Icons.lightbulb_outline),
                  title: Text('Suggestion: Keep 3–5 pages for better completion rates.'),
                ),
              ],
            ),
            ExpansionTile(
              initiallyExpanded: true,
              title: const Text('Step 2: Choose Background'),
              subtitle: const Text('Solid color, gradient, image, or premium video'),
              children: [
                SegmentedButton<WishBackgroundType>(
                  segments: const [
                    ButtonSegment(value: WishBackgroundType.solid, label: Text('Color')),
                    ButtonSegment(value: WishBackgroundType.gradient, label: Text('Gradient')),
                    ButtonSegment(value: WishBackgroundType.image, label: Text('Image')),
                    ButtonSegment(value: WishBackgroundType.video, label: Text('Video 💎')),
                  ],
                  selected: {page.backgroundType},
                  onSelectionChanged: (selection) {
                    setState(() => _pages[_currentPage] = page.copyWith(backgroundType: selection.first));
                  },
                ),
                if (page.backgroundType == WishBackgroundType.solid) ...[
                  ListTile(
                    title: const Text('Pick color'),
                    trailing: CircleAvatar(backgroundColor: _hexToColor(page.solidColor)),
                    onTap: () => _setColorOnPage(isGradientStart: false, isSolid: true),
                  ),
                ],
                if (page.backgroundType == WishBackgroundType.gradient) ...[
                  ListTile(
                    title: const Text('Gradient start'),
                    trailing: CircleAvatar(backgroundColor: _hexToColor(page.gradientStart)),
                    onTap: () => _setColorOnPage(isGradientStart: true, isSolid: false),
                  ),
                  ListTile(
                    title: const Text('Gradient end'),
                    trailing: CircleAvatar(backgroundColor: _hexToColor(page.gradientEnd)),
                    onTap: () => _setColorOnPage(isGradientStart: false, isSolid: false),
                  ),
                ],
                if (page.backgroundType == WishBackgroundType.image)
                  ListTile(
                    title: const Text('Choose background image'),
                    trailing: const Icon(Icons.image_outlined),
                    onTap: () async {
                      final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                      if (image == null) return;
                      setState(() {
                        _picked.add(image);
                        _pages[_currentPage] = page.copyWith(backgroundImageUrl: image.path);
                      });
                    },
                  ),
                if (page.backgroundType == WishBackgroundType.video) ...[
                  ListTile(
                    title: const Text('Choose background video (premium)'),
                    trailing: const Icon(Icons.movie_creation_outlined),
                    onTap: _pickVideoForBackground,
                  ),
                  const ListTile(
                    leading: Icon(Icons.workspace_premium_outlined),
                    title: Text('Suggestion: Charge extra for video rendering + hosting costs.'),
                  ),
                ],
              ],
            ),
            ExpansionTile(
              title: const Text('Step 3: Add Components'),
              initiallyExpanded: true,
              subtitle: const Text('Texts, images, and interactive buttons'),
              children: [
                TextField(
                  controller: _componentTextController,
                  decoration: const InputDecoration(labelText: 'Text component content'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _addComponent(WishComponentType.text),
                      icon: const Icon(Icons.text_fields),
                      label: const Text('Add Text'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await _pickImage();
                        _addComponent(WishComponentType.image);
                      },
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Add Image'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _addComponent(WishComponentType.button),
                      icon: const Icon(Icons.smart_button),
                      label: const Text('Add Button'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const ListTile(
                  leading: Icon(Icons.tips_and_updates_outlined),
                  title: Text('Tip: Start from text + one CTA button per page for clarity.'),
                ),
              ],
            ),
            ExpansionTile(
              title: const Text('Step 4: Layout & Controls'),
              subtitle: const Text('Drag selected component. Lock when done.'),
              children: [
                if (_selectedComponentId == null)
                  const ListTile(title: Text('Select an item from preview to edit controls.')),
                if (_selectedComponentId != null)
                  Builder(builder: (context) {
                    final selected = page.components.firstWhere((c) => c.id == _selectedComponentId);
                    return Column(
                      children: [
                        TextField(
                          controller: TextEditingController(text: selected.value),
                          decoration: const InputDecoration(labelText: 'Selected component label/text'),
                          onSubmitted: (value) => _updateSelected((c) => c.copyWith(value: value)),
                        ),
                        const SizedBox(height: 8),
                        if (selected.type == WishComponentType.button)
                          DropdownButtonFormField<ButtonActionType>(
                            value: selected.actionType,
                            decoration: const InputDecoration(labelText: 'Button action'),
                            items: ButtonActionType.values
                                .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              _updateSelected((c) => c.copyWith(actionType: value));
                            },
                          ),
                        SwitchListTile.adaptive(
                          title: const Text('Lock selected component'),
                          value: selected.locked,
                          onChanged: (v) => _updateSelected((c) => c.copyWith(locked: v)),
                        ),
                      ],
                    );
                  }),
              ],
            ),
            ExpansionTile(
              title: const Text('Step 5: Interactions & Pricing'),
              subtitle: const Text('Rename actions and configure premium gestures'),
              children: [
                SwitchListTile.adaptive(
                  title: const Text('Tap interaction (Free)'),
                  value: _tapEnabled,
                  onChanged: (v) => setState(() => _tapEnabled = v),
                ),
                TextField(controller: _interactionTapController, decoration: const InputDecoration(labelText: 'Tap label')),
                SwitchListTile.adaptive(
                  title: const Text('Swipe interaction (Premium)'),
                  value: _swipeEnabled,
                  onChanged: (v) => setState(() => _swipeEnabled = v),
                ),
                TextField(controller: _interactionSwipeController, decoration: const InputDecoration(labelText: 'Swipe label')),
                SwitchListTile.adaptive(
                  title: const Text('Hold interaction (Premium)'),
                  value: _holdEnabled,
                  onChanged: (v) => setState(() => _holdEnabled = v),
                ),
                TextField(controller: _interactionHoldController, decoration: const InputDecoration(labelText: 'Hold label')),
                SwitchListTile.adaptive(
                  title: const Text('Shake interaction (Premium)'),
                  value: _shakeEnabled,
                  onChanged: (v) => setState(() => _shakeEnabled = v),
                ),
                TextField(controller: _interactionShakeController, decoration: const InputDecoration(labelText: 'Shake label')),
              ],
            ),
            ExpansionTile(
              title: const Text('Step 6: Publish'),
              subtitle: const Text('Animation + validation + create link'),
              children: [
                DropdownButtonFormField<AnimationType>(
                  value: _animationType,
                  decoration: const InputDecoration(labelText: 'Transition animation'),
                  items: AnimationType.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                      .toList(),
                  onChanged: (value) => setState(() => _animationType = value!),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _saving ? null : _saveWish,
                  icon: const Icon(Icons.publish_outlined),
                  label: Text(_saving ? 'Creating...' : 'Create Wish'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewPanel(WishPageModel page, double maxWidth, bool isMobile) {
    final frameWidth = switch (_previewDevice) {
      PreviewDevice.phone => 360.0,
      PreviewDevice.tablet => 600.0,
      PreviewDevice.desktop => 900.0,
    };

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Live preview'),
                  SegmentedButton<PreviewDevice>(
                    selected: {_previewDevice},
                    onSelectionChanged: (s) => setState(() => _previewDevice = s.first),
                    segments: const [
                      ButtonSegment(value: PreviewDevice.phone, icon: Icon(Icons.phone_android)),
                      ButtonSegment(value: PreviewDevice.tablet, icon: Icon(Icons.tablet_mac)),
                      ButtonSegment(value: PreviewDevice.desktop, icon: Icon(Icons.desktop_windows)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Container(
                      width: (frameWidth.clamp(320, isMobile ? maxWidth - 40 : maxWidth)).toDouble(),
                      height: frameWidth * 16 / 9,
                      color: Colors.black,
                      child: Center(
                        child: _EditorCanvas(
                          page: page,
                          selectedComponentId: _selectedComponentId,
                          onSelect: (id) => setState(() => _selectedComponentId = id),
                          onDrag: (id, delta) {
                            final component = page.components.firstWhere((c) => c.id == id);
                            if (component.locked) return;
                            _updateSelected((c) => c.copyWith(
                                  x: (c.x + delta.dx).clamp(0, 300),
                                  y: (c.y + delta.dy).clamp(0, 580),
                                ));
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    final value = hex.replaceAll('#', '');
    return Color(int.parse('0xFF$value'));
  }

  String _toHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}'.toUpperCase();
  }
}

class _EditorCanvas extends StatelessWidget {
  const _EditorCanvas({
    required this.page,
    required this.selectedComponentId,
    required this.onSelect,
    required this.onDrag,
  });

  final WishPageModel page;
  final String? selectedComponentId;
  final ValueChanged<String> onSelect;
  final void Function(String id, Offset delta) onDrag;

  @override
  Widget build(BuildContext context) {
    final background = switch (page.backgroundType) {
      WishBackgroundType.solid => ColoredBox(color: _hex(page.solidColor)),
      WishBackgroundType.gradient => DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_hex(page.gradientStart), _hex(page.gradientEnd)]),
          ),
        ),
      WishBackgroundType.image => page.backgroundImageUrl == null
          ? const ColoredBox(color: Colors.black12)
          : Image.network(
              page.backgroundImageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black12),
            ),
      WishBackgroundType.video => Stack(
          children: [
            const ColoredBox(color: Colors.black26),
            Center(
              child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 90),
            ),
            const Positioned(
              bottom: 10,
              left: 10,
              child: Text('Video background (premium)', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
    };

    return SizedBox(
      width: 360,
      height: 640,
      child: Stack(
        children: [
          Positioned.fill(child: background),
          Positioned.fill(child: ColoredBox(color: Colors.black.withOpacity(0.2))),
          ...page.components.map((component) {
            return Positioned(
              left: component.x,
              top: component.y,
              child: GestureDetector(
                onTap: () => onSelect(component.id),
                onPanUpdate: (d) {
                  if (selectedComponentId == component.id) {
                    onDrag(component.id, d.delta);
                  }
                },
                child: Container(
                  width: component.width,
                  height: component.height,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selectedComponentId == component.id ? Colors.amber : Colors.white38,
                      width: selectedComponentId == component.id ? 2 : 1,
                    ),
                  ),
                  child: _component(component),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _component(WishComponentModel component) {
    switch (component.type) {
      case WishComponentType.text:
        return Text(component.value, maxLines: 3, overflow: TextOverflow.ellipsis);
      case WishComponentType.image:
        if (component.value.startsWith('http')) {
          return Image.network(component.value, fit: BoxFit.cover);
        }
        return const Center(child: Icon(Icons.image));
      case WishComponentType.button:
        return Center(child: FilledButton(onPressed: () {}, child: Text(component.value)));
    }
  }

  Color _hex(String hex) {
    final value = hex.replaceAll('#', '');
    return Color(int.parse('0xFF$value'));
  }
}

class _ColorPickerSheet extends StatelessWidget {
  const _ColorPickerSheet({required this.initial});

  final Color initial;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: _palette
            .map(
              (color) => GestureDetector(
                onTap: () => Navigator.pop(context, color),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
