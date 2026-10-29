import 'package:finance_app/domain/entities/account.dart';
import 'package:finance_app/domain/entities/balance.dart';
import 'package:finance_app/domain/entities/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Balance buildBalance({
    double currentBalance = 1000,
    double income = 0,
    double expenses = 0,
  }) =>
      Balance(
        id: 'balance_1',
        accountId: 'acc_1',
        currentBalance: currentBalance,
        date: DateTime(2024, 1, 1),
        income: income,
        expenses: expenses,
        currency: Currency.usd,
      );

  group('Balance Entity Tests', () {
    test('applyTransaction debe incrementar balance cuando es crédito', () {
      // Dado (Arrange): un balance de 1000
      final balance = buildBalance(currentBalance: 1000);

      // Cuando (Act): se aplica un ingreso (crédito) de 250
      final result = balance.applyTransaction(250, TransactionType.income);

      // Entonces (Assert): el balance sube a 1250
      expect(result.currentBalance, 1250);
    });

    test('applyTransaction debe decrementar balance cuando es débito', () {
      // Dado (Arrange): un balance de 1000
      final balance = buildBalance(currentBalance: 1000);

      // Cuando (Act): se aplica un gasto (débito) de 250
      final result = balance.applyTransaction(250, TransactionType.expense);

      // Entonces (Assert): el balance baja a 750
      expect(result.currentBalance, 750);
    });

    test('canAfford debe retornar true cuando hay fondos suficientes', () {
      // Dado (Arrange): un balance de 1000
      final balance = buildBalance(currentBalance: 1000);

      // Cuando (Act): se consulta si alcanza para 500 y para el monto exacto
      final canAffordLess = balance.canAfford(500);
      final canAffordExact = balance.canAfford(1000);

      // Entonces (Assert): en ambos casos hay fondos suficientes
      expect(canAffordLess, isTrue);
      expect(canAffordExact, isTrue);
    });

    test('canAfford debe retornar false cuando fondos son insuficientes', () {
      // Dado (Arrange): un balance de 100
      final balance = buildBalance(currentBalance: 100);

      // Cuando (Act): se consulta si alcanza para 100.01
      final canAfford = balance.canAfford(100.01);

      // Entonces (Assert): los fondos son insuficientes
      expect(canAfford, isFalse);
    });

    test('copyWith debe crear nueva instancia con valores actualizados', () {
      // Dado (Arrange): un balance original
      final original = buildBalance(currentBalance: 1000, income: 300);

      // Cuando (Act): se copia modificando el saldo actual
      final copy = original.copyWith(currentBalance: 500);

      // Entonces (Assert): se obtiene otra instancia con el cambio aplicado, el
      // resto de los campos igual y el original sin modificar
      expect(identical(copy, original), isFalse);
      expect(copy.currentBalance, 500);
      expect(copy.income, original.income);
      expect(copy.accountId, original.accountId);
      expect(copy.currency, original.currency);
      expect(original.currentBalance, 1000);
    });

    test('applyTransaction debe acumular income correctamente', () {
      // Dado (Arrange): un balance sin ingresos previos
      final balance = buildBalance(income: 0);

      // Cuando (Act): se aplican dos ingresos consecutivos
      final result = balance
          .applyTransaction(100, TransactionType.income)
          .applyTransaction(50, TransactionType.income);

      // Entonces (Assert): los ingresos se acumulan y los gastos no cambian
      expect(result.income, 150);
      expect(result.expenses, 0);
    });

    test('applyTransaction debe acumular expenses correctamente', () {
      // Dado (Arrange): un balance sin gastos previos
      final balance = buildBalance(expenses: 0);

      // Cuando (Act): se aplican dos gastos consecutivos
      final result = balance
          .applyTransaction(100, TransactionType.expense)
          .applyTransaction(50, TransactionType.expense);

      // Entonces (Assert): los gastos se acumulan y los ingresos no cambian
      expect(result.expenses, 150);
      expect(result.income, 0);
    });
  });

  group('Balance Calculation Scenarios', () {
    test('múltiples transacciones de crédito incrementan balance', () {
      // Dado (Arrange): un balance de 1000 y tres ingresos
      final balance = buildBalance(currentBalance: 1000);
      const credits = [100.0, 200.0, 300.0];

      // Cuando (Act): se aplican todos los ingresos
      final result = credits.fold<Balance>(
        balance,
        (acc, amount) => acc.applyTransaction(amount, TransactionType.income),
      );

      // Entonces (Assert): el balance sube 600 y los ingresos suman 600
      expect(result.currentBalance, 1600);
      expect(result.income, 600);
    });

    test('múltiples transacciones de débito decrementan balance', () {
      // Dado (Arrange): un balance de 1000 y tres gastos
      final balance = buildBalance(currentBalance: 1000);
      const debits = [100.0, 200.0, 300.0];

      // Cuando (Act): se aplican todos los gastos
      final result = debits.fold<Balance>(
        balance,
        (acc, amount) => acc.applyTransaction(amount, TransactionType.expense),
      );

      // Entonces (Assert): el balance baja 600 y los gastos suman 600
      expect(result.currentBalance, 400);
      expect(result.expenses, 600);
    });

    test('operación mixta calcula balance neto correctamente', () {
      // Dado (Arrange): un balance de 1000 y una secuencia de ingresos y gastos
      final balance = buildBalance(currentBalance: 1000);

      // Cuando (Act): se aplican, en orden, un ingreso de 500, un gasto de 200,
      // un ingreso de 50 y un gasto de 100
      final result = balance
          .applyTransaction(500, TransactionType.income)
          .applyTransaction(200, TransactionType.expense)
          .applyTransaction(50, TransactionType.income)
          .applyTransaction(100, TransactionType.expense);

      // Entonces (Assert): el balance neto es 1250 (1000 + 550 - 300), con
      // ingresos de 550 y gastos de 300
      expect(result.currentBalance, 1250);
      expect(result.income, 550);
      expect(result.expenses, 300);
    });

    test('transacción con amount cero no modifica balance', () {
      // Dado (Arrange): un balance de 1000 con acumulados previos
      final balance =
          buildBalance(currentBalance: 1000, income: 400, expenses: 200);

      // Cuando (Act): se aplican un ingreso y un gasto de monto cero
      final result = balance
          .applyTransaction(0, TransactionType.income)
          .applyTransaction(0, TransactionType.expense);

      // Entonces (Assert): saldo y acumulados permanecen iguales
      expect(result.currentBalance, 1000);
      expect(result.income, 400);
      expect(result.expenses, 200);
    });

    test('transacción negativa debería ser rechazada', () {
      // Dado (Arrange): una transacción con monto negativo
      final transaction = Transaction(
        id: 'txn_neg',
        accountId: 'acc_1',
        amount: -100,
        description: 'Monto inválido',
        date: DateTime(2024, 1, 1),
        category: 'general',
        type: TransactionType.income,
      );

      // Cuando (Act): se valida el monto antes de aplicarlo al balance
      final isValid = transaction.isValidAmount();

      // Entonces (Assert): la validación del dominio la rechaza
      expect(isValid, isFalse);
    });
  });

  group('Edge Cases', () {
    test('balance con decimales se calcula correctamente', () {
      // Dado (Arrange): un balance de 100.10, con decimales
      final balance = buildBalance(currentBalance: 100.10);

      // Cuando (Act): se aplican un ingreso de 50.25 y un gasto de 20.15
      final result = balance
          .applyTransaction(50.25, TransactionType.income)
          .applyTransaction(20.15, TransactionType.expense);

      // Entonces (Assert): el balance es 130.20, tolerando el error de punto
      // flotante
      expect(result.currentBalance, closeTo(130.20, 1e-9));
    });

    test('balance puede ser negativo', () {
      // Dado (Arrange): un balance de 100
      final balance = buildBalance(currentBalance: 100);

      // Cuando (Act): se aplica un gasto de 250 (sin validar fondos)
      final result = balance.applyTransaction(250, TransactionType.expense);

      // Entonces (Assert): el balance queda en -150
      expect(result.currentBalance, -150);
    });

    test('valores máximos no causan overflow', () {
      // Dado (Arrange): un balance muy grande
      final balance = buildBalance(currentBalance: 1e15);

      // Cuando (Act): se aplica un ingreso igualmente grande
      final result = balance.applyTransaction(1e15, TransactionType.income);

      // Entonces (Assert): el resultado es exacto y finito
      expect(result.currentBalance, 2e15);
      expect(result.currentBalance.isFinite, isTrue);
    });
  });
}
