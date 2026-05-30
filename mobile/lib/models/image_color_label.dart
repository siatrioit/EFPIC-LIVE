import 'package:flutter/material.dart';

/// Lightroom-stila krāsu atzīme galerijas bildei.
enum ImageColorLabel {
  none,
  red,
  yellow,
  green,
  blue,
  purple;

  String get label {
    switch (this) {
      case ImageColorLabel.none:
        return 'Bez krāsas';
      case ImageColorLabel.red:
        return 'Sarkana';
      case ImageColorLabel.yellow:
        return 'Dzeltena';
      case ImageColorLabel.green:
        return 'Zaļa';
      case ImageColorLabel.blue:
        return 'Zila';
      case ImageColorLabel.purple:
        return 'Violeta';
    }
  }

  Color get color {
    switch (this) {
      case ImageColorLabel.none:
        return Colors.transparent;
      case ImageColorLabel.red:
        return const Color(0xFFE53935);
      case ImageColorLabel.yellow:
        return const Color(0xFFFDD835);
      case ImageColorLabel.green:
        return const Color(0xFF43A047);
      case ImageColorLabel.blue:
        return const Color(0xFF1E88E5);
      case ImageColorLabel.purple:
        return const Color(0xFF8E24AA);
    }
  }

  static ImageColorLabel fromJson(String? value) {
    if (value == null || value.isEmpty) return ImageColorLabel.none;
    return ImageColorLabel.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ImageColorLabel.none,
    );
  }
}
