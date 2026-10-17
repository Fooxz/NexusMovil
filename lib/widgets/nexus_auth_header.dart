import 'package:flutter/material.dart';

import '../theme/nexus_theme.dart';

class NexusAuthHeader extends StatelessWidget {
  const NexusAuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: NexusColors.cyan,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'NX',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: NexusColors.onCyan,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'NEXUS',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11.5,
            height: 1.5,
            color: NexusColors.textDim,
          ),
        ),
      ],
    );
  }
}
