import 'package:finance_app/domain/entities/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixedDate = DateTime(2024, 3, 10, 12, 30);

  Transaction buildTransaction({
    String id = 'txn_1',
    double amount = 150.50,
    TransactionType type = TransactionType.income,
    TransactionStatus status = TransactionStatus.pending,
  }) =>
      Transaction(
        id: id,
        accountId: 'acc_1',
        amount: amount,
        description: 'Pago de prueba',
        date: fixedDate,
        category: 'general',
        type: type,
        status: status,
      );

  group('Transaction', () {
    test('Crea transacción válida con todos los campos', () {
      // Dado (Arrange): los valores de todos los campos de una transacción
      const id = 'txn_1';
      const accountId = 'acc_1';
      const amount = 150.50;

      // Cuando (Act): se construye la transacción
      final transaction = Transaction(
        id: id,
        accountId: accountId,
        amount: amount,
        description: 'Compra supermercado',
        date: fixedDate,
        category: 'comida',
        type: TransactionType.expense,
        status: TransactionStatus.completed,
      );

      // Entonces (Assert): cada campo conserva el valor recibido
      expect(transaction.id, id);
      expect(transaction.accountId, accountId);
      expect(transaction.amount, amount);
      expect(transaction.description, 'Compra supermercado');
      expect(transaction.date, fixedDate);
      expect(transaction.category, 'comida');
      expect(transaction.type, TransactionType.expense);
      expect(transaction.status, TransactionStatus.completed);
    });

    test('copyWith crea copia con campos modificados', () {
      // Dado (Arrange): una transacción original pendiente de 150.50
      final original = buildTransaction();

      // Cuando (Act): se copia cambiando monto y estado
      final copy = original.copyWith(
        amount: 300,
        status: TransactionStatus.completed,
      );

      // Entonces (Assert): la copia tiene los cambios, conserva el resto de los
      // campos y el original no se modifica
      expect(copy.amount, 300);
      expect(copy.status, TransactionStatus.completed);
      expect(copy.id, original.id);
      expect(copy.accountId, original.accountId);
      expect(copy.description, original.description);
      expect(copy.date, original.date);
      expect(copy.category, original.category);
      expect(copy.type, original.type);
      expect(original.amount, 150.50);
      expect(original.status, TransactionStatus.pending);
    });

    test('isValidAmount retorna true para monto positivo', () {
      // Dado (Arrange): una transacción con monto positivo
      final transaction = buildTransaction(amount: 0.01);

      // Cuando (Act): se valida el monto
      final isValid = transaction.isValidAmount();

      // Entonces (Assert): el monto es válido
      expect(isValid, isTrue);
    });

    test('isValidAmount retorna false para monto cero', () {
      // Dado (Arrange): una transacción con monto cero
      final transaction = buildTransaction(amount: 0);

      // Cuando (Act): se valida el monto
      final isValid = transaction.isValidAmount();

      // Entonces (Assert): el monto no es válido
      expect(isValid, isFalse);
    });

    test('isValidAmount retorna false para monto negativo', () {
      // Dado (Arrange): una transacción con monto negativo
      final transaction = buildTransaction(amount: -50);

      // Cuando (Act): se valida el monto
      final isValid = transaction.isValidAmount();

      // Entonces (Assert): el monto no es válido
      expect(isValid, isFalse);
    });

    test('calculateBalanceImpact retorna monto positivo para crédito', () {
      // Dado (Arrange): una transacción de ingreso (crédito) de 200
      final transaction = buildTransaction(
        amount: 200,
        type: TransactionType.income,
      );

      // Cuando (Act): se calcula el impacto en el saldo
      final impact = transaction.calculateBalanceImpact();

      // Entonces (Assert): el impacto es positivo e igual al monto
      expect(impact, 200);
    });

    test('calculateBalanceImpact retorna monto negativo para débito', () {
      // Dado (Arrange): una transacción de gasto (débito) de 200
      final transaction = buildTransaction(
        amount: 200,
        type: TransactionType.expense,
      );

      // Cuando (Act): se calcula el impacto en el saldo
      final impact = transaction.calculateBalanceImpact();

      // Entonces (Assert): el impacto es negativo
      expect(impact, -200);
    });

    test('Dos transacciones con mismo contenido son iguales', () {
      // Dado (Arrange): dos instancias distintas con el mismo contenido
      final first = buildTransaction();
      final second = buildTransaction();

      // Cuando (Act): se comparan
      final areEqual = first == second;

      // Entonces (Assert): ambas son iguales y tienen el mismo hashCode, mientras
      // que una con distinto id es diferente
      expect(areEqual, isTrue);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(equals(buildTransaction(id: 'txn_2'))));
    });
  });

  group('TransactionType', () {
    test('TransactionType tiene valores correctos', () {
      // Dado (Arrange): los tipos de transacción esperados por el dominio
      const expected = [
        TransactionType.income,
        TransactionType.expense,
        TransactionType.credit,
        TransactionType.debit,
        TransactionType.transfer,
      ];

      // Cuando (Act): se obtienen los valores del enum
      final values = TransactionType.values;

      // Entonces (Assert): coinciden en contenido y orden
      expect(values, expected);
      expect(values.map((v) => v.name),
          ['income', 'expense', 'credit', 'debit', 'transfer']);
    });
  });

  group('TransactionStatus', () {
    test('TransactionStatus tiene valores correctos', () {
      // Dado (Arrange): los estados de transacción esperados por el dominio
      const expected = [
        TransactionStatus.pending,
        TransactionStatus.completed,
        TransactionStatus.failed,
        TransactionStatus.reversed,
        TransactionStatus.cancelled,
      ];

      // Cuando (Act): se obtienen los valores del enum
      final values = TransactionStatus.values;

      // Entonces (Assert): coinciden en contenido y orden
      expect(values, expected);
      expect(values.map((v) => v.name),
          ['pending', 'completed', 'failed', 'reversed', 'cancelled']);
    });
  });
}
