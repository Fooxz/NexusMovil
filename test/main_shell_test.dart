import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/screens/shell/main_shell.dart';
import 'package:prueba01/widgets/lazy_indexed_stack.dart';
import 'package:prueba01/widgets/nexus_bottom_nav.dart';
import 'support/main_shell_test_support.dart';

class _BuildCounter extends StatefulWidget {
  const _BuildCounter({required this.index, required this.buildCounts});

  final int index;
  final List<int> buildCounts;

  @override
  State<_BuildCounter> createState() => _BuildCounterState();
}

class _BuildCounterState extends State<_BuildCounter> {
  int value = 0;

  @override
  Widget build(BuildContext context) {
    widget.buildCounts[widget.index] += 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('tab-${widget.index}-count-$value'),
        TextButton(
          onPressed: () => setState(() => value++),
          child: Text('increment-${widget.index}'),
        ),
      ],
    );
  }
}

class _LazyHost extends StatefulWidget {
  const _LazyHost({super.key, required this.buildCounts});

  final List<int> buildCounts;

  @override
  State<_LazyHost> createState() => _LazyHostState();
}

class _LazyHostState extends State<_LazyHost> {
  int currentIndex = 0;

  void changeIndex(int index) {
    setState(() => currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return LazyIndexedStack(
      index: currentIndex,
      children: [
        _BuildCounter(index: 0, buildCounts: widget.buildCounts),
        _BuildCounter(index: 1, buildCounts: widget.buildCounts),
      ],
    );
  }
}

class _TickerProbe extends StatelessWidget {
  const _TickerProbe({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final tickerState = TickerMode.valuesOf(context).enabled
        ? 'enabled'
        : 'disabled';
    return Text('tab-$index-ticker-$tickerState');
  }
}

class _TickerHost extends StatefulWidget {
  const _TickerHost({super.key});

  @override
  State<_TickerHost> createState() => _TickerHostState();
}

class _TickerHostState extends State<_TickerHost> {
  int currentIndex = 0;

  void changeIndex(int index) {
    setState(() => currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return LazyIndexedStack(
      index: currentIndex,
      children: const [_TickerProbe(index: 0), _TickerProbe(index: 1)],
    );
  }
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  String? replacedRouteName;
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount++;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    replacedRouteName = newRoute?.settings.name;
  }
}

Widget _withProviderScope(Widget child) => ProviderScope(
  retry: (retryCount, error) => null,
  child: child,
);

void main() {
  testWidgets('LazyIndexedStack builds only the selected tab initially', (
    WidgetTester tester,
  ) async {
    final buildCounts = [0, 0];
    final hostKey = GlobalKey<_LazyHostState>();

    await tester.pumpWidget(
      MaterialApp(
        home: _LazyHost(key: hostKey, buildCounts: buildCounts),
      ),
    );

    expect(buildCounts, [1, 0]);

    hostKey.currentState!.changeIndex(1);
    await tester.pump();

    expect(buildCounts, [2, 1]);
  });

  testWidgets('LazyIndexedStack preserves state when switching tabs', (
    WidgetTester tester,
  ) async {
    final buildCounts = [0, 0];
    final hostKey = GlobalKey<_LazyHostState>();

    await tester.pumpWidget(
      MaterialApp(
        home: _LazyHost(key: hostKey, buildCounts: buildCounts),
      ),
    );

    await tester.tap(find.text('increment-0'));
    await tester.pump();
    expect(find.text('tab-0-count-1'), findsOneWidget);

    hostKey.currentState!.changeIndex(1);
    await tester.pump();
    hostKey.currentState!.changeIndex(0);
    await tester.pump();

    expect(find.text('tab-0-count-1'), findsOneWidget);
  });

  testWidgets('LazyIndexedStack disables tickers in inactive tabs', (
    WidgetTester tester,
  ) async {
    final hostKey = GlobalKey<_TickerHostState>();

    await tester.pumpWidget(MaterialApp(home: _TickerHost(key: hostKey)));

    expect(find.text('tab-0-ticker-enabled'), findsOneWidget);
    expect(find.text('tab-1-ticker-enabled'), findsNothing);

    hostKey.currentState!.changeIndex(1);
    await tester.pump();

    expect(
      find.text('tab-0-ticker-disabled', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('tab-1-ticker-enabled'), findsOneWidget);
  });

  testWidgets('MainShell changes the visible tab', (WidgetTester tester) async {
    await tester.pumpWidget(
      _withProviderScope(const MaterialApp(home: MainShell())),
    );

    expect(find.text('ARMA TU PC\nCON IA'), findsOneWidget);

    await tester.tap(find.text('CATÁLOGO'));
    await tester.pumpAndSettle();

    expect(find.text('CATÁLOGO COMPLETO'), findsOneWidget);
  });

  testWidgets('Android back from catalog returns home without popping shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(shellWithExternalRoute());
    await tester.tap(find.text('open shell'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CATÁLOGO'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('ARMA TU PC\nCON IA'), findsOneWidget);
    expect(find.text('CATÁLOGO COMPLETO'), findsNothing);
    expect(find.text('open shell'), findsNothing);
  });

  testWidgets('MainShell shows bottom bar when keyboard is hidden', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _withProviderScope(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(viewInsets: EdgeInsets.zero),
            child: MainShell(),
          ),
        ),
      ),
    );

    expect(find.byType(NexusBottomNav), findsOneWidget);
    // Deja terminar la carga del inicio.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('MainShell hides bottom bar when keyboard is visible', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _withProviderScope(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: 240)),
            child: MainShell(),
          ),
        ),
      ),
    );

    expect(find.byType(NexusBottomNav), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('PERFIL is a tab of the shell, not a route replacement', (
    WidgetTester tester,
  ) async {
    final observer = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      _withProviderScope(
        MaterialApp(navigatorObservers: [observer], home: const MainShell()),
      ),
    );

    await tester.tap(find.text('PERFIL'));
    await tester.pumpAndSettle();

    expect(observer.replacedRouteName, isNull);
    expect(find.text('MI CUENTA'), findsOneWidget);
    expect(find.text('INICIAR SESIÓN'), findsOneWidget);
    expect(find.byType(NexusBottomNav), findsOneWidget);
    // Deja terminar la carga del inicio.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('NexusBottomNav emits the correct tab for taps', (
    WidgetTester tester,
  ) async {
    NexusTab? selectedTab;
    final observer = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: NexusBottomNav(
          current: NexusTab.home,
          onTap: (tab) => selectedTab = tab,
        ),
      ),
    );

    await tester.tap(find.text('CATÁLOGO'));
    await tester.pump();

    expect(selectedTab, NexusTab.catalog);
    expect(observer.pushCount, 1);
    expect(observer.replacedRouteName, isNull);
  });

}
