import 'package:flutter/material.dart';

import '../../routes.dart';
import '../catalog/catalog_screen.dart';
import '../comparator/comparator_screen.dart';
import '../home/home_screen.dart';
import '../pc_builder/pc_builder_screen.dart';
import '../../widgets/lazy_indexed_stack.dart';
import '../../widgets/nexus_bottom_nav.dart';

enum NexusTab {
  home(0),
  catalog(1),
  pcBuilder(2),
  comparator(3),
  profile(4);

  const NexusTab(this.tabIndex);

  final int tabIndex;
}

class MainShellScope extends InheritedWidget {
  const MainShellScope({
    super.key,
    required this.selectTab,
    required super.child,
  });

  final void Function(NexusTab) selectTab;

  static MainShellScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MainShellScope>();
    assert(scope != null, 'MainShellScope not found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(covariant MainShellScope oldWidget) => false;
}

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late NexusTab _currentTab;

  static const List<Widget> _tabScreens = [
    HomeScreen(),
    CatalogScreen(),
    PcBuilderScreen(),
    ComparatorScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentTab = NexusTab.values.firstWhere(
      (tab) => tab.tabIndex == widget.initialIndex,
      orElse: () => NexusTab.home,
    );
  }

  void _selectTab(NexusTab tab) {
    if (tab == NexusTab.profile) {
      Navigator.of(context).pushReplacementNamed(NexusRoutes.login);
      return;
    }

    if (tab == _currentTab) return;
    setState(() => _currentTab = tab);
  }

  @override
  Widget build(BuildContext context) {
    return MainShellScope(
      selectTab: _selectTab,
      child: PopScope(
        canPop: _currentTab == NexusTab.home,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _currentTab != NexusTab.home) {
            setState(() => _currentTab = NexusTab.home);
          }
        },
        child: Scaffold(
          body: LazyIndexedStack(
            index: _currentTab.tabIndex,
            children: _tabScreens,
          ),
          bottomNavigationBar: _ShellBottomBar(
            current: _currentTab,
            onTap: _selectTab,
          ),
        ),
      ),
    );
  }
}

class _ShellBottomBar extends StatelessWidget {
  const _ShellBottomBar({required this.current, required this.onTap});

  final NexusTab current;
  final ValueChanged<NexusTab> onTap;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    if (keyboardInset > 0) {
      return const SizedBox.shrink();
    }

    return NexusBottomNav(current: current, onTap: onTap);
  }
}
