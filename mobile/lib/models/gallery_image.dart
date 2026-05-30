import 'image_color_label.dart';

enum UploadStatus {
  pending,
  uploading,
  sent,
  skipped,
  excluded;

  String get label {
    switch (this) {
      case UploadStatus.pending:
        return 'Gaida';
      case UploadStatus.uploading:
        return 'Sūta…';
      case UploadStatus.sent:
        return 'Nosūtīts';
      case UploadStatus.skipped:
        return 'Izlaists';
      case UploadStatus.excluded:
        return 'Nesūtīs';
    }
  }
}

class GalleryImage {
  GalleryImage({
    required this.id,
    required this.fileName,
    this.starRating = 0,
    this.uploadStatus = UploadStatus.pending,
    this.localPath,
    this.thumbPath,
    this.colorLabel = ImageColorLabel.none,
  });

  final String id;
  final String fileName;
  final int starRating;
  final UploadStatus uploadStatus;
  final String? localPath;
  final String? thumbPath;
  final ImageColorLabel colorLabel;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'starRating': starRating,
        'uploadStatus': uploadStatus.name,
        'localPath': localPath,
        'thumbPath': thumbPath,
        'colorLabel': colorLabel.name,
      };

  factory GalleryImage.fromJson(Map<String, dynamic> json) => GalleryImage(
        id: json['id'] as String,
        fileName: json['fileName'] as String? ?? '',
        starRating: (json['starRating'] as num?)?.toInt() ?? 0,
        uploadStatus: UploadStatus.values.firstWhere(
          (e) => e.name == (json['uploadStatus'] as String?),
          orElse: () => UploadStatus.pending,
        ),
        localPath: json['localPath'] as String?,
        thumbPath: json['thumbPath'] as String?,
        colorLabel: ImageColorLabel.fromJson(json['colorLabel'] as String?),
      );

  GalleryImage copyWith({
    UploadStatus? uploadStatus,
    int? starRating,
    String? thumbPath,
    String? localPath,
    ImageColorLabel? colorLabel,
  }) =>
      GalleryImage(
        id: id,
        fileName: fileName,
        starRating: starRating ?? this.starRating,
        uploadStatus: uploadStatus ?? this.uploadStatus,
        localPath: localPath ?? this.localPath,
        thumbPath: thumbPath ?? this.thumbPath,
        colorLabel: colorLabel ?? this.colorLabel,
      );
}
