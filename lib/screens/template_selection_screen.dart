import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/wish_model.dart';
import '../widgets/adaptive_scaffold.dart';
import '../widgets/template_card.dart';

class TemplateSelectionScreen extends StatelessWidget {
  const TemplateSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final templates = <(TemplateType, String)>[
      (TemplateType.romantic, 'Soft transitions + tap reveal.'),
      (TemplateType.birthday, 'Energetic slides + shake confetti.'),
      (TemplateType.friendship, 'Playful swipe story.'),
    ];

    return AdaptiveScaffold(
      title: 'Pick a Template',
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (_, i) {
          final template = templates[i];
          return TemplateCard(
            template: template.$1,
            description: template.$2,
            onTap: () => context.push('/editor/${template.$1.name}'),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemCount: templates.length,
      ),
    );
  }
}
