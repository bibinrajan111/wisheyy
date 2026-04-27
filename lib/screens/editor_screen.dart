import 'dart:math' as math;

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

enum PreviewDevice { mobile, tablet, desktop }

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.templateType});

  final TemplateType templateType;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final _picker = ImagePicker();
  final _textController = TextEditingController();

  final _pages = <WishPageModel>[];
  final _picked = <XFile>[];
  final _pages = <WishPageModel>[];

  int _currentPage = 0;
  String? _selectedId;
  AnimationType _animationType = AnimationType.fade;
  bool _saving = false;
  PreviewDevice _previewDevice = PreviewDevice.mobile;
  bool _previewInitialized = false;

  @override
  void initState() {
    super.initState();
    _pages.add(_seedPage(widget.templateType));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_previewInitialized) return;
    _previewInitialized = true;
    final width = MediaQuery.sizeOf(context).width;
    _previewDevice = width < 700
        ? PreviewDevice.mobile
        : width < 1100
            ? PreviewDevice.tablet
            : PreviewDevice.desktop;
  }

  WishPageModel _seedPage(TemplateType type) {
    final colors = switch (type) {
      TemplateType.romantic => (const Color(0xFFB24592), const Color(0xFFF15F79), 'My Love Story'),
      TemplateType.birthday => (const Color(0xFF36D1DC), const Color(0xFF5B86E5), 'Birthday Vibes'),
      TemplateType.friendship => (const Color(0xFF00C9A7), const Color(0xFF845EC2), 'Friendship Forever'),
    };

    return WishPageModel(
      id: const Uuid().v4(),
      backgroundType: WishBackgroundType.gradient,
      solidColor: _toHex(colors.$1),
      gradientStart: _toHex(colors.$1),
      gradientEnd: _toHex(colors.$2),
      finish: FinishType.normal,
      components: [
        WishComponentModel(
          id: const Uuid().v4(),
          type: WishComponentType.text,
          value: colors.$3,
          x: 28,
          y: 78,
          width: 280,
          height: 64,
        ),
        WishComponentModel(
          id: const Uuid().v4(),
          type: WishComponentType.text,
          value: 'Edit me right on canvas ✨',
          x: 28,
          y: 152,
          width: 300,
          height: 84,
          revealTrigger: RevealTrigger.tap,
        ),
        WishComponentModel(
          id: const Uuid().v4(),
          type: WishComponentType.button,
          value: 'Next',
          x: 118,
          y: 544,
          width: 124,
          height: 50,
          actionType: ButtonActionType.nextPage,
          revealTrigger: RevealTrigger.tap,
        ),
      ],
    );
  }

  WishPageModel get _page => _pages[_currentPage];

  void _addPage() {
    setState(() {
      _pages.add(_seedPage(widget.templateType));
      _currentPage = _pages.length - 1;
      _selectedId = null;
    });
  }

  Future<void> _pickBackgroundAsset({required bool video}) async {
    final file = video
        ? await _picker.pickVideo(source: ImageSource.gallery)
        : await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() {
      _picked.add(file);
      _pages[_currentPage] = _page.copyWith(
        backgroundType: video ? WishBackgroundType.video : WishBackgroundType.image,
        backgroundImageUrl: video ? _page.backgroundImageUrl : file.path,
        backgroundVideoUrl: video ? file.path : _page.backgroundVideoUrl,
      );
    });
  }

  Future<RevealTrigger?> _askTrigger() async {
    return showModalBottomSheet<RevealTrigger>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Choose reveal interaction')),
              for (final trigger in RevealTrigger.values.where((e) => e != RevealTrigger.none))
                ListTile(
                  title: Text(trigger.name),
                  subtitle: Text((trigger == RevealTrigger.tap)
                      ? 'Free'
                      : 'Premium component (recommended paid tier)'),
                  onTap: () => Navigator.pop(context, trigger),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<ButtonActionType?> _askButtonPurpose() async {
    return showModalBottomSheet<ButtonActionType>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('What should this button do?')),
            for (final action in ButtonActionType.values)
              ListTile(
                title: Text(action.name),
                onTap: () => Navigator.pop(context, action),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _addComponent(WishComponentType type) async {
    final trigger = await _askTrigger() ?? RevealTrigger.tap;
    ButtonActionType action = ButtonActionType.nextPage;
    if (type == WishComponentType.button) {
      action = await _askButtonPurpose() ?? ButtonActionType.nextPage;
    }

    final value = switch (type) {
      WishComponentType.text => _textController.text.trim().isEmpty ? 'Your text' : _textController.text.trim(),
      WishComponentType.image => _picked.isNotEmpty ? _picked.first.path : '',
      WishComponentType.button => 'Action',
    };

    final c = WishComponentModel(
      id: const Uuid().v4(),
      type: type,
      value: value,
      x: 40,
      y: 130,
      width: type == WishComponentType.image ? 170 : 220,
      height: type == WishComponentType.image ? 130 : 60,
      actionType: action,
      revealTrigger: trigger,
    );

    setState(() {
      _pages[_currentPage] = _page.copyWith(components: [..._page.components, c]);
      _selectedId = c.id;
    });
  }

  void _updateSelected(WishComponentModel Function(WishComponentModel) mapper) {
    if (_selectedId == null) return;
    final list = _page.components.map((c) => c.id == _selectedId ? mapper(c) : c).toList();
    setState(() => _pages[_currentPage] = _page.copyWith(components: list));
  }

  Future<void> _chooseColor({required bool start, required bool solid}) async {
    final c = await showModalBottomSheet<Color>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _HsbPicker(initial: _hexColor(_page.gradientStart)),
    );
    if (c == null) return;
    setState(() {
      _pages[_currentPage] = _page.copyWith(
        solidColor: solid ? _toHex(c) : _page.solidColor,
        gradientStart: start ? _toHex(c) : _page.gradientStart,
        gradientEnd: !start && !solid ? _toHex(c) : _page.gradientEnd,
      );
    });
  }

  Future<void> _editTextOnCanvas(WishComponentModel c) async {
    if (c.type != WishComponentType.text && c.type != WishComponentType.button) return;
    final ctrl = TextEditingController(text: c.value);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit text'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    _updateSelected((x) => x.copyWith(value: result));
  }

  Future<void> _saveWish() async {
    if (_pages.every((p) => p.components.isEmpty)) {
      _snack('Add at least one component.');
      return;
    }

    setState(() => _saving = true);
    try {
      final id = const Uuid().v4();
      final storage = StorageService(FirebaseStorage.instance);
      final repo = WishRepository(FirebaseFirestore.instance);
      final urlByPath = <String, String>{};

      for (var i = 0; i < _picked.length; i++) {
        final file = _picked[i];
        final isVideo = file.path.toLowerCase().endsWith('.mp4') || file.path.toLowerCase().endsWith('.mov');
        final url = await storage.uploadWishAsset(
          wishId: id,
          file: await file.readAsBytes(),
          fileName: '${isVideo ? 'video' : 'asset'}_$i${isVideo ? '.mp4' : '.jpg'}',
          contentType: isVideo ? 'video/mp4' : 'image/jpeg',
        );
        urlByPath[file.path] = url;
      }

      final pages = _pages.map((p) {
        final components = p.components.map((c) {
          if (c.type == WishComponentType.image && urlByPath.containsKey(c.value)) {
            return c.copyWith(value: urlByPath[c.value]);
          }
          return c;
        }).toList();
        return p.copyWith(
          backgroundImageUrl: urlByPath[p.backgroundImageUrl] ?? p.backgroundImageUrl,
          backgroundVideoUrl: urlByPath[p.backgroundVideoUrl] ?? p.backgroundVideoUrl,
          components: components,
        );
      }).toList();

      final premiumFromTriggers = pages.any(
        (p) => p.components.any((c) =>
            c.revealTrigger == RevealTrigger.swipe ||
            c.revealTrigger == RevealTrigger.hold ||
            c.revealTrigger == RevealTrigger.shake),
      );
      final premiumFromVideo = pages.any((p) => p.backgroundType == WishBackgroundType.video);
      final isPremium = premiumFromTriggers || premiumFromVideo;

      final wish = WishModel(
        id: id,
        templateType: widget.templateType,
        photos: pages
            .expand((p) => p.components.where((c) => c.type == WishComponentType.image).map((c) => c.value))
            .where((v) => v.startsWith('http'))
            .toList(),
        messages: pages
            .map((p) => p.components.where((c) => c.type == WishComponentType.text).map((c) => c.value).join(' '))
            .toList(),
        theme: pages.first.solidColor,
        animationType: _animationType,
        musicUrl: null,
        interactionConfig: const InteractionConfig(
          tapEnabled: true,
          swipeEnabled: true,
          holdEnabled: true,
          shakeEnabled: true,
        ),
        createdAt: DateTime.now(),
        pages: pages,
        isPremium: isPremium,
      );

      await repo.saveWish(wish);
      if (!mounted) return;
      _snack('Ready to share: ${ShareService().buildWishUrl(id)}');
      context.go('/player/$id');
    } catch (_) {
      _snack('Could not create wish right now.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 980;

    return AdaptiveScaffold(
      title: 'Editor • ${widget.templateType.name}',
      body: isMobile
          ? ListView(children: [_previewCard(), _controlCard()])
          : Row(children: [Expanded(flex: 4, child: _controlCard()), Expanded(flex: 3, child: _previewCard())]),
    );
  }

  Widget _controlCard() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            ExpansionTile(
              title: const Text('1) Preview device size'),
              initiallyExpanded: true,
              children: [
                SegmentedButton<PreviewDevice>(
                  selected: {_previewDevice},
                  segments: const [
                    ButtonSegment(value: PreviewDevice.mobile, label: Text('Mobile')),
                    ButtonSegment(value: PreviewDevice.tablet, label: Text('Tablet')),
                    ButtonSegment(value: PreviewDevice.desktop, label: Text('Desktop')),
                  ],
                  onSelectionChanged: (s) => setState(() => _previewDevice = s.first),
                ),
              ],
            ),
            ExpansionTile(
              title: const Text('2) Background & finish'),
              subtitle: const Text('HSB color picker + gradient + metallic/matte'),
              initiallyExpanded: true,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Solid'),
                      selected: _page.backgroundType == WishBackgroundType.solid,
                      onSelected: (_) => setState(() => _pages[_currentPage] = _page.copyWith(backgroundType: WishBackgroundType.solid)),
                    ),
                    ChoiceChip(
                      label: const Text('Gradient'),
                      selected: _page.backgroundType == WishBackgroundType.gradient,
                      onSelected: (_) => setState(() => _pages[_currentPage] = _page.copyWith(backgroundType: WishBackgroundType.gradient)),
                    ),
                    ChoiceChip(
                      label: const Text('Image'),
                      selected: _page.backgroundType == WishBackgroundType.image,
                      onSelected: (_) => _pickBackgroundAsset(video: false),
                    ),
                    ChoiceChip(
                      label: const Text('Video 💎'),
                      selected: _page.backgroundType == WishBackgroundType.video,
                      onSelected: (_) => _pickBackgroundAsset(video: true),
                    ),
                  ],
                ),
                ListTile(
                  title: const Text('Pick solid color (HSB)'),
                  trailing: CircleAvatar(backgroundColor: _hexColor(_page.solidColor)),
                  onTap: () => _chooseColor(start: false, solid: true),
                ),
                ListTile(
                  title: const Text('Pick gradient start (HSB)'),
                  trailing: CircleAvatar(backgroundColor: _hexColor(_page.gradientStart)),
                  onTap: () => _chooseColor(start: true, solid: false),
                ),
                ListTile(
                  title: const Text('Pick gradient end (HSB)'),
                  trailing: CircleAvatar(backgroundColor: _hexColor(_page.gradientEnd)),
                  onTap: () => _chooseColor(start: false, solid: false),
                ),
                SegmentedButton<FinishType>(
                  selected: {_page.finish},
                  onSelectionChanged: (s) => setState(() => _pages[_currentPage] = _page.copyWith(finish: s.first)),
                  segments: const [
                    ButtonSegment(value: FinishType.normal, label: Text('Normal')),
                    ButtonSegment(value: FinishType.matte, label: Text('Matte')),
                    ButtonSegment(value: FinishType.metallic, label: Text('Metallic')),
                  ],
                ),
              ],
            ),
            ExpansionTile(
              title: const Text('3) Add components'),
              subtitle: const Text('Text editable from preview (double tap)'),
              children: [
                TextField(controller: _textController, decoration: const InputDecoration(labelText: 'Text value')),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(onPressed: () => _addComponent(WishComponentType.text), child: const Text('Add Text')),
                    OutlinedButton(
                      onPressed: () async {
                        final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                        if (img != null) setState(() => _picked.add(img));
                        _addComponent(WishComponentType.image);
                      },
                      child: const Text('Add Image'),
                    ),
                    OutlinedButton(onPressed: () => _addComponent(WishComponentType.button), child: const Text('Add Button')),
                  ],
                ),
              ],
            ),
            ExpansionTile(
              title: const Text('4) Page flow'),
              children: [
                FilledButton.icon(onPressed: _addPage, icon: const Icon(Icons.add), label: const Text('Add next page')),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: List.generate(
                    _pages.length,
                    (i) => ChoiceChip(
                      label: Text('Page ${i + 1}'),
                      selected: _currentPage == i,
                      onSelected: (_) => setState(() {
                        _currentPage = i;
                        _selectedId = null;
                      }),
                    ),
                  ),
                ),
              ],
            ),
            ExpansionTile(
              title: const Text('5) Selected component settings'),
              children: [
                if (_selectedId == null) const ListTile(title: Text('Select a component from preview')), 
                if (_selectedId != null) ...[
                  Builder(builder: (context) {
                    final c = _page.components.firstWhere((x) => x.id == _selectedId);
                    return Column(
                      children: [
                        ListTile(
                          title: Text('Trigger: ${c.revealTrigger.name}'),
                          subtitle: const Text('Change by re-adding component if needed'),
                        ),
                        if (c.type == WishComponentType.button)
                          DropdownButtonFormField<ButtonActionType>(
                            value: c.actionType,
                            items: ButtonActionType.values
                                .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                                .toList(),
                            onChanged: (v) => _updateSelected((x) => x.copyWith(actionType: v)),
                            decoration: const InputDecoration(labelText: 'Button purpose'),
                          ),
                        SwitchListTile.adaptive(
                          title: const Text('Lock selected'),
                          value: c.locked,
                          onChanged: (v) => _updateSelected((x) => x.copyWith(locked: v)),
                        ),
                      ],
                    );
                  }),
                ]
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<AnimationType>(
              value: _animationType,
              items: AnimationType.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList(),
              onChanged: (v) => setState(() => _animationType = v!),
              decoration: const InputDecoration(labelText: 'Transition'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _saving ? null : _saveWish,
              icon: const Icon(Icons.publish),
              label: Text(_saving ? 'Creating...' : 'Create Wish'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewCard() {
    final frame = switch (_previewDevice) {
      PreviewDevice.mobile => const Size(360, 640),
      PreviewDevice.tablet => const Size(600, 960),
      PreviewDevice.desktop => const Size(900, 560),
    };

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: frame.width,
                height: frame.height,
                child: _EditorCanvas(
                  page: _page,
                  selectedId: _selectedId,
                  onTap: (id) => setState(() => _selectedId = id),
                  onDoubleTap: _editTextOnCanvas,
                  onDrag: (id, delta) {
                    final c = _page.components.firstWhere((e) => e.id == id);
                    if (c.locked) return;
                    _selectedId = id;
                    _updateSelected((x) => x.copyWith(
                          x: (x.x + delta.dx).clamp(0, math.max(0, frame.width - x.width - 8)),
                          y: (x.y + delta.dy).clamp(0, math.max(0, frame.height - x.height - 8)),
                        ));
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _hexColor(String hex) => Color(int.parse('0xFF${hex.replaceAll('#', '')}'));
  String _toHex(Color c) => '#${c.value.toRadixString(16).padLeft(8, '0').substring(2)}'.toUpperCase();
}

class _EditorCanvas extends StatelessWidget {
  const _EditorCanvas({
    required this.page,
    required this.selectedId,
    required this.onTap,
    required this.onDoubleTap,
    required this.onDrag,
  });

  final WishPageModel page;
  final String? selectedId;
  final ValueChanged<String> onTap;
  final ValueChanged<WishComponentModel> onDoubleTap;
  final void Function(String, Offset) onDrag;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: _background(page)),
        Positioned.fill(child: _finishOverlay(page.finish)),
        ...page.components.map((c) {
          return Positioned(
            left: c.x,
            top: c.y,
            child: GestureDetector(
              onTap: () => onTap(c.id),
              onDoubleTap: () => onDoubleTap(c),
              onPanUpdate: (d) => onDrag(c.id, d.delta),
              child: Container(
                width: c.width,
                height: c.height,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.28),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selectedId == c.id ? Colors.amber : Colors.white38,
                    width: selectedId == c.id ? 2 : 1,
                  ),
                ),
                child: _component(c),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _component(WishComponentModel c) {
    switch (c.type) {
      case WishComponentType.text:
        return Text(c.value, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700));
      case WishComponentType.image:
        return c.value.startsWith('http') ? Image.network(c.value, fit: BoxFit.cover) : const Icon(Icons.image);
      case WishComponentType.button:
        final icon = switch (c.revealTrigger) {
          RevealTrigger.tap => Icons.touch_app,
          RevealTrigger.hold => Icons.pan_tool_alt,
          RevealTrigger.swipe => Icons.swipe,
          RevealTrigger.shake => Icons.vibration,
          RevealTrigger.none => Icons.smart_button,
        };
        return FilledButton.icon(onPressed: () {}, icon: Icon(icon, size: 16), label: Text(c.value));
    }
  }

  Widget _background(WishPageModel page) {
    switch (page.backgroundType) {
      case WishBackgroundType.solid:
        return ColoredBox(color: Color(int.parse('0xFF${page.solidColor.replaceAll('#', '')}')));
      case WishBackgroundType.gradient:
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(int.parse('0xFF${page.gradientStart.replaceAll('#', '')}')),
                Color(int.parse('0xFF${page.gradientEnd.replaceAll('#', '')}')),
              ],
            ),
          ),
        );
      case WishBackgroundType.image:
        return page.backgroundImageUrl == null
            ? const ColoredBox(color: Colors.black12)
            : Image.network(page.backgroundImageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black12));
      case WishBackgroundType.video:
        return Stack(children: const [
          Positioned.fill(child: ColoredBox(color: Colors.black45)),
          Center(child: Icon(Icons.play_circle_fill, size: 90, color: Colors.white70)),
        ]);
    }
  }

  Widget _finishOverlay(FinishType finish) {
    switch (finish) {
      case FinishType.normal:
        return const SizedBox.shrink();
      case FinishType.matte:
        return ColoredBox(color: Colors.black.withOpacity(0.18));
      case FinishType.metallic:
        return IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.15), Colors.transparent, Colors.white.withOpacity(0.08)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        );
    }
  }
}

class _HsbPicker extends StatefulWidget {
  const _HsbPicker({required this.initial});
  final Color initial;

  @override
  State<_HsbPicker> createState() => _HsbPickerState();
}

class _HsbPickerState extends State<_HsbPicker> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial);
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 16, right: 16, top: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('HSB Color Picker', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Container(height: 48, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 12),
          _slider('Hue', _hsv.hue, 360, (v) => setState(() => _hsv = _hsv.withHue(v))),
          _slider('Saturation', _hsv.saturation * 100, 100, (v) => setState(() => _hsv = _hsv.withSaturation(v / 100))),
          _slider('Brightness', _hsv.value * 100, 100, (v) => setState(() => _hsv = _hsv.withValue(v / 100))),
          const SizedBox(height: 8),
          FilledButton(onPressed: () => Navigator.pop(context, color), child: const Text('Use color')),
        ],
      ),
    );
  }

  Widget _slider(String label, double value, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(0)}'),
        Slider(value: value, max: max, onChanged: onChanged),
      ],
    );
  }
}
