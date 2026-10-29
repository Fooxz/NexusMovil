// lib/widgets/nexus_notice.dart
//
// Aviso flotante de NEXUS (agregado al carrito, errores, confirmaciones):
// tarjeta oscura con borde de color, ícono, título, detalle y una acción.

import 'package:flutter/material.dart';

import '../theme/nexus_theme.dart';

enum NexusNoticeTone { success, error, info }

/// Muestra el aviso en [messenger] y reemplaza el que estuviera visible.
/// Con [actionLabel] y [onAction] agrega un botón que cierra el aviso.
void showNexusNotice(
  ScaffoldMessengerState? messenger, {
  required String title,
  String? message,
  NexusNoticeTone tone = NexusNoticeTone.success,
  IconData? icon,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  if (messenger == null) return;
  final color = switch (tone) {
    NexusNoticeTone.success => NexusColors.cyan,
    NexusNoticeTone.error => NexusColors.pink,
    NexusNoticeTone.info => NexusColors.textDim,
  };
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: NexusColors.cardAlt,
        elevation: 8,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.55)),
        ),
        content: _NoticeContent(
          title: title,
          message: message,
          color: color,
          icon: icon ??
              switch (tone) {
                NexusNoticeTone.success => Icons.check_circle,
                NexusNoticeTone.error => Icons.error_outline,
                NexusNoticeTone.info => Icons.info_outline,
              },
          actionLabel: actionLabel,
          onAction: onAction == null
              ? null
              : () {
                  messenger.hideCurrentSnackBar();
                  onAction();
                },
        ),
      ),
    );
}

class _NoticeContent extends StatelessWidget {
  const _NoticeContent({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String? message;
  final Color color;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: NexusColors.text,
                ),
              ),
              if (message case final message?) ...[
                const SizedBox(height: 2),
                Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, height: 1.35, color: NexusColors.textDim),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: NexusColors.onCyan,
              backgroundColor: NexusColors.cyan,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.3),
            ),
            child: Text(actionLabel!),
          ),
        ],
      ],
    );
  }
}
