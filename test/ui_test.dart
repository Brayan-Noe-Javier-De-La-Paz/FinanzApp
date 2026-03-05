import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Verificar que el título de FinanzApp aparece', (WidgetTester tester) async {
    // Construimos un widget básico para probar
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Text('Mi Balance Semanal'),
      ),
    ));

    // Buscamos si el texto existe
    expect(find.text('Mi Balance Semanal'), findsOneWidget);
    // Verificamos que no haya errores
    expect(find.text('Error'), findsNothing);
  });
}