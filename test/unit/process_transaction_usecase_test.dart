import 'dart:io';

import 'package:finance_app/domain/entities/account.dart';
import 'package:finance_app/domain/entities/transaction.dart';
import 'package:finance_app/domain/repositories/account_repository.dart';
import 'package:finance_app/domain/repositories/transaction_repository.dart';
import 'package:finance_app/domain/usecases/process_transaction_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'process_transaction_usecase_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<TransactionRepository>(),
  MockSpec<AccountRepository>(),
])
void main() {
  const accountId = 'acc_1';

  late ProcessTransactionUseCase useCase;
  late MockTransactionRepository mockTransactionRepository;
  late MockAccountRepository mockAccountRepository;

  Account buildAccount({double initialBalance = 1000}) => Account(
        id: accountId,
        name: 'Cuenta corriente',
        userId: 'user_1',
        initialBalance: initialBalance,
        currency: Currency.usd,
        type: AccountType.checking,
        createdAt: DateTime(2024, 1, 1),
      );

  ProcessTransactionParams buildParams({
    required double amount,
    required TransactionType type,
  }) =>
      ProcessTransactionParams(
        accountId: accountId,
        amount: amount,
        description: 'Movimiento de prueba',
        category: 'general',
        type: type,
      );

  /// Configura una cuenta existente sin balance previo registrado, de modo
  /// que el caso de uso parte del saldo inicial de la cuenta.
  void givenAccountWithInitialBalance(double initialBalance) {
    when(mockAccountRepository.getAccountById(accountId))
        .thenAnswer((_) async => buildAccount(initialBalance: initialBalance));
    when(mockTransactionRepository.getLatestBalance(accountId))
        .thenAnswer((_) async => null);
  }

  setUp(() {
    mockTransactionRepository = MockTransactionRepository();
    mockAccountRepository = MockAccountRepository();
    useCase = ProcessTransactionUseCase(
      transactionRepository: mockTransactionRepository,
      accountRepository: mockAccountRepository,
    );
  });

  group('ProcessTransactionUseCase', () {
    test('Procesa transacción de crédito exitosamente', () async {
      // Dado (Arrange): una cuenta con saldo de 1000 y un repositorio que
      // guarda la información sin errores
      givenAccountWithInitialBalance(1000);
      when(mockTransactionRepository.saveTransaction(any)).thenAnswer(
          (invocation) async =>
              invocation.positionalArguments.first as Transaction);
      when(mockTransactionRepository.updateBalance(any))
          .thenAnswer((_) async {});

      // Cuando (Act): se procesa un ingreso de 200
      final result = await useCase.execute(
        buildParams(amount: 200, type: TransactionType.income),
      );

      // Entonces (Assert): la operación es exitosa y el saldo sube a 1200
      expect(result.success, isTrue);
      expect(result.errorMessage, isNull);
      expect(result.transaction.status, TransactionStatus.completed);
      expect(result.transaction.amount, 200);
      expect(result.updatedBalance.currentBalance, 1200);
      expect(result.updatedBalance.income, 200);
      verify(mockTransactionRepository.saveTransaction(any)).called(1);
      verify(mockTransactionRepository.updateBalance(result.updatedBalance))
          .called(1);
    });

    test('Rechaza transacción de débito por saldo insuficiente', () async {
      // Dado (Arrange): una cuenta con un saldo de solo 100
      givenAccountWithInitialBalance(100);

      // Cuando (Act): se intenta procesar un gasto de 500
      final result = await useCase.execute(
        buildParams(amount: 500, type: TransactionType.expense),
      );

      // Entonces (Assert): la operación se rechaza, el saldo no cambia y no se
      // guarda nada
      expect(result.success, isFalse);
      expect(result.errorMessage,
          'Saldo insuficiente para realizar esta transacción');
      expect(result.transaction.status, TransactionStatus.failed);
      expect(result.updatedBalance.currentBalance, 100);
      verifyNever(mockTransactionRepository.saveTransaction(any));
      verifyNever(mockTransactionRepository.updateBalance(any));
    });

    test('Maneja error de red durante procesamiento', () async {
      // Dado (Arrange): una cuenta con saldo suficiente y un repositorio que
      // falla por falta de conexión al guardar la transacción
      givenAccountWithInitialBalance(1000);
      when(mockTransactionRepository.saveTransaction(any))
          .thenAnswer((_) async => throw const SocketException('Sin conexión'));

      // Cuando (Act): se procesa un ingreso de 200
      final result = await useCase.execute(
        buildParams(amount: 200, type: TransactionType.income),
      );

      // Entonces (Assert): el error se captura y se informa en el resultado,
      // sin lanzar excepción
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Error al procesar la transacción'));
      expect(result.errorMessage, contains('Sin conexión'));
      verifyNever(mockTransactionRepository.updateBalance(any));
    });

    test('Marca transacción como fallida en caso de error', () async {
      // Dado (Arrange): un repositorio que guarda la transacción pero falla al
      // actualizar el balance
      givenAccountWithInitialBalance(1000);
      when(mockTransactionRepository.saveTransaction(any)).thenAnswer(
          (invocation) async =>
              invocation.positionalArguments.first as Transaction);
      when(mockTransactionRepository.updateBalance(any))
          .thenAnswer((_) async => throw Exception('Fallo al actualizar'));

      // Cuando (Act): se procesa un ingreso de 200
      final result = await useCase.execute(
        buildParams(amount: 200, type: TransactionType.income),
      );

      // Entonces (Assert): la transacción queda en estado fallido y el balance
      // devuelto es el original, sin el ingreso aplicado
      expect(result.success, isFalse);
      expect(result.transaction.status, TransactionStatus.failed);
      expect(result.updatedBalance.currentBalance, 1000);
    });
  });
}
