// Mensajes entre el visor y Flutter.
// - Android/iOS (webview_flutter): canal JavaScript `NexusViewerChannel` hacia
//   Flutter; Flutter llama a `window.nexusViewer.receive(texto)`.
// - Web (iframe): `postMessage` en ambos sentidos con la clave `nexusViewer`.
// Los mensajes viajan como texto JSON.

export function send(message) {
  const text = JSON.stringify(message);
  const channel = window.NexusViewerChannel;
  if (channel && typeof channel.postMessage === 'function') {
    channel.postMessage(text);
  } else if (window.parent && window.parent !== window) {
    window.parent.postMessage({ nexusViewer: text }, '*');
  }
}

export function onMessage(handler) {
  const receive = (text) => {
    try {
      handler(typeof text === 'string' ? JSON.parse(text) : text);
    } catch (error) {
      send({ type: 'error', message: String(error) });
    }
  };
  window.nexusViewer = { receive };
  window.addEventListener('message', (event) => {
    if (event.source !== window.parent) return;
    const text = event.data && event.data.nexusViewer;
    if (typeof text === 'string') receive(text);
  });
}
