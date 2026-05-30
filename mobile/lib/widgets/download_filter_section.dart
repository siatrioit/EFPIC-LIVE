import 'package:flutter/material.dart';

import 'star_rating_picker.dart';

class DownloadFilterSection extends StatelessWidget {
  const DownloadFilterSection({
    super.key,
    required this.allImages,
    required this.minStars,
    required this.onAllImagesChanged,
    required this.onMinStarsChanged,
  });

  final bool allImages;
  final int minStars;
  final ValueChanged<bool> onAllImagesChanged;
  final ValueChanged<int> onMinStarsChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Lejupielādēt visas bildes'),
          subtitle: const Text(
            'Izslēdz, lai ņemtu tikai ar izvēlēto zvaigžņu reitingu',
          ),
          value: allImages,
          onChanged: onAllImagesChanged,
        ),
        if (!allImages) ...[
          const SizedBox(height: 8),
          StarRatingPicker(
            value: minStars.clamp(1, 5),
            onChanged: onMinStarsChanged,
          ),
        ],
      ],
    );
  }
}
