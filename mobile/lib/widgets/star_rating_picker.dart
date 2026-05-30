import 'package:flutter/material.dart';

class StarRatingPicker extends StatelessWidget {
  const StarRatingPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lejupielādēt no šī reitinga:',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
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
                size: 36,
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
