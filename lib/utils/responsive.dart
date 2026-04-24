import 'package:flutter/widgets.dart';

enum DeviceSize { mobile, tablet, desktop }

class Responsive {
  static DeviceSize of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1024) return DeviceSize.desktop;
    if (width >= 600) return DeviceSize.tablet;
    return DeviceSize.mobile;
  }

  static bool isDesktop(BuildContext context) => of(context) == DeviceSize.desktop;
}
