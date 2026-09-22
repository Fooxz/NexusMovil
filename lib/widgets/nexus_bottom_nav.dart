// lib/widgets/nexus_bottom_nav.dart
//
// Barra de navegación inferior compartida por (casi) todas las pantallas.
// Es puramente visual/navegación: cambia de pantalla con pushReplacementNamed
// para que el usuario pueda moverse entre las pestañas principales sin
// acumular un historial infinito. "PERFIL" lleva a Login mientras no exista
// una pantalla de perfil real (el cliente aún no está autenticado).

import 'package:flutter/material.dart';
import '../routes.dart';
import '../theme/nexus_theme.dart';

class NexusBottomNav extends StatelessWidget {
  const NexusBottomNav({super.key, required this.currentIndex});

  /// 0 = Inicio, 1 = Catálogo, 2 = PC Builder, 3 = Comparador, 4 = Perfil.
  final int currentIndex;

  static const _routesByIndex = [
    NexusRoutes.home,
    NexusRoutes.catalog,
    NexusRoutes.pcBuilder,
    NexusRoutes.comparator,
    NexusRoutes.login,
  ];

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;
    Navigator.of(context).pushReplacementNamed(_routesByIndex[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: NexusColors.bgAlt,
        border: Border(top: BorderSide(color: NexusColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: currentIndex.clamp(0, 4),
          onTap: (i) => _onTap(context, i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: NexusColors.bgAlt,
          selectedItemColor: NexusColors.cyan,
          unselectedItemColor: NexusColors.textFaint,
          selectedFontSize: 8,
          unselectedFontSize: 8,
          elevation: 0,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined, size: 18),
              activeIcon: Icon(Icons.home, size: 18),
              label: 'INICIO',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined, size: 18),
              label: 'CATÁLOGO',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.dvr_outlined, size: 18),
              label: 'PC BUILDER',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined, size: 18),
              label: 'COMPARADOR',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline, size: 18),
              label: 'PERFIL',
            ),
          ],
        ),
      ),
    );
  }
}
