import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/responsive.dart';

class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.title,
    required this.body,
    this.sidebar,
  });

  final String title;
  final Widget body;
  final Widget? sidebar;

  @override
  Widget build(BuildContext context) {
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final isDesktop = Responsive.isDesktop(context);

    final decoratedBody = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF171538), Color(0xFF0F1024), Color(0xFF251650)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: body,
    );

    if (isIOS) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: Text(title)),
        child: SafeArea(child: decoratedBody),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
      ),
      body: isDesktop && sidebar != null
          ? Row(
              children: [
                SizedBox(width: 280, child: sidebar),
                const VerticalDivider(width: 1),
                Expanded(child: decoratedBody),
              ],
            )
          : decoratedBody,
    );
  }
}
