import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/wish_model.dart';
import '../widgets/adaptive_scaffold.dart';
import '../widgets/template_card.dart';

class TemplateSelectionScreen extends StatelessWidget {
  const TemplateSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final templates = <({
      TemplateType type,
      String description,
      List<Color> gradient,
      IconData icon,
      bool premium,
    })>[
      (
        type: TemplateType.romantic,
        description: 'Soft reveals, dreamy gradients, surprise interactions.',
        gradient: [const Color(0xFFB24592), const Color(0xFFF15F79)],
        icon: Icons.favorite_rounded,
        premium: true,
      ),
      (
        type: TemplateType.birthday,
        description: 'Bright party colors with confetti shake effect.',
        gradient: [const Color(0xFF36D1DC), const Color(0xFF5B86E5)],
        icon: Icons.celebration_rounded,
        premium: false,
      ),
      (
        type: TemplateType.friendship,
        description: 'Playful layout and swipe-through story pages.',
        gradient: [const Color(0xFF00C9A7), const Color(0xFF845EC2)],
        icon: Icons.groups_rounded,
        premium: false,
      ),
    ];

    return AdaptiveScaffold(
      title: 'Pick a Template',
      body: Column(
        children: [
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Live template feeling',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(16),
              itemBuilder: (_, i) {
                final template = templates[i];
                return Container(
                  width: 220,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(colors: template.gradient),
                  ),
                  child: Center(
                    child: Icon(template.icon, size: 48, color: Colors.white),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemCount: templates.length,
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (_, i) {
                final template = templates[i];
                return TemplateCard(
                  template: template.type,
                  description: template.description,
                  gradient: template.gradient,
                  icon: template.icon,
                  isPremium: template.premium,
                  onTap: () => context.push('/editor/${template.type.name}'),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: templates.length,
            ),
          ),
        ],
      ),
    );
  }
}
