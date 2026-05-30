import 'package:flutter/material.dart';

/// RAW / JPG uzlīme galerijas režģī.
class ImageFormatBadge extends StatelessWidget {
  const ImageFormatBadge({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final isRaw = label == 'RAW';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Text(
          label,
          style: TextStyle(
            color: isRaw ? Colors.orange.shade200 : Colors.lightBlue.shade100,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
