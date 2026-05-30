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
    this.importAllowedStars = const [1, 2, 3, 4, 5],
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
  /// Vecā lauka saderībai — minimums no [importAllowedStars].
  final int minStarRating;
  final bool downloadAllImages;
  /// Kuri reitingi (1–5) importēt, ja [downloadAllImages] ir false.
  final List<int> importAllowedStars;
  final int jpgQuality;
  final int jpgMaxLongEdge;
  final DeliveryTargetType deliveryTarget;
  final String? ftpPresetId;
  final OneOffFtpConfig? oneOffFtp;
  final bool autoSendToFtp;
  final ImportPolicy importPolicy;
  final FtpUploadFormat ftpUploadFormat;
  final String? photoBoxFramePath;
  final String? photoBoxEditPresetId;
  final String photoBoxPrintSizeLabel;

  /// Tikai bildes ar EXIF reitingu un atļauto zvaigžņu skaitu.
  bool acceptsImportRating(int stars) {
    if (downloadAllImages) return true;
    if (stars < 1 || stars > 5) return false;
    return importAllowedStars.contains(stars);
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'mode': mode.name,
        'downloadFormat': downloadFormat.name,
        'minStarRating': minStarRating,
        'downloadAllImages': downloadAllImages,
        'importAllowedStars': importAllowedStars,
        'jpgQuality': jpgQuality,
        'jpgMaxLongEdge': jpgMaxLongEdge,
        'deliveryTarget': deliveryTarget.name,
        'ftpPresetId': ftpPresetId,
        'oneOffFtp': oneOffFtp?.toJson(),
        'autoSendToFtp': autoSendToFtp,
        'importPolicy': importPolicy.name,
        'ftpUploadFormat': ftpUploadFormat.name,
        'photoBoxFramePath': photoBoxFramePath,
        'photoBoxEditPresetId': photoBoxEditPresetId,
        'photoBoxPrintSizeLabel': photoBoxPrintSizeLabel,
      };

  factory EventConfig.fromJson(Map<String, dynamic> json) {
    final allowed = _parseImportAllowedStars(json);
    return EventConfig(
      name: json['name'] as String? ?? '',
      mode: EventMode.values.byName(json['mode'] as String? ?? 'live'),
      downloadFormat: DownloadFormat.values
          .byName(json['downloadFormat'] as String? ?? 'both'),
      minStarRating: allowed.isEmpty
          ? 0
          : allowed.reduce((a, b) => a < b ? a : b),
      downloadAllImages: json['downloadAllImages'] as bool? ?? true,
      importAllowedStars: allowed,
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

  static List<int> _parseImportAllowedStars(Map<String, dynamic> json) {
    final raw = json['importAllowedStars'] as List<dynamic>?;
    if (raw != null && raw.isNotEmpty) {
      return raw
          .map((e) => (e as num).toInt())
          .where((s) => s >= 1 && s <= 5)
          .toSet()
          .toList()
        ..sort();
    }
    final min = (json['minStarRating'] as num?)?.toInt() ?? 0;
    if (min >= 1) {
      return [for (var i = min; i <= 5; i++) i];
    }
    return [1, 2, 3, 4, 5];
  }
}
