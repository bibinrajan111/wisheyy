import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/adaptive_scaffold.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Wisheyy',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFFF7EB3), Color(0xFF65D6FF), Color(0xFF7DFFB3)],
                      ).createShader(bounds),
                      child: Text(
                        'Create emotional wishes\nin under 3 minutes',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Design pages, drag components, customize backgrounds, and share magic instantly.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => context.push('/templates'),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Start Creating'),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Scheduled delivery + premium marketplace coming soon',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
