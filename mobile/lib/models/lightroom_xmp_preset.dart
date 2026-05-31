/// Imported Adobe Lightroom `.xmp` development preset (stored locally).
class LightroomXmpPreset {
  const LightroomXmpPreset({
    required this.id,
    required this.name,
    required this.xmpPath,
    this.originalFileName,
    required this.importedAt,
  });

  final String id;
  final String name;
  /// Absolute path to `.xmp` in app documents.
  final String xmpPath;
  final String? originalFileName;
  final DateTime importedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'xmpPath': xmpPath,
        'originalFileName': originalFileName,
        'importedAt': importedAt.toIso8601String(),
      };

  factory LightroomXmpPreset.fromJson(Map<String, dynamic> json) =>
      LightroomXmpPreset(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Lightroom preset',
        xmpPath: json['xmpPath'] as String,
        originalFileName: json['originalFileName'] as String?,
        importedAt: DateTime.tryParse(json['importedAt'] as String? ?? '') ??
            DateTime.now(),
      );

  LightroomXmpPreset copyWith({String? name}) => LightroomXmpPreset(
        id: id,
        name: name ?? this.name,
        xmpPath: xmpPath,
        originalFileName: originalFileName,
        importedAt: importedAt,
      );
}
