import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'viewer_host_stub.dart'
    if (dart.library.js_interop) 'viewer_host_web.dart'
    if (dart.library.io) 'viewer_host_io.dart';

/// Página del visor (generada por tool/viewer).
const viewerAsset = 'assets/viewer/viewer.html';

/// Muestra el visor 3D de la plataforma: le envía [sceneMessage] (el mensaje
/// `scene` de ViewerScene.toMessage) cada vez que cambia y avisa sus eventos.
typedef ViewerHostBuilder =
    Widget Function(String sceneMessage, ValueChanged<ViewerEvent> onEvent);

/// Nulo donde no hay visor (escritorio y pruebas): la pantalla lo explica.
/// Las pruebas lo reemplazan por uno falso.
final viewerHostProvider = Provider<ViewerHostBuilder?>(
  (ref) => platformViewerHost(),
);

/// Mensajes que llegan del visor.
sealed class ViewerEvent {
  const ViewerEvent();

  /// Nulo si el texto no es un mensaje conocido.
  static ViewerEvent? parse(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      return null;
    }
    return switch (json) {
      {'type': 'ready'} => const ViewerReady(),
      {'type': 'loaded', 'failed': List<Object?> failed} => ViewerLoaded(
        failed: [for (final part in failed) if (part is String) part],
      ),
      {'type': 'tap', 'part': String part} => ViewerTap(part),
      {'type': 'error', 'message': String message} => ViewerFailure(message),
      _ => null,
    };
  }
}

/// La página cargó y puede recibir escenas.
class ViewerReady extends ViewerEvent {
  const ViewerReady();
}

/// Terminó de dibujar una escena; [failed] son las piezas cuyo modelo no
/// cargó (se muestran generadas).
class ViewerLoaded extends ViewerEvent {
  const ViewerLoaded({required this.failed});

  final List<String> failed;
}

/// Toque sobre la pieza de la oferta [part].
class ViewerTap extends ViewerEvent {
  const ViewerTap(this.part);

  final String part;
}

/// El visor no puede funcionar, por ejemplo sin WebGL.
class ViewerFailure extends ViewerEvent {
  const ViewerFailure(this.message);

  final String message;
}
