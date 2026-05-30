import 'event_config.dart';
import 'gallery_image.dart';

class Gallery {
  Gallery({
    required this.id,
    required this.config,
    required this.createdAt,
    this.images = const [],
    this.folderPath,
    this.webGalleryUrl,
  });

  final String id;
  final EventConfig config;
  final DateTime createdAt;
  final List<GalleryImage> images;
  final String? folderPath;
  final String? webGalleryUrl;

  Map<String, dynamic> toJson() => {
        'id': id,
        'config': config.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'images': images.map((e) => e.toJson()).toList(),
        'folderPath': folderPath,
        'webGalleryUrl': webGalleryUrl,
      };

  factory Gallery.fromJson(Map<String, dynamic> json) => Gallery(
        id: json['id'] as String,
        config: EventConfig.fromJson(
          json['config'] as Map<String, dynamic>,
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        images: (json['images'] as List<dynamic>? ?? [])
            .map((e) => GalleryImage.fromJson(e as Map<String, dynamic>))
            .toList(),
        folderPath: json['folderPath'] as String?,
        webGalleryUrl: json['webGalleryUrl'] as String?,
      );

  Gallery copyWith({
    List<GalleryImage>? images,
    EventConfig? config,
    String? webGalleryUrl,
  }) =>
      Gallery(
        id: id,
        config: config ?? this.config,
        createdAt: createdAt,
        images: images ?? this.images,
        folderPath: folderPath,
        webGalleryUrl: webGalleryUrl ?? this.webGalleryUrl,
      );
}
