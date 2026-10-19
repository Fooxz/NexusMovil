import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../routes.dart';
import '../../../widgets/nexus_cart_badge.dart';
import '../cart_providers.dart';

/// Provee el número de unidades del carrito a los íconos de [NexusTopBar].
/// Va en `MaterialApp.builder`, por encima del navegador.
class CartBadgeHost extends ConsumerWidget {
  const CartBadgeHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NexusCartBadge(count: ref.watch(cartItemCountProvider), child: child);
  }
}

/// Mensaje en español para un error del carrito.
String cartErrorMessage(Object error) => error is AppFailure
    ? error.userMessage
    : const UnexpectedFailure().userMessage;

/// Agrega la oferta al carrito y lo informa con un aviso. Devuelve `true` si
/// se agregó. Con [openCart] abre el carrito después ("Comprar ahora").
Future<bool> addToCart(
  BuildContext context,
  WidgetRef ref, {
  required String offerId,
  int quantity = 1,
  bool openCart = false,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final navigator = Navigator.of(context);
  try {
    await ref
        .read(cartControllerProvider.notifier)
        .add(offerId, quantity: quantity);
  } catch (error) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(cartErrorMessage(error))));
    return false;
  }

  if (openCart) {
    await navigator.pushNamed(NexusRoutes.cart);
    return true;
  }
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          quantity == 1
              ? 'Agregado al carrito.'
              : '$quantity unidades agregadas al carrito.',
        ),
        action: SnackBarAction(
          label: 'VER CARRITO',
          onPressed: () => navigator.pushNamed(NexusRoutes.cart),
        ),
      ),
    );
  return true;
}
