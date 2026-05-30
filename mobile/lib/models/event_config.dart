import 'delivery_target.dart';
import 'event_mode.dart';
import 'file_format.dart';
import 'ftp_preset.dart';
import 'import_policy.dart';

class EventConfig {
  EventConfig({
    required this.name,
    required this.mode,
    this.downloadFormat = DownloadFormat.both,
    this.minStarRating = 0,
    this.downloadAllImages = true,
    this.jpgQuality = 90,
    this.jpgMaxLongEdge = 3000,
    this.deliveryTarget = DeliveryTargetType.ftp,
    this.ftpPresetId,
    this.oneOffFtp,
    this.autoSendToFtp = false,
    this.importPolicy = ImportPolicy.always,
    this.ftpUploadFormat = FtpUploadFormat.jpg,
    this.photoBoxFramePath,
    this.photoBoxEditPresetId,
    this.photoBoxPrintSizeLabel = '9x13',
  });

  final String name;
  final EventMode mode;
  final DownloadFormat downloadFormat;
  final int minStarRating;
  final bool downloadAllImages;
  final int jpgQuality;
  final int jpgMaxLongEdge;
  final DeliveryTargetType deliveryTarget;
  final String? ftpPresetId;
  final OneOffFtpConfig? oneOffFtp;
  final bool autoSendToFtp;
  final ImportPolicy importPolicy;
  final FtpUploadFormat ftpUploadFormat;
  /// Absolūts ceļš uz PNG rāmi galerijas mapē (Foto kaste).
  final String? photoBoxFramePath;
  final String? photoBoxEditPresetId;
  final String photoBoxPrintSizeLabel;

  Map<String, dynamic> toJson() => {
        'name': name,
        'mode': mode.name,
        'downloadFormat': downloadFormat.name,
        'minStarRating': minStarRating,
        'downloadAllImages': downloadAllImages,
        'jpgQuality': jpgQuality,
        'jpgMaxLongEdge': jpgMaxLongEdge,
        'deliveryTarget': deliveryTarget.name,
        'ftpPresetId': ftpPresetId,
        'oneOffFtp': oneOffFtp?.toJson(),
        'autoSendToFtp': autoSendToFtp,
        'importPolicy': importPolicy.name,
        'ftpUploadFormat': ftpUploadFormat.name,
      };

  factory EventConfig.fromJson(Map<String, dynamic> json) => EventConfig(
        name: json['name'] as String? ?? '',
        mode: EventMode.values.byName(json['mode'] as String? ?? 'live'),
        downloadFormat: DownloadFormat.values
            .byName(json['downloadFormat'] as String? ?? 'both'),
        minStarRating: (json['minStarRating'] as num?)?.toInt() ?? 0,
        downloadAllImages: json['downloadAllImages'] as bool? ?? true,
        jpgQuality: (json['jpgQuality'] as num?)?.toInt() ?? 90,
        jpgMaxLongEdge: (json['jpgMaxLongEdge'] as num?)?.toInt() ?? 3000,
        deliveryTarget: DeliveryTargetType.values
            .byName(json['deliveryTarget'] as String? ?? 'ftp'),
        ftpPresetId: json['ftpPresetId'] as String?,
        oneOffFtp: OneOffFtpConfig.fromJson(
          json['oneOffFtp'] as Map<String, dynamic>?,
        ),
        autoSendToFtp: json['autoSendToFtp'] as bool? ?? false,
        importPolicy: ImportPolicy.values.firstWhere(
          (e) => e.name == (json['importPolicy'] as String?),
          orElse: () => ImportPolicy.ask,
        ),
        ftpUploadFormat: FtpUploadFormat.values
            .byName(json['ftpUploadFormat'] as String? ?? 'jpg'),
        photoBoxFramePath: json['photoBoxFramePath'] as String?,
        photoBoxEditPresetId: json['photoBoxEditPresetId'] as String?,
        photoBoxPrintSizeLabel:
            json['photoBoxPrintSizeLabel'] as String? ?? '9x13',
      );
}
