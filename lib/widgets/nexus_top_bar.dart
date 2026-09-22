// lib/widgets/nexus_top_bar.dart
//
// Barra superior reutilizada en catálogo, detalle, carrito, comparador y
// PC builder: título grande + botón de volver opcional + ícono de carrito.

import 'package:flutter/material.dart';
import '../routes.dart';
import '../theme/nexus_theme.dart';

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
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
          if (showCart)
            InkWell(
              onTap: () => Navigator.of(context).pushNamed(NexusRoutes.cart),
              child: const Icon(Icons.shopping_cart_outlined, color: NexusColors.text, size: 22),
            ),
        ],
      ),
    );
  }
}
