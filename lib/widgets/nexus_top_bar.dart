// lib/widgets/nexus_top_bar.dart
//
// Barra superior reutilizada en catálogo, detalle, carrito y
// PC builder: título grande + botón de volver opcional + ícono de carrito.

import 'package:flutter/material.dart';
import '../routes.dart';
import '../theme/nexus_theme.dart';
import 'nexus_cart_badge.dart';
import 'nexus_menu_scope.dart';

class NexusTopBar extends StatelessWidget {
  const NexusTopBar({
    super.key,
    required this.title,
    this.showBack = false,
    this.trailingBadge,
    this.showCart = true,
  });

  final String title;
  final bool showBack;

  /// Texto pequeño opcional junto al título, ej. "NXS.v1.0".
  final String? trailingBadge;
  final bool showCart;

  @override
  Widget build(BuildContext context) {
    // Dentro de un shell con menú lateral (cliente, tienda o administrador).
    final menu = showBack ? null : NexusMenuScope.maybeOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          if (menu != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: IconButton(
                tooltip: 'Abrir menú',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: menu.openMenu,
                icon: const Icon(Icons.menu, color: NexusColors.text, size: 22),
              ),
            ),
          if (showBack)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.arrow_back, color: NexusColors.text, size: 22),
              ),
            ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trailingBadge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      border: Border.all(color: NexusColors.border),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      trailingBadge!,
                      style: const TextStyle(fontSize: 8, color: NexusColors.textDim),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (showCart && NexusCartBadge.enabledOf(context)) const _CartButton(),
        ],
      ),
    );
  }
}

/// Ícono del carrito con el número de unidades (de [NexusCartBadge]).
class _CartButton extends StatelessWidget {
  const _CartButton();

  @override
  Widget build(BuildContext context) {
    final count = NexusCartBadge.countOf(context);
    return Semantics(
      button: true,
      label: count == 0 ? 'Carrito vacío' : 'Carrito con $count unidades',
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(NexusRoutes.cart),
        child: Badge(
          isLabelVisible: count > 0,
          label: Text(count > 99 ? '99+' : '$count'),
          backgroundColor: NexusColors.pink,
          textColor: Colors.white,
          child: const Icon(
            Icons.shopping_cart_outlined,
            color: NexusColors.text,
            size: 22,
          ),
        ),
      ),
    );
  }
}
