import 'package:cloud_firestore/cloud_firestore.dart';

enum TemplateType { romantic, birthday, friendship }

enum AnimationType { fade, slide, zoom }

enum WishBackgroundType { gradient, image }

enum WishComponentType { text, image, button }

class InteractionConfig {
  const InteractionConfig({
    required this.tapEnabled,
    required this.swipeEnabled,
    required this.holdEnabled,
    required this.shakeEnabled,
  });

  final bool tapEnabled;
  final bool swipeEnabled;
  final bool holdEnabled;
  final bool shakeEnabled;

  Map<String, dynamic> toJson() => {
        'tapEnabled': tapEnabled,
        'swipeEnabled': swipeEnabled,
        'holdEnabled': holdEnabled,
        'shakeEnabled': shakeEnabled,
      };

  factory InteractionConfig.fromJson(Map<String, dynamic> json) => InteractionConfig(
        tapEnabled: json['tapEnabled'] as bool? ?? true,
        swipeEnabled: json['swipeEnabled'] as bool? ?? true,
        holdEnabled: json['holdEnabled'] as bool? ?? false,
        shakeEnabled: json['shakeEnabled'] as bool? ?? false,
      );
}

class WishComponentModel {
  const WishComponentModel({
    required this.id,
    required this.type,
    required this.value,
    required this.x,
    required this.y,
    this.width = 180,
    this.height = 60,
    this.locked = false,
  });

  final String id;
  final WishComponentType type;
  final String value;
  final double x;
  final double y;
  final double width;
  final double height;
  final bool locked;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'value': value,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'locked': locked,
      };

  factory WishComponentModel.fromJson(Map<String, dynamic> json) => WishComponentModel(
        id: json['id'] as String,
        type: WishComponentType.values.byName(json['type'] as String),
        value: json['value'] as String? ?? '',
        x: (json['x'] as num?)?.toDouble() ?? 0,
        y: (json['y'] as num?)?.toDouble() ?? 0,
        width: (json['width'] as num?)?.toDouble() ?? 180,
        height: (json['height'] as num?)?.toDouble() ?? 60,
        locked: json['locked'] as bool? ?? false,
      );

  WishComponentModel copyWith({
    String? id,
    WishComponentType? type,
    String? value,
    double? x,
    double? y,
    double? width,
    double? height,
    bool? locked,
  }) {
    return WishComponentModel(
      id: id ?? this.id,
      type: type ?? this.type,
      value: value ?? this.value,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      locked: locked ?? this.locked,
    );
  }
}

class WishPageModel {
  const WishPageModel({
    required this.id,
    required this.backgroundType,
    required this.gradientStart,
    required this.gradientEnd,
    this.backgroundImageUrl,
    required this.components,
  });

  final String id;
  final WishBackgroundType backgroundType;
  final String gradientStart;
  final String gradientEnd;
  final String? backgroundImageUrl;
  final List<WishComponentModel> components;

  Map<String, dynamic> toJson() => {
        'id': id,
        'backgroundType': backgroundType.name,
        'gradientStart': gradientStart,
        'gradientEnd': gradientEnd,
        'backgroundImageUrl': backgroundImageUrl,
        'components': components.map((c) => c.toJson()).toList(),
      };

  factory WishPageModel.fromJson(Map<String, dynamic> json) => WishPageModel(
        id: json['id'] as String,
        backgroundType: WishBackgroundType.values.byName(
          json['backgroundType'] as String? ?? WishBackgroundType.gradient.name,
        ),
        gradientStart: json['gradientStart'] as String? ?? '#6E56F8',
        gradientEnd: json['gradientEnd'] as String? ?? '#1A103D',
        backgroundImageUrl: json['backgroundImageUrl'] as String?,
        components: (json['components'] as List<dynamic>? ?? const [])
            .map((e) => WishComponentModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  WishPageModel copyWith({
    String? id,
    WishBackgroundType? backgroundType,
    String? gradientStart,
    String? gradientEnd,
    String? backgroundImageUrl,
    List<WishComponentModel>? components,
  }) {
    return WishPageModel(
      id: id ?? this.id,
      backgroundType: backgroundType ?? this.backgroundType,
      gradientStart: gradientStart ?? this.gradientStart,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
      components: components ?? this.components,
    );
  }
}

class WishModel {
  const WishModel({
    required this.id,
    required this.templateType,
    required this.photos,
    required this.messages,
    required this.theme,
    required this.animationType,
    required this.musicUrl,
    required this.interactionConfig,
    required this.createdAt,
    required this.pages,
    this.isPremium = false,
  });

  final String id;
  final TemplateType templateType;
  final List<String> photos;
  final List<String> messages;
  final String theme;
  final AnimationType animationType;
  final String? musicUrl;
  final InteractionConfig interactionConfig;
  final DateTime createdAt;
  final List<WishPageModel> pages;
  final bool isPremium;

  Map<String, dynamic> toJson() => {
        'id': id,
        'templateType': templateType.name,
        'photos': photos,
        'messages': messages,
        'theme': theme,
        'animationType': animationType.name,
        'musicUrl': musicUrl,
        'interactionConfig': interactionConfig.toJson(),
        'createdAt': Timestamp.fromDate(createdAt),
        'pages': pages.map((p) => p.toJson()).toList(),
        'isPremium': isPremium,
      };

  factory WishModel.fromJson(Map<String, dynamic> json) => WishModel(
        id: json['id'] as String,
        templateType: TemplateType.values.byName(json['templateType'] as String),
        photos: List<String>.from(json['photos'] as List<dynamic>? ?? const []),
        messages: List<String>.from(json['messages'] as List<dynamic>? ?? const []),
        theme: json['theme'] as String? ?? '#6E56F8',
        animationType: AnimationType.values.byName(
          json['animationType'] as String? ?? AnimationType.fade.name,
        ),
        musicUrl: json['musicUrl'] as String?,
        interactionConfig: InteractionConfig.fromJson(
          json['interactionConfig'] as Map<String, dynamic>? ?? const {},
        ),
        createdAt: (json['createdAt'] as Timestamp).toDate(),
        pages: (json['pages'] as List<dynamic>? ?? const [])
            .map((e) => WishPageModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        isPremium: json['isPremium'] as bool? ?? false,
      );
}
