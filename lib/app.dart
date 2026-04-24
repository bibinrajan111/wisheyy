import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'models/wish_model.dart';
import 'screens/editor_screen.dart';
import 'screens/home_screen.dart';
import 'screens/player_screen.dart';
import 'screens/template_selection_screen.dart';
import 'theme/app_theme.dart';

class WisheyyApp extends StatelessWidget {
  const WisheyyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
        GoRoute(
          path: '/templates',
          builder: (_, __) => const TemplateSelectionScreen(),
        ),
        GoRoute(
          path: '/editor/:template',
          builder: (_, state) => EditorScreen(
            templateType: TemplateType.values.byName(state.pathParameters['template']!),
          ),
        ),
        GoRoute(
          path: '/player/:wishId',
          builder: (_, state) => PlayerScreen(wishId: state.pathParameters['wishId']!),
        ),
      ],
    );

    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    if (isIOS) {
      return CupertinoApp.router(
        title: 'Wisheyy',
        theme: AppTheme.cupertinoTheme,
        routerConfig: router,
      );
    }

    return MaterialApp.router(
      title: 'Wisheyy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.materialTheme,
      routerConfig: router,
    );
  }
}
