import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'viewer_host.dart';

/// Android e iOS: el visor corre en un WebView con la página de los assets.
/// En escritorio no hay WebView (webview_flutter no lo soporta).
ViewerHostBuilder? platformViewerHost() => Platform.isAndroid || Platform.isIOS
    ? (sceneMessage, onEvent) =>
          _WebViewViewer(sceneMessage: sceneMessage, onEvent: onEvent)
    : null;

class _WebViewViewer extends StatefulWidget {
  const _WebViewViewer({required this.sceneMessage, required this.onEvent});

  final String sceneMessage;
  final ValueChanged<ViewerEvent> onEvent;

  @override
  State<_WebViewViewer> createState() => _WebViewViewerState();
}

class _WebViewViewerState extends State<_WebViewViewer> {
  late final WebViewController _controller;
  bool _ready = false;
  String? _sent;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'NexusViewerChannel',
        onMessageReceived: (message) => _receive(message.message),
      )
      ..loadFlutterAsset(viewerAsset);
  }

  void _receive(String text) {
    final event = ViewerEvent.parse(text);
    if (event == null || !mounted) return;
    if (event is ViewerReady) {
      _ready = true;
      _send();
    }
    widget.onEvent(event);
  }

  @override
  void didUpdateWidget(_WebViewViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _send();
  }

  void _send() {
    final message = widget.sceneMessage;
    if (!_ready || message == _sent) return;
    _sent = message;
    _controller.runJavaScript(
      'window.nexusViewer.receive(${jsonEncode(message)})',
    );
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(
      controller: _controller,
      // Arrastrar sobre el visor gira el modelo en vez de desplazar la página.
      gestureRecognizers: {
        Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
      },
    );
  }
}
