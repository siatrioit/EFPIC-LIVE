class EditPreset {
  EditPreset({
    required this.id,
    required this.name,
    this.brightness = 0,
    this.contrast = 1,
    this.saturation = 1,
    this.warmth = 0,
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
  /// -1 … 1 (siltums / balans)
  final double warmth;
  final int rotationDegrees;
  /// null = brīvais; 1 kvadrāts; 4/5; 9/16 u.c.
  final double? cropAspect;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'brightness': brightness,
        'contrast': contrast,
        'saturation': saturation,
        'warmth': warmth,
        'rotationDegrees': rotationDegrees,
        'cropAspect': cropAspect,
      };

  factory EditPreset.fromJson(Map<String, dynamic> json) => EditPreset(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Preset',
        brightness: (json['brightness'] as num?)?.toDouble() ?? 0,
        contrast: (json['contrast'] as num?)?.toDouble() ?? 1,
        saturation: (json['saturation'] as num?)?.toDouble() ?? 1,
        warmth: (json['warmth'] as num?)?.toDouble() ?? 0,
        rotationDegrees: (json['rotationDegrees'] as num?)?.toInt() ?? 0,
        cropAspect: (json['cropAspect'] as num?)?.toDouble(),
      );

  EditPreset copyWith({
    String? name,
    double? brightness,
    double? contrast,
    double? saturation,
    double? warmth,
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
        warmth: warmth ?? this.warmth,
        rotationDegrees: rotationDegrees ?? this.rotationDegrees,
        cropAspect: clearCropAspect ? null : (cropAspect ?? this.cropAspect),
      );
}
