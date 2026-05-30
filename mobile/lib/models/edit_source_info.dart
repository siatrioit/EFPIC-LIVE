import '../services/image_edit_service.dart';

/// Kā apstrāde saistās ar galerijas failu (skaidrojums lietotājam).
enum EditSourceKind {
  /// Tieši .jpg / .jpeg no diska.
  directJpeg,
  /// RAW fails; pikseļi no iegultā JPG (_emb.jpg).
  rawEmbeddedPreview,
  /// RAW bez izveidota priekšskata (pagaidu thumb).
  rawThumbFallback,
}

class EditSourceInfo {
  const EditSourceInfo({
    required this.source,
    required this.kind,
    required this.originalFileName,
    required this.originalFormatLabel,
    required this.workingFileName,
    required this.workingFormatLabel,
    required this.headline,
    required this.detailLines,
    this.originalFileSizeLabel,
    this.workingFileSizeLabel,
    this.workingDimensionsLabel,
    this.rawFileDimensionsLabel,
    this.outputFileHint,
  });

  final EditSource source;
  final EditSourceKind kind;
  final String originalFileName;
  final String originalFormatLabel;
  final String workingFileName;
  final String workingFormatLabel;
  final String headline;
  final List<String> detailLines;
  final String? originalFileSizeLabel;
  final String? workingFileSizeLabel;
  final String? workingDimensionsLabel;
  final String? rawFileDimensionsLabel;
  final String? outputFileHint;

  bool get isRawPipeline =>
      kind == EditSourceKind.rawEmbeddedPreview ||
      kind == EditSourceKind.rawThumbFallback;
}
