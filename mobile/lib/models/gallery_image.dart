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
  });

  final String id;
  final String fileName;
  final int starRating;
  final UploadStatus uploadStatus;
  final String? localPath;
  final String? thumbPath;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'starRating': starRating,
        'uploadStatus': uploadStatus.name,
        'localPath': localPath,
        'thumbPath': thumbPath,
      };

  factory GalleryImage.fromJson(Map<String, dynamic> json) => GalleryImage(
        id: json['id'] as String,
        fileName: json['fileName'] as String? ?? '',
        starRating: (json['starRating'] as num?)?.toInt() ?? 0,
        uploadStatus: UploadStatus.values
            .byName(json['uploadStatus'] as String? ?? 'pending'),
        localPath: json['localPath'] as String?,
        thumbPath: json['thumbPath'] as String?,
      );

  GalleryImage copyWith({
    UploadStatus? uploadStatus,
    int? starRating,
  }) =>
      GalleryImage(
        id: id,
        fileName: fileName,
        starRating: starRating ?? this.starRating,
        uploadStatus: uploadStatus ?? this.uploadStatus,
        localPath: localPath,
        thumbPath: thumbPath,
      );
}
