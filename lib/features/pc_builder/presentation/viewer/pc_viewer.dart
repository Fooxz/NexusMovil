import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/nexus_theme.dart';
import '../../domain/build_scene.dart';
import '../../pc_builder_providers.dart';
import '../part_picker_screen.dart';
import 'viewer_host.dart';

const _viewerHeight = 260.0;

/// Vista 3D de la configuración (RF-090): se puede girar y acercar, marca en
/// rosa las piezas incompatibles y, al tocar una pieza, abre su selector.
class PcViewer extends ConsumerStatefulWidget {
  const PcViewer({super.key});

  @override
  ConsumerState<PcViewer> createState() => _PcViewerState();
}

class _PcViewerState extends ConsumerState<PcViewer> {
  bool _drawn = false;
  bool _failed = false;
  int _missingModels = 0;

  void _onEvent(ViewerEvent event) {
    switch (event) {
      case ViewerLoaded(:final failed):
        setState(() {
          _drawn = true;
          _missingModels = failed.length;
        });
      case ViewerFailure():
        setState(() => _failed = true);
      case ViewerTap(:final part):
        _openPicker(part);
      case ViewerReady():
        break;
    }
  }

  void _openPicker(String offerId) {
    final selection =
        ref.read(pcBuilderControllerProvider).value?.selection ?? const {};
    final slots = ref.read(builderSlotsProvider).value ?? const [];
    for (final slot in slots) {
      if (selection[slot.category] == offerId) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => PartPickerScreen(slot: slot)),
        );
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = ref.watch(viewerHostProvider);
    final scene = ref.watch(viewerSceneProvider);
    // En la vista de un armado no hay piezas que cambiar.
    final previewing = ref.watch(prebuiltPreviewProvider.select((id) => id != null));

    final Widget stage;
    if (host == null || _failed) {
      stage = _ViewerMessage(
        host == null
            ? 'La vista 3D está disponible en Android, iOS y la web.'
            : 'Este dispositivo no puede mostrar la vista 3D.',
      );
    } else if (scene.value case final scene?) {
      stage = Stack(
        fit: StackFit.expand,
        children: [
          // Aísla el repintado del visor del resto de la página (R9).
          RepaintBoundary(child: host(scene.toMessage(), _onEvent)),
          if (!_drawn) const Center(child: _Spinner()),
        ],
      );
    } else if (scene.hasError) {
      stage = const _ViewerMessage('No se pudo cargar la vista 3D.');
    } else {
      stage = const Center(child: _Spinner());
    }

    final credits = scene.value?.credits ?? const <ModelCredit>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('VISTA 3D // GABINETE', style: _labelStyle),
            ),
            if (scene.isLoading && scene.hasValue) const _Spinner(size: 12),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: _viewerHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF10161B), Color(0xFF0A0D10)],
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  stage,
                  for (final corner in _Corner.values) _CornerBracket(corner),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (host != null && !_failed)
          Text(
            previewing
                ? 'Arrastra para girar y pellizca para acercar.'
                : 'Arrastra para girar, pellizca para acercar y toca una pieza '
                      'para cambiarla.',
            style: _hintStyle,
          ),
        if (_missingModels > 0)
          const Text(
            'Algunos modelos no cargaron: esas piezas se ven genéricas.',
            style: _hintStyle,
          ),
        if (credits.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                foregroundColor: NexusColors.textDim,
                textStyle: _hintStyle,
              ),
              onPressed: () => _showCredits(context, credits),
              child: const Text('Créditos de los modelos 3D'),
            ),
          ),
      ],
    );
  }
}

const _labelStyle = TextStyle(
  fontSize: 9,
  fontWeight: FontWeight.bold,
  letterSpacing: 0.6,
  color: NexusColors.textDim,
);

const _hintStyle = TextStyle(fontSize: 11, color: NexusColors.textFaint);

/// Las licencias CC BY exigen nombrar la obra, el autor, la licencia y la
/// fuente.
void _showCredits(BuildContext context, List<ModelCredit> credits) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Modelos 3D'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final credit in credits)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SelectableText(
                  '"${credit.title}" de ${credit.author}, '
                  '${licenseName(credit.license)}.'
                  '${credit.sourceUrl == null ? '' : '\n${credit.sourceUrl}'}',
                  style: NexusText.body,
                ),
              ),
            const Text(
              'Las demás piezas se generan con sus medidas típicas.',
              style: _hintStyle,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

String licenseName(String license) => switch (license) {
  'CC0-1.0' => 'dominio público (CC0 1.0)',
  'CC-BY-3.0' => 'licencia CC BY 3.0 (creativecommons.org/licenses/by/3.0)',
  'CC-BY-4.0' => 'licencia CC BY 4.0 (creativecommons.org/licenses/by/4.0)',
  'propia' => 'modelo propio de NEXUS',
  _ => license,
};

class _ViewerMessage extends StatelessWidget {
  const _ViewerMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.view_in_ar, size: 48, color: NexusColors.cyan),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: NexusText.body),
        ],
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner({this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: const CircularProgressIndicator(
        strokeWidth: 2,
        color: NexusColors.cyan,
      ),
    );
  }
}

enum _Corner { topLeft, topRight, bottomLeft, bottomRight }

/// Esquinas decorativas del marco del visor.
class _CornerBracket extends StatelessWidget {
  const _CornerBracket(this.corner);

  final _Corner corner;

  @override
  Widget build(BuildContext context) {
    const side = BorderSide(color: NexusColors.cyan, width: 2);
    final top = corner == _Corner.topLeft || corner == _Corner.topRight;
    final left = corner == _Corner.topLeft || corner == _Corner.bottomLeft;
    return Positioned(
      top: top ? 8 : null,
      bottom: top ? null : 8,
      left: left ? 8 : null,
      right: left ? null : 8,
      child: IgnorePointer(
        child: SizedBox.square(
          dimension: 14,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: top ? side : BorderSide.none,
                bottom: top ? BorderSide.none : side,
                left: left ? side : BorderSide.none,
                right: left ? BorderSide.none : side,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
