import 'package:flutter/material.dart';

import '../../../core/errors/app_failure.dart';
import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_auth_header.dart';
import '../../../widgets/nexus_widgets.dart';
import '../domain/auth_models.dart';

/// Marco común de las pantallas de cuenta: tarjeta centrada con encabezado y
/// botón de cerrar cuando la pantalla se abrió encima de otra.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: NexusColors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border.all(color: NexusColors.border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      NexusAuthHeader(title: title, subtitle: subtitle),
                      const SizedBox(height: 24),
                      child,
                    ],
                  ),
                ),
              ),
            ),
            if (canPop)
              Positioned(
                top: 4,
                left: 4,
                child: IconButton(
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close, color: NexusColors.textDim),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Mensaje de error de un envío fallido.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner(this.error, {super.key});

  final Object error;

  static String messageFor(Object error) => error is AppFailure
      ? error.userMessage
      : const UnexpectedFailure().userMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: NexusColors.pink.withValues(alpha: 0.12),
        border: Border.all(color: NexusColors.pink),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 16, color: NexusColors.pink),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              messageFor(error),
              style: const TextStyle(fontSize: 11.5, color: NexusColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta y campo, con el espaciado de los formularios de cuenta.
class AuthField extends StatelessWidget {
  const AuthField({super.key, required this.label, required this.field});

  final String label;
  final Widget field;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [NexusFieldLabel(label), const SizedBox(height: 6), field],
      ),
    );
  }
}

/// Enlace de texto en cian (por ejemplo, "Crear cuenta").
class AuthLink extends StatelessWidget {
  const AuthLink({
    super.key,
    required this.prefix,
    required this.label,
    required this.onTap,
  });

  final String prefix;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          prefix,
          style: const TextStyle(fontSize: 11, color: NexusColors.textDim),
        ),
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: NexusColors.cyan,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Muestra el texto completo de un documento legal.
Future<void> showLegalDocument(BuildContext context, LegalDocument document) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: NexusColors.bgAlt,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                document.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Versión ${document.version}',
                style: const TextStyle(fontSize: 11, color: NexusColors.textDim),
              ),
              const SizedBox(height: 14),
              Text(
                document.content,
                style: const TextStyle(fontSize: 12.5, color: NexusColors.text),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
