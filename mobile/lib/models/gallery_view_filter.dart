import 'gallery_image.dart';
import 'image_color_label.dart';

enum GalleryViewFilterKind {
  all,
  withRating,
  withoutRating,
  withColor,
  byStars,
  byColor,
}

class GalleryViewFilter {
  const GalleryViewFilter({
    this.kind = GalleryViewFilterKind.all,
    this.minStars = 1,
    this.color = ImageColorLabel.none,
  });

  final GalleryViewFilterKind kind;
  final int minStars;
  final ImageColorLabel color;

  String get label {
    switch (kind) {
      case GalleryViewFilterKind.all:
        return 'Visas';
      case GalleryViewFilterKind.withRating:
        return 'Ar reitingu';
      case GalleryViewFilterKind.withoutRating:
        return 'Bez reitinga';
      case GalleryViewFilterKind.withColor:
        return 'Ar krāsu';
      case GalleryViewFilterKind.byStars:
        return '★' * minStars;
      case GalleryViewFilterKind.byColor:
        return color.label;
    }
  }

  bool matches(GalleryImage image) {
    switch (kind) {
      case GalleryViewFilterKind.all:
        return true;
      case GalleryViewFilterKind.withRating:
        return image.starRating > 0;
      case GalleryViewFilterKind.withoutRating:
        return image.starRating == 0;
      case GalleryViewFilterKind.withColor:
        return image.colorLabel != ImageColorLabel.none;
      case GalleryViewFilterKind.byStars:
        return image.starRating >= minStars;
      case GalleryViewFilterKind.byColor:
        return image.colorLabel == color;
    }
  }

  GalleryViewFilter copyWith({
    GalleryViewFilterKind? kind,
    int? minStars,
    ImageColorLabel? color,
  }) =>
      GalleryViewFilter(
        kind: kind ?? this.kind,
        minStars: minStars ?? this.minStars,
        color: color ?? this.color,
      );
}
