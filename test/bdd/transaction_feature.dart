import 'package:finance_app/data/datasources/mock_remote_account_datasource.dart';
import 'package:finance_app/data/models/account_model.dart';
import 'package:finance_app/data/repositories/account_repository_impl.dart';
import 'package:finance_app/domain/entities/account.dart';
import 'package:finance_app/domain/entities/transaction.dart';
import 'package:finance_app/domain/usecases/calculate_balance_usecase.dart';
import 'package:finance_app/domain/usecases/process_transaction_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/in_memory_transaction_repository.dart';

/// Feature: Gestión de Transacciones
///
///   Como usuario de la aplicación de finanzas personales
///   Quiero registrar y administrar mis transacciones
///   Para conocer en todo momento el estado real de mi dinero
///
/// Las pruebas ejercitan los casos de uso reales contra repositorios en
/// memoria (sin mocks), de modo que validan el comportamiento de negocio de
/// extremo a extremo.
void main() {
  const accountId = 'acc_main';

  late AccountRepositoryImpl accountRepository;
  late InMemoryTransactionRepository transactionRepository;
  late ProcessTransactionUseCase processTransaction;
  late CalculateBalanceUseCase calculateBalance;

  /// Dado que existe una cuenta con el saldo inicial indicado.
  Future<void> givenAnAccountWithBalance(double initialBalance) async {
    final remote = MockRemoteAccountDataSource(
      initialAccounts: [
        AccountModel.fromEntity(
          Account(
            id: accountId,
            name: 'Cuenta principal',
            userId: 'user_1',
            initialBalance: initialBalance,
            currency: Currency.usd,
            type: AccountType.checking,
            createdAt: DateTime(2024, 1, 1),
          ),
        ),
      ],
      latency: Duration.zero,
    );
    accountRepository = AccountRepositoryImpl(remoteDataSource: remote);
    transactionRepository = InMemoryTransactionRepository();
    processTransaction = ProcessTransactionUseCase(
      transactionRepository: transactionRepository,
      accountRepository: accountRepository,
    );
    calculateBalance = CalculateBalanceUseCase(
      accountRepository: accountRepository,
      transactionRepository: transactionRepository,
    );
  }

  Future<ProcessTransactionResult> whenTheUserRegisters(
    TransactionType type,
    double amount, {
    String description = 'Movimiento',
  }) {
    return processTransaction.execute(
      ProcessTransactionParams(
        accountId: accountId,
        amount: amount,
        description: description,
        category: 'general',
        type: type,
      ),
    );
  }

  Transaction aPendingTransaction({
    String id = 'txn_pending',
    double amount = 100,
    TransactionType type = TransactionType.expense,
  }) =>
      Transaction(
        id: id,
        accountId: accountId,
        amount: amount,
        description: 'Pago pendiente',
        date: DateTime(2024, 2, 1),
        category: 'general',
        type: type,
      );

  group('Feature: Gestión de Transacciones', () {
    test('Scenario: Crear transacción de ingreso exitosa', () async {
      // Dado (Arrange): que existe una cuenta con saldo de 1000
      await givenAnAccountWithBalance(1000);

      // Cuando (Act): el usuario registra un ingreso de 500 por "Salario"
      final result = await whenTheUserRegisters(
        TransactionType.income,
        500,
        description: 'Salario',
      );

      // Entonces (Assert): la transacción se completa exitosamente
      expect(result.success, isTrue);
      expect(result.transaction.status, TransactionStatus.completed);
      expect(result.transaction.description, 'Salario');
      // Y el saldo de la cuenta pasa a 1500
      expect(result.updatedBalance.currentBalance, 1500);
      // Y la transacción queda almacenada
      final stored =
          await transactionRepository.getTransactionById(result.transaction.id);
      expect(stored, result.transaction);
    });

    test('Scenario: Procesar transacción de débito', () async {
      // Dado (Arrange): que existe una cuenta con saldo de 1000
      await givenAnAccountWithBalance(1000);

      // Cuando (Act): el usuario registra un gasto de 300
      final result = await whenTheUserRegisters(TransactionType.expense, 300);

      // Entonces (Assert): la transacción se completa exitosamente
      expect(result.success, isTrue);
      expect(result.transaction.status, TransactionStatus.completed);
      // Y el saldo de la cuenta baja a 700
      expect(result.updatedBalance.currentBalance, 700);
      // Y el balance calculado desde el historial coincide
      final balance = await calculateBalance.execute(accountId);
      expect(balance.currentBalance, 700);
    });

    test('Scenario: Rechazar transacción por fondos insuficientes', () async {
      // Dado (Arrange): que existe una cuenta con saldo de 100
      await givenAnAccountWithBalance(100);

      // Cuando (Act): el usuario intenta registrar un gasto de 500
      final result = await whenTheUserRegisters(TransactionType.expense, 500);

      // Entonces (Assert): la transacción es rechazada con un mensaje de saldo
      // insuficiente
      expect(result.success, isFalse);
      expect(result.transaction.status, TransactionStatus.failed);
      expect(result.errorMessage, contains('Saldo insuficiente'));
      // Y el saldo de la cuenta no cambia
      expect(result.updatedBalance.currentBalance, 100);
      // Y no se almacena ninguna transacción
      expect(transactionRepository.stored, isEmpty);
    });

    test('Scenario: Actualizar estado de transacción', () async {
      // Dado (Arrange): que existe una transacción de gasto de 100 en estado
      // pendiente
      await givenAnAccountWithBalance(1000);
      final pending =
          await transactionRepository.createTransaction(aPendingTransaction());
      final balanceBefore = await calculateBalance.execute(accountId);

      // Cuando (Act): la transacción pasa a estado completada
      await transactionRepository.updateTransaction(
        pending.copyWith(status: TransactionStatus.completed),
      );

      // Entonces (Assert): la transacción consultada aparece como completada
      final updated =
          await transactionRepository.getTransactionById(pending.id);
      expect(updated?.status, TransactionStatus.completed);
      // Y el gasto de 100 se descuenta del saldo
      final balanceAfter = await calculateBalance.execute(accountId);
      expect(balanceBefore.currentBalance, 1000);
      expect(balanceAfter.currentBalance, 900);
      expect(balanceAfter.expenses, 100);
    });

    test('Scenario: Cancelar transacción', () async {
      // Dado (Arrange): que existe una transacción de gasto de 100 en estado
      // pendiente
      await givenAnAccountWithBalance(1000);
      final pending =
          await transactionRepository.createTransaction(aPendingTransaction());

      // Cuando (Act): el usuario cancela la transacción
      await transactionRepository.updateTransaction(
        pending.copyWith(status: TransactionStatus.cancelled),
      );

      // Entonces (Assert): la transacción queda cancelada
      final cancelled =
          await transactionRepository.getTransactionById(pending.id);
      expect(cancelled?.status, TransactionStatus.cancelled);
      // Y ya no figura entre las transacciones pendientes
      expect(
        await transactionRepository.getPendingTransactions(accountId),
        isEmpty,
      );
      // Y el saldo de la cuenta permanece en 1000
      final balance = await calculateBalance.execute(accountId);
      expect(balance.currentBalance, 1000);
      expect(balance.expenses, 0);
    });
  });

  group('Transacciones con comportamiento específico', () {
    test('Scenario: Transacción de crédito aumenta income del balance',
        () async {
      // Dado (Arrange): que existe una cuenta con saldo de 1000 y sin ingresos
      // registrados
      await givenAnAccountWithBalance(1000);

      // Cuando (Act): el usuario registra dos ingresos, de 200 y de 300
      await whenTheUserRegisters(TransactionType.income, 200);
      final result = await whenTheUserRegisters(TransactionType.income, 300);

      // Entonces (Assert): el income del balance acumula 500
      expect(result.updatedBalance.income, 500);
      // Y los expenses del balance siguen en 0
      expect(result.updatedBalance.expenses, 0);
      // Y el income calculado desde el historial coincide
      final balance = await calculateBalance.execute(accountId);
      expect(balance.income, 500);
    });

    test('Scenario: Transacción de débito aumenta expenses del balance',
        () async {
      // Dado (Arrange): que existe una cuenta con saldo de 1000 y sin gastos
      // registrados
      await givenAnAccountWithBalance(1000);

      // Cuando (Act): el usuario registra dos gastos, de 150 y de 250
      await whenTheUserRegisters(TransactionType.expense, 150);
      final result = await whenTheUserRegisters(TransactionType.expense, 250);

      // Entonces (Assert): los expenses del balance acumulan 400
      expect(result.updatedBalance.expenses, 400);
      // Y el income del balance sigue en 0
      expect(result.updatedBalance.income, 0);
      // Y los expenses calculados desde el historial coinciden
      final balance = await calculateBalance.execute(accountId);
      expect(balance.expenses, 400);
    });
  });
}
