import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/utils/format_price.dart';
import '../../../theme/nexus_theme.dart';
import '../data/mock_checkout_repository.dart';
import '../domain/checkout_models.dart';

/// Abre el pago de un intento y espera a que el cliente termine. Devuelve el
/// id de la transacción que Wompi informa al volver, o `null` si no lo hay
/// (el cliente cerró, o el pago se hizo fuera de la app).
abstract class PaymentLauncher {
  Future<String?> open(BuildContext context, CheckoutSession session);
}

/// Web Checkout de Wompi. En Android e iOS va dentro de la app, en un
/// WebView que intercepta la página de regreso; en web y escritorio se abre
/// en el navegador.
class WompiPaymentLauncher implements PaymentLauncher {
  const WompiPaymentLauncher();

  static bool get _inAppWebView =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<String?> open(BuildContext context, CheckoutSession session) async {
    if (_inAppWebView) {
      return Navigator.of(context).push<String?>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => PaymentWebViewScreen(session: session),
        ),
      );
    }
    await launchUrl(session.checkoutUrl, webOnlyWindowName: '_blank');
    if (!context.mounted) return null;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Completa el pago en Wompi'),
        content: const Text(
          'Abrimos el pago en otra ventana. Cuando termines, vuelve aquí '
          'para ver el resultado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ya terminé'),
          ),
        ],
      ),
    );
    return null;
  }
}

/// Pasarela simulada para la app sin backend (repositorios mock).
class SimulatedPaymentLauncher implements PaymentLauncher {
  const SimulatedPaymentLauncher();

  @override
  Future<String?> open(BuildContext context, CheckoutSession session) {
    return showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pago simulado'),
        content: Text(
          'Sin backend no hay pasarela. Elige el resultado del pago de '
          '${formatPrice(session.amountCents)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar sin pagar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(MockCheckoutRepository.declinedTransaction),
            child: const Text('Rechazar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(MockCheckoutRepository.approvedTransaction),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );
  }
}

/// Wompi dentro de la app. Al llegar a la página de regreso cierra con el id
/// de la transacción; los enlaces a otras apps (banco, Nequi) se abren fuera.
class PaymentWebViewScreen extends StatefulWidget {
  const PaymentWebViewScreen({super.key, required this.session});

  final CheckoutSession session;

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  var _loading = true;
  var _closed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(NexusColors.bg)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigation,
          // Algunas redirecciones no pasan por onNavigationRequest (iOS).
          onPageStarted: (url) => _closeIfReturn(Uri.tryParse(url)),
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(widget.session.checkoutUrl);
  }

  NavigationDecision _onNavigation(NavigationRequest request) {
    final url = Uri.tryParse(request.url);
    if (url == null) return NavigationDecision.prevent;
    if (_closeIfReturn(url)) return NavigationDecision.prevent;
    if (url.scheme != 'https' && url.scheme != 'http') {
      launchUrl(url, mode: LaunchMode.externalApplication);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  bool _closeIfReturn(Uri? url) {
    if (url == null || !widget.session.isReturnUrl(url)) return false;
    _close(url.queryParameters['id']);
    return true;
  }

  void _close(String? transactionId) {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop(transactionId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexusColors.bg,
      appBar: AppBar(
        backgroundColor: NexusColors.bg,
        title: const Text('Pago seguro con Wompi', style: TextStyle(fontSize: 15)),
        leading: IconButton(
          tooltip: 'Cerrar el pago',
          icon: const Icon(Icons.close),
          onPressed: () => _close(null),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(color: NexusColors.cyan),
        ],
      ),
    );
  }
}
