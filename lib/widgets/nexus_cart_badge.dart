import 'package:flutter/widgets.dart';

/// Unidades en el carrito para el ícono de [NexusTopBar]. Lo provee el
/// feature del carrito en la raíz de la app (`CartBadgeHost`); así los widgets
/// compartidos no dependen de `features/`. Sin él, el contador es 0.
class NexusCartBadge extends InheritedWidget {
  const NexusCartBadge({super.key, required this.count, required super.child});

  final int count;

  static int countOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NexusCartBadge>()?.count ?? 0;

  @override
  bool updateShouldNotify(NexusCartBadge oldWidget) => count != oldWidget.count;
}
