import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'viewer_host.dart';

/// Web: el visor corre en un iframe del mismo origen y se comunica con
/// `postMessage`.
ViewerHostBuilder? platformViewerHost() =>
    (sceneMessage, onEvent) =>
        _IframeViewer(sceneMessage: sceneMessage, onEvent: onEvent);

class _IframeViewer extends StatefulWidget {
  const _IframeViewer({required this.sceneMessage, required this.onEvent});

  final String sceneMessage;
  final ValueChanged<ViewerEvent> onEvent;

  @override
  State<_IframeViewer> createState() => _IframeViewerState();
}

class _IframeViewerState extends State<_IframeViewer> {
  static int _nextId = 0;

  late final String _viewType = 'nexus-pc-viewer-${_nextId++}';
  late final web.HTMLIFrameElement _iframe;
  late final JSFunction _listener = _onMessage.toJS;
  bool _ready = false;
  String? _sent;

  @override
  void initState() {
    super.initState();
    _iframe = web.HTMLIFrameElement()
      ..src = ui_web.assetManager.getAssetUrl(viewerAsset)
      ..title = 'Vista 3D de la configuración';
    _iframe.style
      ..border = '0'
      ..width = '100%'
      ..height = '100%'
      ..backgroundColor = 'transparent';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int _) => _iframe,
    );
    web.window.addEventListener('message', _listener);
  }

  void _onMessage(web.MessageEvent event) {
    if (!mounted || !event.source.strictEquals(_iframe.contentWindow).toDart) {
      return;
    }
    final data = event.data;
    if (data == null || !data.isA<JSObject>()) return;
    final text = (data as JSObject).getProperty<JSAny?>('nexusViewer'.toJS);
    if (text == null || !text.isA<JSString>()) return;
    final parsed = ViewerEvent.parse((text as JSString).toDart);
    if (parsed == null) return;
    if (parsed is ViewerReady) {
      _ready = true;
      _send();
    }
    widget.onEvent(parsed);
  }

  @override
  void didUpdateWidget(_IframeViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _send();
  }

  void _send() {
    final message = widget.sceneMessage;
    if (!_ready || message == _sent) return;
    _sent = message;
    final payload = JSObject()..setProperty('nexusViewer'.toJS, message.toJS);
    _iframe.contentWindow?.postMessage(payload, '*'.toJS);
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', _listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
