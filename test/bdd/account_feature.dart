import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Feature: Gestión de Cuentas', () {
    test(
      'Scenario: Crear cuenta con balance inicial válido',
      () {},
      skip: 'Fase 2: ejercicio pendiente',
    );

    test(
      'Scenario: Crear cuenta con balance inicial negativo es rechazado',
      () {},
      skip: 'Fase 2: ejercicio pendiente',
    );

    test(
      'Scenario: Actualizar información de cuenta',
      () {},
      skip: 'Fase 2: ejercicio pendiente',
    );

    test(
      'Scenario: Cambiar tipo de cuenta',
      () {},
      skip: 'Fase 2: ejercicio pendiente',
    );

    test(
      'Scenario: Verificar balance disponible para transacción',
      () {},
      skip: 'Fase 2: ejercicio pendiente',
    );

    test(
      'Scenario: Verificar fondos insuficientes',
      () {},
      skip: 'Fase 2: ejercicio pendiente',
    );
  });

  group('Cuentas con múltiples monedas', () {
    test(
      'Scenario: Cuenta en dólares tiene moneda correcta',
      () {},
      skip: 'Fase 2: ejercicio pendiente',
    );

    test(
      'Scenario: Cuenta en euros tiene moneda correcta',
      () {},
      skip: 'Fase 2: ejercicio pendiente',
    );

    test(
      'Scenario: Balance refleja la moneda de la cuenta',
      () {},
      skip: 'Fase 2: ejercicio pendiente',
    );
  });

  group('Copia inmutable de cuentas', () {
    test(
      'Scenario: copyWith preserva valores no modificados',
      () {},
      skip: 'Fase 2: ejercicio pendiente',
    );
  });
}
