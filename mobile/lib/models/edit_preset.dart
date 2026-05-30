class EditPreset {
  EditPreset({
    required this.id,
    required this.name,
    this.brightness = 0,
    this.contrast = 1,
    this.saturation = 1,
    this.temperature = 0,
    this.tint = 0,
    this.shadows = 0,
    this.rotationDegrees = 0,
    this.cropAspect,
  });

  final String id;
  final String name;
  /// -1 … 1
  final double brightness;
  /// 0.5 … 2
  final double contrast;
  final double saturation;
  /// Baltā balansa temperatūra (auksts ← 0 → silts).
  final double temperature;
  /// Zaļš ← 0 → magenta.
  final double tint;
  /// Ēnu pacelšana (-1 … 1).
  final double shadows;
  final int rotationDegrees;
  final double? cropAspect;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'brightness': brightness,
        'contrast': contrast,
        'saturation': saturation,
        'temperature': temperature,
        'tint': tint,
        'shadows': shadows,
        'rotationDegrees': rotationDegrees,
        'cropAspect': cropAspect,
      };

  factory EditPreset.fromJson(Map<String, dynamic> json) {
    final warmthLegacy = (json['warmth'] as num?)?.toDouble() ?? 0;
    return EditPreset(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Preset',
      brightness: (json['brightness'] as num?)?.toDouble() ?? 0,
      contrast: (json['contrast'] as num?)?.toDouble() ?? 1,
      saturation: (json['saturation'] as num?)?.toDouble() ?? 1,
      temperature: (json['temperature'] as num?)?.toDouble() ?? warmthLegacy,
      tint: (json['tint'] as num?)?.toDouble() ?? 0,
      shadows: (json['shadows'] as num?)?.toDouble() ?? 0,
      rotationDegrees: (json['rotationDegrees'] as num?)?.toInt() ?? 0,
      cropAspect: (json['cropAspect'] as num?)?.toDouble(),
    );
  }

  EditPreset copyWith({
    String? name,
    double? brightness,
    double? contrast,
    double? saturation,
    double? temperature,
    double? tint,
    double? shadows,
    int? rotationDegrees,
    double? cropAspect,
    bool clearCropAspect = false,
  }) =>
      EditPreset(
        id: id,
        name: name ?? this.name,
        brightness: brightness ?? this.brightness,
        contrast: contrast ?? this.contrast,
        saturation: saturation ?? this.saturation,
        temperature: temperature ?? this.temperature,
        tint: tint ?? this.tint,
        shadows: shadows ?? this.shadows,
        rotationDegrees: rotationDegrees ?? this.rotationDegrees,
        cropAspect: clearCropAspect ? null : (cropAspect ?? this.cropAspect),
      );
}
