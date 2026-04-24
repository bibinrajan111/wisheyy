import 'dart:io';

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
  final _messages = <String>[];
  final _picked = <XFile>[];
  AnimationType _animationType = AnimationType.fade;
  String _theme = '#6E56F8';
  bool _openWhenMode = false;
  bool _saving = false;

  Future<void> _pickImage() async {
    if (_picked.length >= 5) return;
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;
    setState(() => _picked.add(image));
  }

  Future<void> _saveWish() async {
    if (_picked.length < 3 || _messages.isEmpty) return;
    setState(() => _saving = true);

    final id = const Uuid().v4();
    final storage = StorageService(FirebaseStorage.instance);
    final repository = WishRepository(FirebaseFirestore.instance);

    final urls = <String>[];
    for (var i = 0; i < _picked.length; i++) {
      urls.add(
        await storage.uploadWishImage(
          wishId: id,
          file: File(_picked[i].path),
          index: i,
        ),
      );
    }

    final wish = WishModel(
      id: id,
      templateType: widget.templateType,
      photos: urls,
      messages: _messages,
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
    );

    await repository.saveWish(wish);
    if (!mounted) return;

    final shareUrl = ShareService().buildWishUrl(id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ready to share: $shareUrl')),
    );

    context.go('/player/$id');
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Editor • ${widget.templateType.name}',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Photos (${_picked.length}/5, min 3)'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final img in _picked)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(img.path),
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add image'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _messageController,
            decoration: const InputDecoration(
              labelText: 'Add short message slide',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              if (value.trim().isEmpty) return;
              setState(() {
                _messages.add(value.trim());
                _messageController.clear();
              });
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: _messages.map((m) => Chip(label: Text(m))).toList(),
          ),
          const SizedBox(height: 16),
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
          if (widget.templateType == TemplateType.romantic) ...[
            SwitchListTile(
              title: const Text('Enable premium “Open When…” mode'),
              subtitle: const Text('Tap open + hold reveal + shake surprise'),
              value: _openWhenMode,
              onChanged: (v) => setState(() => _openWhenMode = v),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _saveWish,
            child: Text(_saving ? 'Creating...' : 'Create Wish'),
          ),
        ],
      ),
    );
  }
}
