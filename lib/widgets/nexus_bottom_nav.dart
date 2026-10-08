import 'package:flutter/material.dart';

import '../screens/shell/main_shell.dart';
import '../theme/nexus_theme.dart';

class NexusBottomNav extends StatelessWidget {
  const NexusBottomNav({
    super.key,
    required this.current,
    required this.onTap,
  });

  final NexusTab current;
  final ValueChanged<NexusTab> onTap;

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
          currentIndex: current.tabIndex.clamp(0, NexusTab.values.length - 1),
          onTap: (index) {
            final tab = NexusTab.values.firstWhere(
              (candidate) => candidate.tabIndex == index,
              orElse: () => NexusTab.home,
            );
            if (tab == current) return;
            onTap(tab);
          },
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
