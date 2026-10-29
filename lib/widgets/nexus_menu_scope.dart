import 'package:flutter/widgets.dart';

/// Abre el menú lateral del shell que lo provee (cliente, tienda o consola).
/// `NexusTopBar` muestra el botón del menú cuando lo encuentra, así las
/// pantallas no dependen de qué shell las contiene.
class NexusMenuScope extends InheritedWidget {
  const NexusMenuScope({super.key, required this.openMenu, required super.child});

  final VoidCallback openMenu;

  static NexusMenuScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NexusMenuScope>();

  @override
  bool updateShouldNotify(NexusMenuScope oldWidget) => openMenu != oldWidget.openMenu;
}
