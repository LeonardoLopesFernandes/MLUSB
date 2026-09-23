import 'package:flutter_test/flutter_test.dart';

import 'package:mlusb_flutter/main.dart';

void main() {
  testWidgets('App inicia com as 3 abas', (WidgetTester tester) async {
    await tester.pumpWidget(const MLUSBAapp());

    expect(find.text('Arquivos'), findsOneWidget);
    expect(find.text('Disco'), findsOneWidget);
    expect(find.text('Backup'), findsWidgets);
  });
}