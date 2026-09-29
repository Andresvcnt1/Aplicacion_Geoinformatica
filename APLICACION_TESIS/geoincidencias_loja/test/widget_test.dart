// Test básico de arranque para GeoIncidencias Loja.
//
// Verifica que la app inicia sin errores y muestra la pantalla de Splash.

import 'package:flutter_test/flutter_test.dart';
import 'package:geoincidencias_loja/main.dart';

void main() {
  testWidgets('La app arranca y muestra el Splash sin errores', (
    WidgetTester tester,
  ) async {
    // Construye la app y dispara un frame.
    await tester.pumpWidget(const MyApp());

    // Verifica que no hubo errores de renderizado.
    expect(tester.takeException(), isNull);

    // El Splash debería mostrar el nombre de la app.
    expect(find.text('GeoIncidencias Loja'), findsOneWidget);
  });
}
