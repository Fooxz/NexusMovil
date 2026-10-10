import 'package:flutter/material.dart';

import '../theme/nexus_theme.dart';

class NexusLoading extends StatelessWidget {
  const NexusLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: NexusColors.cyan,
          ),
        ),
      ),
    );
  }
}
