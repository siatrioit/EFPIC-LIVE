import 'package:flutter/material.dart';

class StarRatingPicker extends StatelessWidget {
  const StarRatingPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.compact = false,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;
  /// Kompakts režīms (skatītājs) — bez virsraksta, mazākas zvaigznes.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final starSize = compact ? 40.0 : 36.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact)
          Text(
            'Lejupielādēt no šī reitinga:',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        if (!compact) const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final star = i + 1;
            final filled = star <= value;
            return IconButton(
              onPressed: enabled ? () => onChanged(star) : null,
              icon: Icon(
                filled ? Icons.star : Icons.star_border,
                color: Colors.amber.shade700,
                size: starSize,
              ),
            );
          }),
        ),
        Center(
          child: Text(
            value == 1 ? '$value zvaigzne' : '$value zvaigznes',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ],
    );
  }
}
