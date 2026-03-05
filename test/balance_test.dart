import 'package:flutter_test/flutter_test.dart';

// Función sencilla para simular tu lógica de FinanzApp
double calcularBalance(double ingresos, double gastos) {
  return ingresos - gastos;
}

void main() {
  // El grupo organiza varias pruebas
  group('Pruebas de Cálculo en FinanzApp', () {
    
    test('El balance debe ser positivo si ingresos > gastos', () {
      final resultado = calcularBalance(100.0, 40.0);
      expect(resultado, 60.0); // Verificamos que sea 60
    });

    test('El balance debe ser negativo si hay más gastos', () {
      final resultado = calcularBalance(50.0, 80.0);
      expect(resultado, -30.0);
    });
  });
}