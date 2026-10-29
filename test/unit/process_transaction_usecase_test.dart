import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:finance_app/domain/repositories/transaction_repository.dart';
import 'package:finance_app/domain/repositories/account_repository.dart';
import 'package:finance_app/domain/usecases/process_transaction_usecase.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

class MockAccountRepository extends Mock implements AccountRepository {}

void main() {
  group('ProcessTransactionUseCase', () {
    // ignore: unused_local_variable
    late ProcessTransactionUseCase useCase;
    late MockTransactionRepository mockTransactionRepository;
    late MockAccountRepository mockAccountRepository;

    setUp(() {
      mockTransactionRepository = MockTransactionRepository();
      mockAccountRepository = MockAccountRepository();
      useCase = ProcessTransactionUseCase(
        transactionRepository: mockTransactionRepository,
        accountRepository: mockAccountRepository,
      );
    });

    test(
      'Procesa transacción de crédito exitosamente',
      () {},
      skip: 'Fase 1: ejercicio pendiente',
    );

    test(
      'Rechaza transacción de débito por saldo insuficiente',
      () {},
      skip: 'Fase 1: ejercicio pendiente',
    );

    test(
      'Maneja error de red durante procesamiento',
      () {},
      skip: 'Fase 1: ejercicio pendiente',
    );

    test(
      'Marca transacción como fallida en caso de error',
      () {},
      skip: 'Fase 1: ejercicio pendiente',
    );
  });
}
