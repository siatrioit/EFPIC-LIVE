import 'gallery_image.dart';
import 'image_color_label.dart';

enum GalleryViewFilterKind {
  all,
  withRating,
  withoutRating,
  byColor,
}

class GalleryViewFilter {
  const GalleryViewFilter({
    this.kind = GalleryViewFilterKind.all,
    this.ratingStars,
    this.color = ImageColorLabel.none,
  });

  final GalleryViewFilterKind kind;
  /// [withRating]: `null` = jebkurš reitings (>0), 1–5 = tieši šis.
  final int? ratingStars;
  final ImageColorLabel color;

  String get label {
    switch (kind) {
      case GalleryViewFilterKind.all:
        return 'Visas';
      case GalleryViewFilterKind.withRating:
        if (ratingStars != null) {
          return '★' * ratingStars!;
        }
        return 'Ar reitingu';
      case GalleryViewFilterKind.withoutRating:
        return 'Bez reitinga';
      case GalleryViewFilterKind.byColor:
        return color.label;
    }
  }

  bool matches(GalleryImage image) {
    switch (kind) {
      case GalleryViewFilterKind.all:
        return true;
      case GalleryViewFilterKind.withRating:
        if (ratingStars != null) {
          return image.starRating == ratingStars;
        }
        return image.starRating > 0;
      case GalleryViewFilterKind.withoutRating:
        return image.starRating == 0;
      case GalleryViewFilterKind.byColor:
        return image.colorLabel == color;
    }
  }

  GalleryViewFilter copyWith({
    GalleryViewFilterKind? kind,
    int? ratingStars,
    bool clearRatingStars = false,
    ImageColorLabel? color,
  }) =>
      GalleryViewFilter(
        kind: kind ?? this.kind,
        ratingStars: clearRatingStars ? null : (ratingStars ?? this.ratingStars),
        color: color ?? this.color,
      );
}
