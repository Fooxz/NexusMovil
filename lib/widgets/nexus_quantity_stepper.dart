import 'package:flutter/material.dart';

import '../theme/nexus_theme.dart';

class NexusQuantityStepper extends StatelessWidget {
  const NexusQuantityStepper({
    super.key,
    required this.value,
    required this.onIncrement,
    required this.onDecrement,
    this.compact = false,
  });

  final int value;

  /// `null` deshabilita el botón (por ejemplo, en el máximo o en el mínimo).
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 4),
      decoration: BoxDecoration(
        border: Border.all(color: NexusColors.border),
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            padding: compact ? EdgeInsets.zero : null,
            constraints: compact ? const BoxConstraints() : null,
            onPressed: onDecrement,
            tooltip: 'Quitar una unidad',
            icon: Icon(
              Icons.remove,
              size: compact ? 14 : 16,
              color: _iconColor(onDecrement),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 0),
            child: Text(
              value.toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: compact ? FontWeight.normal : FontWeight.bold,
                color: NexusColors.text,
              ),
            ),
          ),
          IconButton(
            padding: compact ? EdgeInsets.zero : null,
            constraints: compact ? const BoxConstraints() : null,
            onPressed: onIncrement,
            tooltip: 'Agregar una unidad',
            icon: Icon(
              Icons.add,
              size: compact ? 14 : 16,
              color: _iconColor(onIncrement),
            ),
          ),
        ],
      ),
    );
  }

  static Color _iconColor(VoidCallback? onPressed) => onPressed == null
      ? NexusColors.textFaint.withValues(alpha: 0.4)
      : NexusColors.textDim;
}
