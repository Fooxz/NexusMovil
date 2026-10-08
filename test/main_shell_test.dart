import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/screens/shell/main_shell.dart';
import 'package:prueba01/widgets/lazy_indexed_stack.dart';
import 'package:prueba01/widgets/nexus_bottom_nav.dart';

class _BuildCounter extends StatefulWidget {
  const _BuildCounter({required this.index, required this.buildCounts});

  final int index;
  final List<int> buildCounts;

  @override
  State<_BuildCounter> createState() => _BuildCounterState();
}

class _BuildCounterState extends State<_BuildCounter> {
  @override
  Widget build(BuildContext context) {
    widget.buildCounts[widget.index] += 1;
    return Text('tab-${widget.index}');
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

  testWidgets('MainShell changes the visible tab', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainShell()));

    expect(find.text('TIENDA DE\nTECNOLOGÍA'), findsOneWidget);

    await tester.tap(find.text('CATÁLOGO'));
    await tester.pumpAndSettle();

    expect(find.text('CATÁLOGO COMPLETO'), findsOneWidget);
  });

  testWidgets('NexusBottomNav emits the correct tab for taps', (
    WidgetTester tester,
  ) async {
    NexusTab? selectedTab;

    await tester.pumpWidget(
      MaterialApp(
        home: NexusBottomNav(
          current: NexusTab.home,
          onTap: (tab) => selectedTab = tab,
        ),
      ),
    );

    await tester.tap(find.text('CATÁLOGO'));
    await tester.pump();

    expect(selectedTab, NexusTab.catalog);
  });

  testWidgets('MainShellScope exposes selectTab to descendants', (
    WidgetTester tester,
  ) async {
    NexusTab? selectedTab;

    await tester.pumpWidget(
      MaterialApp(
        home: MainShellScope(
          selectTab: (tab) => selectedTab = tab,
          child: Builder(
            builder: (context) {
              return Center(
                child: ElevatedButton(
                  onPressed: () => MainShellScope.of(context).selectTab(NexusTab.comparator),
                  child: const Text('switch'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('switch'));
    await tester.pump();

    expect(selectedTab, NexusTab.comparator);
  });
}
