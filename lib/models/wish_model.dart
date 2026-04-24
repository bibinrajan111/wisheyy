import 'package:cloud_firestore/cloud_firestore.dart';

enum TemplateType { romantic, birthday, friendship }

enum AnimationType { fade, slide, zoom }

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
      };

  factory WishModel.fromJson(Map<String, dynamic> json) => WishModel(
        id: json['id'] as String,
        templateType: TemplateType.values.byName(json['templateType'] as String),
        photos: List<String>.from(json['photos'] as List<dynamic>),
        messages: List<String>.from(json['messages'] as List<dynamic>),
        theme: json['theme'] as String,
        animationType: AnimationType.values.byName(json['animationType'] as String),
        musicUrl: json['musicUrl'] as String?,
        interactionConfig: InteractionConfig.fromJson(
          json['interactionConfig'] as Map<String, dynamic>,
        ),
        createdAt: (json['createdAt'] as Timestamp).toDate(),
      );
}
