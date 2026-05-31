class EditPreset {
  EditPreset({
    required this.id,
    required this.name,
    this.exposure = 0,
    this.contrast = 1,
    this.saturation = 1,
    this.temperature = 0,
    this.tint = 0,
    this.shadows = 0,
    this.highlights = 0,
    this.sharpness = 0,
    this.rotationDegrees = 0,
    this.cropAspect,
  });

  final String id;
  final String name;
  /// Ekspozīcija EV (−5…+5).
  final double exposure;
  /// Kontrasts (−100…+100) vai mantots reizinātājs 0.5…2.
  final double contrast;
  final double saturation;
  /// Kelvin (2000–50000) vai mantota −1…1 (tiks konvertēts ielādējot).
  final double temperature;
  /// Tint −150…150 vai mantots −1…1.
  final double tint;
  /// Ēnu pacelšana (-1 … 1).
  final double shadows;
  /// Spilgtumi (-100 … 100) vai mantots (-1 … 1).
  final double highlights;
  /// Asums 0–100 (USM).
  final double sharpness;
  final int rotationDegrees;
  final double? cropAspect;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'exposure': exposure,
        'brightness': exposure,
        'contrast': contrast,
        'saturation': saturation,
        'temperature': temperature,
        'tint': tint,
        'shadows': shadows,
        'highlights': highlights,
        'rotationDegrees': rotationDegrees,
        'cropAspect': cropAspect,
      };

  factory EditPreset.fromJson(Map<String, dynamic> json) {
    final warmthLegacy = (json['warmth'] as num?)?.toDouble() ?? 0;
    final rawExposure = (json['exposure'] as num?)?.toDouble() ??
        (json['brightness'] as num?)?.toDouble() ??
        0;
    return EditPreset(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Preset',
      exposure: rawExposure,
      contrast: (json['contrast'] as num?)?.toDouble() ?? 1,
      saturation: (json['saturation'] as num?)?.toDouble() ?? 1,
      temperature: (json['temperature'] as num?)?.toDouble() ?? warmthLegacy,
      tint: (json['tint'] as num?)?.toDouble() ?? 0,
      shadows: (json['shadows'] as num?)?.toDouble() ?? 0,
      highlights: (json['highlights'] as num?)?.toDouble() ?? 0,
      rotationDegrees: (json['rotationDegrees'] as num?)?.toInt() ?? 0,
      cropAspect: (json['cropAspect'] as num?)?.toDouble(),
    );
  }

  EditPreset copyWith({
    String? name,
    double? exposure,
    double? contrast,
    double? saturation,
    double? temperature,
    double? tint,
    double? shadows,
    double? highlights,
    int? rotationDegrees,
    double? cropAspect,
    bool clearCropAspect = false,
  }) =>
      EditPreset(
        id: id,
        name: name ?? this.name,
        exposure: exposure ?? this.exposure,
        contrast: contrast ?? this.contrast,
        saturation: saturation ?? this.saturation,
        temperature: temperature ?? this.temperature,
        tint: tint ?? this.tint,
        shadows: shadows ?? this.shadows,
        highlights: highlights ?? this.highlights,
        sharpness: sharpness ?? this.sharpness,
        rotationDegrees: rotationDegrees ?? this.rotationDegrees,
        cropAspect: clearCropAspect ? null : (cropAspect ?? this.cropAspect),
      );
}
