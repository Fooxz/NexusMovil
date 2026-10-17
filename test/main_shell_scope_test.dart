import 'package:flutter_test/flutter_test.dart';
import 'package:prueba01/screens/shell/main_shell.dart';

import 'support/main_shell_test_support.dart';

void main() {
  testWidgets('MainShellScope exposes selectTab to descendants', (
    WidgetTester tester,
  ) async {
    NexusTab? selectedTab;
    await tester.pumpWidget(mainShellScopeProbe((tab) => selectedTab = tab));
    await tester.tap(find.text('switch'));
    await tester.pump();

    expect(selectedTab, NexusTab.catalog);
  });
}
