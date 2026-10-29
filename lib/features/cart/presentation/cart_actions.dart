import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../routes.dart';
import '../../../widgets/nexus_cart_badge.dart';
import '../../../widgets/nexus_notice.dart';
import '../../account/account_providers.dart';
import '../cart_providers.dart';

/// Provee el número de unidades del carrito a los íconos de [NexusTopBar].
/// Va en `MaterialApp.builder`, por encima del navegador.
class CartBadgeHost extends ConsumerWidget {
  const CartBadgeHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NexusCartBadge(
      count: ref.watch(cartItemCountProvider),
      enabled: ref.watch(canBuyProvider),
      child: child,
    );
  }
}

/// Mensaje en español para un error del carrito.
String cartErrorMessage(Object error) => error is AppFailure
    ? error.userMessage
    : const UnexpectedFailure().userMessage;

/// Agrega la oferta al carrito y lo informa con un aviso. Devuelve `true` si
/// se agregó. Con [openCart] abre el carrito después ("Comprar ahora").
/// [productName] aparece en el aviso.
Future<bool> addToCart(
  BuildContext context,
  WidgetRef ref, {
  required String offerId,
  int quantity = 1,
  bool openCart = false,
  String? productName,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final navigator = Navigator.of(context);
  try {
    await ref
        .read(cartControllerProvider.notifier)
        .add(offerId, quantity: quantity);
  } catch (error) {
    showNexusNotice(
      messenger,
      title: 'No se pudo agregar al carrito',
      message: cartErrorMessage(error),
      tone: NexusNoticeTone.error,
    );
    return false;
  }

  if (openCart) {
    await navigator.pushNamed(NexusRoutes.cart);
    return true;
  }
  final units = quantity == 1 ? '1 unidad' : '$quantity unidades';
  showNexusNotice(
    messenger,
    title: quantity == 1 ? 'Agregado al carrito' : '$quantity unidades agregadas al carrito',
    message: productName == null ? null : '$productName · $units',
    icon: Icons.shopping_cart_checkout,
    actionLabel: 'VER CARRITO',
    onAction: () => navigator.pushNamed(NexusRoutes.cart),
  );
  return true;
}

/// Una pieza de una configuración para [addPartsToCart].
typedef CartPart = ({String offerId, String name});

/// Agrega una configuración completa, una unidad de cada pieza, y lo informa
/// con un aviso: cuántas piezas entraron y cuáles no. Devuelve cuántas se
/// agregaron.
Future<int> addPartsToCart(BuildContext context, WidgetRef ref, List<CartPart> parts) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final navigator = Navigator.of(context);
  final cart = ref.read(cartControllerProvider.notifier);
  final failures = <String>[];
  for (final part in parts) {
    try {
      await cart.add(part.offerId);
    } catch (error) {
      failures.add('${part.name}: ${cartErrorMessage(error)}');
    }
  }
  final added = parts.length - failures.length;
  showNexusNotice(
    messenger,
    title: failures.isEmpty
        ? 'Agregamos las $added piezas al carrito'
        : added == 0
        ? 'No se pudo agregar la configuración'
        : 'Agregamos $added de ${parts.length} piezas',
    message: failures.isEmpty ? 'Tu configuración está lista para pagar.' : failures.join('\n'),
    tone: failures.isEmpty ? NexusNoticeTone.success : NexusNoticeTone.error,
    icon: failures.isEmpty ? Icons.shopping_cart_checkout : null,
    actionLabel: added > 0 ? 'VER CARRITO' : null,
    onAction: added > 0 ? () => navigator.pushNamed(NexusRoutes.cart) : null,
    duration: Duration(seconds: failures.isEmpty ? 4 : 6),
  );
  return added;
}
