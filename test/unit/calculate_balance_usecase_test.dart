import 'package:finance_app/domain/entities/account.dart';
import 'package:finance_app/domain/entities/transaction.dart';
import 'package:finance_app/domain/repositories/account_repository.dart';
import 'package:finance_app/domain/repositories/transaction_repository.dart';
import 'package:finance_app/domain/usecases/calculate_balance_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'calculate_balance_usecase_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<TransactionRepository>(),
  MockSpec<AccountRepository>(),
])
void main() {
  const accountId = 'acc_1';

  late CalculateBalanceUseCase useCase;
  late MockTransactionRepository mockTransactionRepository;
  late MockAccountRepository mockAccountRepository;

  Account buildAccount({double initialBalance = 1000}) => Account(
        id: accountId,
        name: 'Cuenta de ahorros',
        userId: 'user_1',
        initialBalance: initialBalance,
        currency: Currency.usd,
        type: AccountType.savings,
        createdAt: DateTime(2024, 1, 1),
      );

  Transaction buildTransaction({
    required String id,
    required double amount,
    required TransactionType type,
    TransactionStatus status = TransactionStatus.completed,
  }) =>
      Transaction(
        id: id,
        accountId: accountId,
        amount: amount,
        description: 'Transacción $id',
        date: DateTime(2024, 1, 15),
        category: 'general',
        type: type,
        status: status,
      );

  setUp(() {
    mockTransactionRepository = MockTransactionRepository();
    mockAccountRepository = MockAccountRepository();
    useCase = CalculateBalanceUseCase(
      accountRepository: mockAccountRepository,
      transactionRepository: mockTransactionRepository,
    );
  });

  group('CalculateBalanceUseCase', () {
    test('Calcula saldo correctamente para cuenta con transacciones positivas',
        () async {
      // Given (Arrange): una cuenta con saldo inicial 1000 y dos ingresos completados
      when(mockAccountRepository.getAccountById(accountId))
          .thenAnswer((_) async => buildAccount(initialBalance: 1000));
      when(mockTransactionRepository.getTransactionsByAccount(accountId))
          .thenAnswer((_) async => [
                buildTransaction(
                    id: 't1', amount: 500, type: TransactionType.income),
                buildTransaction(
                    id: 't2', amount: 250, type: TransactionType.income),
              ]);
      when(mockTransactionRepository.getPendingTransactions(accountId))
          .thenAnswer((_) async => []);

      // When (Act): se calcula el balance de la cuenta
      final balance = await useCase.execute(accountId);

      // Then (Assert): el saldo suma los ingresos y no hay gastos
      expect(balance.accountId, accountId);
      expect(balance.currentBalance, 1750);
      expect(balance.income, 750);
      expect(balance.expenses, 0);
      expect(balance.currency, Currency.usd);
      verify(mockAccountRepository.getAccountById(accountId)).called(1);
      verify(mockTransactionRepository.getTransactionsByAccount(accountId))
          .called(1);
    });

    test('Maneja cuenta sin transacciones correctamente', () async {
      // Given (Arrange): una cuenta con saldo inicial 500 y sin movimientos
      when(mockAccountRepository.getAccountById(accountId))
          .thenAnswer((_) async => buildAccount(initialBalance: 500));
      when(mockTransactionRepository.getTransactionsByAccount(accountId))
          .thenAnswer((_) async => []);
      when(mockTransactionRepository.getPendingTransactions(accountId))
          .thenAnswer((_) async => []);

      // When (Act): se calcula el balance de la cuenta
      final balance = await useCase.execute(accountId);

      // Then (Assert): el saldo es igual al inicial y los acumulados son cero
      expect(balance.currentBalance, 500);
      expect(balance.income, 0);
      expect(balance.expenses, 0);
    });

    test('Calcula saldo con transacciones de ambos tipos', () async {
      // Given (Arrange): ingreso y gasto completados, y un gasto pendiente
      // que no debe afectar el saldo
      when(mockAccountRepository.getAccountById(accountId))
          .thenAnswer((_) async => buildAccount(initialBalance: 1000));
      final pendingExpense = buildTransaction(
        id: 't3',
        amount: 100,
        type: TransactionType.expense,
        status: TransactionStatus.pending,
      );
      when(mockTransactionRepository.getTransactionsByAccount(accountId))
          .thenAnswer((_) async => [
                buildTransaction(
                    id: 't1', amount: 2000, type: TransactionType.income),
                buildTransaction(
                    id: 't2', amount: 300, type: TransactionType.expense),
                pendingExpense,
              ]);
      when(mockTransactionRepository.getPendingTransactions(accountId))
          .thenAnswer((_) async => [pendingExpense]);

      // When (Act): se calcula el balance de la cuenta
      final balance = await useCase.execute(accountId);

      // Then (Assert): 1000 + 2000 - 300 = 2700, ignorando la transacción pendiente
      expect(balance.currentBalance, 2700);
      expect(balance.income, 2000);
      expect(balance.expenses, 300);
    });
  });
}
