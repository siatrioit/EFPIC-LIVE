import 'package:flutter/material.dart';

import '../models/gallery_image.dart';
import '../models/image_color_label.dart';
import '../services/image_info_service.dart';

/// Bilžu metadatu panelis (skatītājs).
Future<void> showImageInfoSheet(
  BuildContext context, {
  required GalleryImage image,
}) async {
  final info = await ImageInfoService.instance.loadForImage(image);
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bildes dati',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                info.fileName,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              _InfoRow('Formāts', info.formatLabel),
              _InfoRow('Izmērs', info.fileSizeLabel),
              if (info.dimensionsLabel != null)
                _InfoRow('Izšķirtspēja', info.dimensionsLabel!),
              if (info.dateTaken != null)
                _InfoRow('Datums', info.dateTaken!),
              if (info.cameraLabel != null)
                _InfoRow('Kamera', info.cameraLabel!),
              if (info.exifRating != null && info.exifRating! > 0)
                _InfoRow('EXIF reitings', '★${info.exifRating}'),
              if (info.orientation != null && info.orientation != 1)
                _InfoRow('EXIF orientācija', '${info.orientation}'),
              if (info.starRating > 0)
                _InfoRow('Lietotnes reitings', '★' * info.starRating),
              if (image.colorLabel != ImageColorLabel.none)
                _InfoRow('Krāsa', image.colorLabel.label),
              if (info.uploadStatusLabel != null)
                _InfoRow('FTP statuss', info.uploadStatusLabel!),
              if (info.localPath != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Ceļš',
                  style: Theme.of(ctx).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                SelectableText(
                  info.localPath!,
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
