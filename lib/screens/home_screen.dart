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
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Create emotional wishes in < 3 minutes',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => context.push('/templates'),
                  child: const Text('Start Creating'),
                ),
                const SizedBox(height: 12),
                const Text('Scheduled delivery: coming soon'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
