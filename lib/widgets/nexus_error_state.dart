import 'package:flutter/material.dart';

import '../theme/nexus_theme.dart';
import 'nexus_widgets.dart';

class NexusErrorState extends StatelessWidget {
  const NexusErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: NexusColors.pink, size: 28),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: NexusColors.textDim),
          ),
          const SizedBox(height: 12),
          NexusOutlineButton(
            label: 'REINTENTAR',
            onPressed: onRetry,
            color: NexusColors.cyan,
            borderColor: NexusColors.cyan,
            compact: true,
          ),
        ],
      ),
    );
  }
}
