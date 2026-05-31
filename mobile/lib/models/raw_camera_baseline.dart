/// Camera "As Shot" baseline from native RAW metadata (NEF/ARW…).
class RawCameraBaseline {
  const RawCameraBaseline({
    required this.exposureEv,
    required this.kelvin,
    required this.tint,
    required this.contrast,
    required this.shadows,
    required this.highlights,
    required this.sharpness,
    required this.saturation,
    required this.sources,
    this.redGain = 1,
    this.greenGain = 1,
    this.blueGain = 1,
    this.colorSpace = 'SRGB',
    this.pictureControl,
    this.cameraModel,
    this.exposureCompensationEv = 0,
    this.activeDLighting,
    this.highIsoNoiseReduction,
    this.rawWidth = 0,
    this.rawHeight = 0,
    this.usedFallback = true,
  });

  final double exposureEv;
  final double exposureCompensationEv;
  final double kelvin;
  final double tint;
  final double redGain;
  final double greenGain;
  final double blueGain;
  final double contrast;
  final double shadows;
  final double highlights;
  final double sharpness;
  final double saturation;
  final String colorSpace;
  final String? pictureControl;
  final String? cameraModel;
  final String? activeDLighting;
  final String? highIsoNoiseReduction;
  final int rawWidth;
  final int rawHeight;
  final List<String> sources;
  final bool usedFallback;

  factory RawCameraBaseline.fromMap(Map<dynamic, dynamic> map) {
    final sources = (map['sources'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    return RawCameraBaseline(
      exposureEv: (map['exposureEv'] as num?)?.toDouble() ?? 0,
      kelvin: (map['kelvin'] as num?)?.toDouble() ?? 6500,
      tint: (map['tint'] as num?)?.toDouble() ?? 0,
      redGain: (map['redGain'] as num?)?.toDouble() ?? 1,
      greenGain: (map['greenGain'] as num?)?.toDouble() ?? 1,
      blueGain: (map['blueGain'] as num?)?.toDouble() ?? 1,
      contrast: (map['contrast'] as num?)?.toDouble() ?? 0,
      shadows: (map['shadows'] as num?)?.toDouble() ?? 0,
      highlights: (map['highlights'] as num?)?.toDouble() ?? 0,
      sharpness: (map['sharpness'] as num?)?.toDouble() ?? 0,
      saturation: (map['saturation'] as num?)?.toDouble() ?? 1,
      colorSpace: map['colorSpace'] as String? ?? 'SRGB',
      pictureControl: map['pictureControl'] as String?,
      cameraModel: map['cameraModel'] as String?,
      exposureCompensationEv:
          (map['exposureCompensationEv'] as num?)?.toDouble() ?? 0,
      activeDLighting: map['activeDLighting'] as String?,
      highIsoNoiseReduction: map['highIsoNoiseReduction'] as String?,
      rawWidth: (map['rawWidth'] as num?)?.toInt() ?? 0,
      rawHeight: (map['rawHeight'] as num?)?.toInt() ?? 0,
      sources: sources,
      usedFallback: map['usedFallback'] as bool? ?? sources.isEmpty,
    );
  }
}
