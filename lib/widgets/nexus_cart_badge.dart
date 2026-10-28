import 'package:flutter/widgets.dart';

/// Unidades en el carrito para el ícono de [NexusTopBar]. Lo provee el
/// feature del carrito en la raíz de la app (`CartBadgeHost`); así los widgets
/// compartidos no dependen de `features/`. Sin él, el contador es 0.
///
/// [enabled] es falso para las cuentas que no compran (tiendas y
/// administradores): el ícono del carrito no se muestra.
class NexusCartBadge extends InheritedWidget {
  const NexusCartBadge({
    super.key,
    required this.count,
    this.enabled = true,
    required super.child,
  });

  final int count;
  final bool enabled;

  static int countOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NexusCartBadge>()?.count ?? 0;

  static bool enabledOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NexusCartBadge>()?.enabled ?? true;

  @override
  bool updateShouldNotify(NexusCartBadge oldWidget) =>
      count != oldWidget.count || enabled != oldWidget.enabled;
}
