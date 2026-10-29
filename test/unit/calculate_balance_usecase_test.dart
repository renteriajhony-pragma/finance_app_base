import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:finance_app/domain/repositories/transaction_repository.dart';
import 'package:finance_app/domain/repositories/account_repository.dart';
import 'package:finance_app/domain/usecases/calculate_balance_usecase.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

class MockAccountRepository extends Mock implements AccountRepository {}

void main() {
  group('CalculateBalanceUseCase', () {
    // ignore: unused_local_variable
    late CalculateBalanceUseCase useCase;
    late MockTransactionRepository mockTransactionRepository;
    late MockAccountRepository mockAccountRepository;

    setUp(() {
      mockTransactionRepository = MockTransactionRepository();
      mockAccountRepository = MockAccountRepository();
      useCase = CalculateBalanceUseCase(
        accountRepository: mockAccountRepository,
        transactionRepository: mockTransactionRepository,
      );
    });

    test(
      'Calcula saldo correctamente para cuenta con transacciones positivas',
      () {},
      skip: 'Fase 1: ejercicio pendiente',
    );

    test(
      'Maneja cuenta sin transacciones correctamente',
      () {},
      skip: 'Fase 1: ejercicio pendiente',
    );

    test(
      'Calcula saldo con transacciones de ambos tipos',
      () {},
      skip: 'Fase 1: ejercicio pendiente',
    );
  });
}
