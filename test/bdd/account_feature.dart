import 'package:finance_app/data/datasources/mock_remote_account_datasource.dart';
import 'package:finance_app/data/repositories/account_repository_impl.dart';
import 'package:finance_app/domain/entities/account.dart';
import 'package:finance_app/domain/usecases/calculate_balance_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/in_memory_transaction_repository.dart';

/// Feature: Gestión de Cuentas
///
///   Como usuario de la aplicación de finanzas personales
///   Quiero crear y administrar mis cuentas
///   Para organizar mi dinero y saber con cuántos fondos cuento
///
/// Las pruebas usan el repositorio real de cuentas respaldado por la fuente
/// remota en memoria ([MockRemoteAccountDataSource]), sin latencia simulada.
void main() {
  late AccountRepositoryImpl accountRepository;
  late CalculateBalanceUseCase calculateBalance;

  Account anAccount({
    String id = 'acc_1',
    String name = 'Cuenta principal',
    double initialBalance = 1000,
    Currency currency = Currency.usd,
    AccountType type = AccountType.checking,
  }) =>
      Account(
        id: id,
        name: name,
        userId: 'user_1',
        initialBalance: initialBalance,
        currency: currency,
        type: type,
        createdAt: DateTime(2024, 1, 1),
      );

  setUp(() {
    accountRepository = AccountRepositoryImpl(
      remoteDataSource: MockRemoteAccountDataSource(
        initialAccounts: const [],
        latency: Duration.zero,
      ),
    );
    calculateBalance = CalculateBalanceUseCase(
      accountRepository: accountRepository,
      transactionRepository: InMemoryTransactionRepository(),
    );
  });

  group('Feature: Gestión de Cuentas', () {
    test('Scenario: Crear cuenta con balance inicial válido', () async {
      // Dado (Arrange): que el usuario tiene los datos de una cuenta con balance
      // inicial de 500
      final newAccount = anAccount(initialBalance: 500);

      // Cuando (Act): el usuario crea la cuenta
      final created = await accountRepository.createAccount(newAccount);

      // Entonces (Assert): la cuenta se crea con el balance inicial indicado
      expect(created.id, newAccount.id);
      expect(created.initialBalance, 500);
      // Y la cuenta puede consultarse posteriormente
      expect(await accountRepository.accountExists(newAccount.id), isTrue);
      final stored = await accountRepository.getAccountById(newAccount.id);
      expect(stored, newAccount);
    });

    test('Scenario: Crear cuenta con balance inicial negativo es rechazado',
        () async {
      // Dado (Arrange): que el usuario tiene los datos de una cuenta con balance
      // inicial de -100
      final invalidAccount = anAccount(initialBalance: -100);

      // Cuando (Act): el usuario intenta crear la cuenta
      final attempt = accountRepository.createAccount(invalidAccount);

      // Entonces (Assert): la creación es rechazada
      await expectLater(attempt, throwsA(isA<Exception>()));
      // Y la cuenta no existe
      expect(await accountRepository.accountExists(invalidAccount.id), isFalse);
    });

    test('Scenario: Actualizar información de cuenta', () async {
      // Dado (Arrange): que existe una cuenta llamada "Cuenta principal"
      final original =
          await accountRepository.createAccount(anAccount(initialBalance: 750));

      // Cuando (Act): el usuario cambia el nombre a "Ahorros vacaciones"
      await accountRepository
          .updateAccount(original.copyWith(name: 'Ahorros vacaciones'));

      // Entonces (Assert): la cuenta consultada muestra el nuevo nombre
      final updated = await accountRepository.getAccountById(original.id);
      expect(updated?.name, 'Ahorros vacaciones');
      // Y el resto de la información se conserva
      expect(updated?.initialBalance, 750);
      expect(updated?.currency, original.currency);
      expect(updated?.type, original.type);
      // Y queda registrada la fecha de actualización
      expect(updated?.updatedAt, isNotNull);
    });

    test('Scenario: Cambiar tipo de cuenta', () async {
      // Dado (Arrange): que existe una cuenta corriente
      final original = await accountRepository
          .createAccount(anAccount(type: AccountType.checking));

      // Cuando (Act): el usuario la convierte en cuenta de ahorros
      await accountRepository
          .updateAccount(original.copyWith(type: AccountType.savings));

      // Entonces (Assert): la cuenta consultada es de tipo ahorros
      final updated = await accountRepository.getAccountById(original.id);
      expect(updated?.type, AccountType.savings);
      // Y el nombre y el balance inicial no cambian
      expect(updated?.name, original.name);
      expect(updated?.initialBalance, original.initialBalance);
    });

    test('Scenario: Verificar balance disponible para transacción', () async {
      // Dado (Arrange): que existe una cuenta con balance de 500
      final account =
          await accountRepository.createAccount(anAccount(initialBalance: 500));

      // Cuando (Act): el usuario consulta si puede retirar 200
      final canWithdraw = await calculateBalance.canWithdraw(account.id, 200);

      // Entonces (Assert): la consulta indica que hay fondos suficientes
      expect(canWithdraw, isTrue);
    });

    test('Scenario: Verificar fondos insuficientes', () async {
      // Dado (Arrange): que existe una cuenta con balance de 500
      final account =
          await accountRepository.createAccount(anAccount(initialBalance: 500));

      // Cuando (Act): el usuario consulta si puede retirar 800
      final canWithdraw = await calculateBalance.canWithdraw(account.id, 800);

      // Entonces (Assert): la consulta indica que los fondos son insuficientes
      expect(canWithdraw, isFalse);
    });
  });

  group('Cuentas con múltiples monedas', () {
    test('Scenario: Cuenta en dólares tiene moneda correcta', () async {
      // Dado (Arrange): que el usuario creó una cuenta en dólares
      await accountRepository
          .createAccount(anAccount(id: 'acc_usd', currency: Currency.usd));

      // Cuando (Act): el usuario consulta la cuenta
      final account = await accountRepository.getAccountById('acc_usd');

      // Entonces (Assert): la cuenta está en USD
      expect(account?.currency, Currency.usd);
    });

    test('Scenario: Cuenta en euros tiene moneda correcta', () async {
      // Dado (Arrange): que el usuario creó una cuenta en euros
      await accountRepository
          .createAccount(anAccount(id: 'acc_eur', currency: Currency.eur));

      // Cuando (Act): el usuario consulta la cuenta
      final account = await accountRepository.getAccountById('acc_eur');

      // Entonces (Assert): la cuenta está en EUR
      expect(account?.currency, Currency.eur);
    });

    test('Scenario: Balance refleja la moneda de la cuenta', () async {
      // Dado (Arrange): que existe una cuenta en pesos colombianos con balance de
      // 2000000
      await accountRepository.createAccount(
        anAccount(
          id: 'acc_cop',
          initialBalance: 2000000,
          currency: Currency.cop,
        ),
      );

      // Cuando (Act): el usuario calcula el balance de la cuenta
      final balance = await calculateBalance.execute('acc_cop');

      // Entonces (Assert): el balance está expresado en COP
      expect(balance.currency, Currency.cop);
      // Y el monto corresponde al balance inicial
      expect(balance.currentBalance, 2000000);
    });
  });

  group('Copia inmutable de cuentas', () {
    test('Scenario: copyWith preserva valores no modificados', () {
      // Dado (Arrange): que existe una cuenta de ahorros en euros llamada
      // "Fondo de emergencia"
      final original = anAccount(
        name: 'Fondo de emergencia',
        initialBalance: 3000,
        currency: Currency.eur,
        type: AccountType.savings,
      );

      // Cuando (Act): se crea una copia cambiando solo el nombre
      final copy = original.copyWith(name: 'Fondo familiar');

      // Entonces (Assert): la copia tiene el nuevo nombre
      expect(copy.name, 'Fondo familiar');
      // Y conserva el resto de los valores
      expect(copy.id, original.id);
      expect(copy.userId, original.userId);
      expect(copy.initialBalance, 3000);
      expect(copy.currency, Currency.eur);
      expect(copy.type, AccountType.savings);
      expect(copy.createdAt, original.createdAt);
      // Y la cuenta original no se modifica
      expect(original.name, 'Fondo de emergencia');
    });
  });
}
