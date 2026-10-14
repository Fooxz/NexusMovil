import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prueba01/screens/shell/main_shell.dart';

Widget shellWithExternalRoute() => ProviderScope(
  retry: (retryCount, error) => null,
  child: MaterialApp(
    routes: {'/shell': (_) => const MainShell()},
    home: Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () => Navigator.of(context).pushNamed('/shell'),
          child: const Text('open shell'),
        ),
      ),
    ),
  ),
);

Widget mainShellScopeProbe(ValueChanged<NexusTab> onSelected) => MaterialApp(
  home: MainShellScope(
    selectTab: onSelected,
    child: Builder(
      builder: (context) => Center(
        child: ElevatedButton(
          onPressed: () =>
              MainShellScope.of(context).selectTab(NexusTab.comparator),
          child: const Text('switch'),
        ),
      ),
    ),
  ),
);
