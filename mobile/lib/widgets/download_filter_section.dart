import 'package:flutter/material.dart';

/// Live / Download — importēt tikai ar EXIF reitingu; izvēle ★1–★5.
class DownloadFilterSection extends StatelessWidget {
  const DownloadFilterSection({
    super.key,
    required this.allImages,
    required this.allowedStars,
    required this.onAllImagesChanged,
    required this.onAllowedStarsChanged,
  });

  final bool allImages;
  final Set<int> allowedStars;
  final ValueChanged<bool> onAllImagesChanged;
  final ValueChanged<Set<int>> onAllowedStarsChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Lejupielādēt visas bildes'),
          subtitle: const Text(
            'Izslēdz — importē tikai ar reitingu kamerā (EXIF)',
          ),
          value: allImages,
          onChanged: onAllImagesChanged,
        ),
        if (!allImages) ...[
          const SizedBox(height: 8),
          Text(
            'Kuri reitingi importēt:',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: List.generate(5, (i) {
              final star = i + 1;
              final selected = allowedStars.contains(star);
              return FilterChip(
                label: Text('★$star'),
                selected: selected,
                onSelected: (v) {
                  final next = Set<int>.from(allowedStars);
                  if (v) {
                    next.add(star);
                  } else {
                    next.remove(star);
                  }
                  if (next.isEmpty) return;
                  onAllowedStarsChanged(next);
                },
              );
            }),
          ),
          if (allowedStars.isEmpty)
            Text(
              'Izvēlies vismaz vienu reitingu',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
        ],
      ],
    );
  }
}
