import 'package:flutter/material.dart';

import '../models/edit_source_info.dart';

/// Skaidro, ar kuru failu bilžu apstrāde faktiski strādā.
class EditSourceBanner extends StatelessWidget {
  const EditSourceBanner({
    super.key,
    required this.info,
    this.onDetails,
  });

  final EditSourceInfo info;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = info.isRawPipeline
        ? scheme.tertiaryContainer
        : scheme.surfaceContainerHighest;
    final fg = info.isRawPipeline
        ? scheme.onTertiaryContainer
        : scheme.onSurfaceVariant;

    return Material(
      color: bg,
      child: InkWell(
        onTap: onDetails,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FormatChip(
                label: info.originalFormatLabel,
                emphasized: info.isRawPipeline,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.headline,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Avots: ${info.originalFileName}'
                      '${info.originalFileSizeLabel != null ? ' · ${info.originalFileSizeLabel}' : ''}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: fg),
                    ),
                    Text(
                      'Apstrāde: ${info.workingFileName} (${info.workingFormatLabel})'
                      '${info.workingFileSizeLabel != null ? ' · ${info.workingFileSizeLabel}' : ''}'
                      '${info.workingDimensionsLabel != null ? ' · ${info.workingDimensionsLabel}' : ''}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: fg),
                    ),
                    if (info.rawFileDimensionsLabel != null)
                      Text(
                        'RAW izmērs: ${info.rawFileDimensionsLabel}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: fg),
                      ),
                    if (info.outputFileHint != null)
                      Text(
                        'Saglabājums → ${info.outputFileHint}',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: fg.withValues(alpha: 0.85)),
                      ),
                  ],
                ),
              ),
              if (onDetails != null)
                IconButton(
                  icon: Icon(Icons.info_outline, color: fg, size: 20),
                  tooltip: 'Sīkāk par avotu',
                  onPressed: onDetails,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({required this.label, required this.emphasized});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: emphasized ? scheme.tertiary : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: emphasized ? scheme.onTertiary : scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

void showEditSourceDetailsDialog(BuildContext context, EditSourceInfo info) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Apstrādes avots'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(info.headline, style: Theme.of(ctx).textTheme.titleSmall),
            const SizedBox(height: 12),
            for (final line in info.detailLines) ...[
              Text('• $line'),
              const SizedBox(height: 6),
            ],
            const Divider(),
            _DetailRow('Galerijas fails', info.originalFileName),
            _DetailRow('Formāts', info.originalFormatLabel),
            if (info.originalFileSizeLabel != null)
              _DetailRow('Avota izmērs', info.originalFileSizeLabel!),
            _DetailRow('Apstrādes fails', info.workingFileName),
            _DetailRow('Apstrādes veids', info.workingFormatLabel),
            if (info.workingDimensionsLabel != null)
              _DetailRow('Priekšskata px', info.workingDimensionsLabel!),
            if (info.rawFileDimensionsLabel != null)
              _DetailRow('RAW EXIF', info.rawFileDimensionsLabel!),
            if (info.outputFileHint != null)
              _DetailRow('Saglabājums', info.outputFileHint!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Aizvērt'),
        ),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
