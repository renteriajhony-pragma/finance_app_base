// Índice de ejecución de todas las pruebas del proyecto.
//
// Agrupa en un solo punto de entrada las pruebas unitarias, los escenarios BDD
// y las pruebas de integración:
//
//   flutter test test/widget_test.dart
//
// Los archivos de BDD terminan en `_feature.dart`, por lo que `flutter test`
// no los detecta por sí solo; este índice es la forma de ejecutarlos todos
// juntos. Cada archivo se puede seguir ejecutando de manera individual, por
// ejemplo: `flutter test test/unit/balance_calculation_test.dart`.

import 'package:flutter_test/flutter_test.dart';

import 'bdd/account_feature.dart' as account_feature;
import 'bdd/transaction_feature.dart' as transaction_feature;
import 'integration/finance_flow_test.dart' as finance_flow;
import 'unit/balance_calculation_test.dart' as balance_calculation;
import 'unit/calculate_balance_usecase_test.dart' as calculate_balance_usecase;
import 'unit/process_transaction_usecase_test.dart'
    as process_transaction_usecase;
import 'unit/transaction_model_test.dart' as transaction_model;

void main() {
  group('Pruebas unitarias', () {
    group('Balance', balance_calculation.main);
    group('Transaction (modelo)', transaction_model.main);
    group('CalculateBalanceUseCase', calculate_balance_usecase.main);
    group('ProcessTransactionUseCase', process_transaction_usecase.main);
  });

  group('Pruebas BDD', () {
    group('Cuentas', account_feature.main);
    group('Transacciones', transaction_feature.main);
  });

  group('Pruebas de integración', () {
    group('Flujo financiero', finance_flow.main);
  });
}
