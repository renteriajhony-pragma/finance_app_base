import 'package:finance_app/domain/entities/transaction.dart';
import 'package:finance_app/domain/usecases/notify_transaction_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/finance_test_environment.dart';

/// Pruebas de integración del flujo financiero.
///
/// Se arma la aplicación real (ViewModel, casos de uso, repositorios y
/// modelos) y solo se sustituyen los bordes externos: la API remota de
/// cuentas, la base de datos SQLite y el servicio de notificaciones push.
void main() {
  const accountId = 'acc_1';

  group('Flujo Financiero Completo', () {
    test('debe procesar una transacción de ingreso correctamente', () async {
      // Dado (Arrange): una cuenta con saldo inicial de 1000
      final env = FinanceTestEnvironment(
        accounts: [buildAccount(id: accountId, initialBalance: 1000)],
      );

      // Cuando (Act): se procesa un ingreso de 500
      final result = await env.process(
        accountId: accountId,
        amount: 500,
        type: TransactionType.income,
        description: 'Salario',
      );

      // Entonces (Assert): la transacción queda persistida como completada
      expect(result.success, isTrue);
      final stored = await env.transactionRepository
          .getTransactionById(result.transaction.id);
      expect(stored, result.transaction);
      expect(stored?.status, TransactionStatus.completed);
      // Y el balance guardado y el calculado desde el historial coinciden
      final latest =
          await env.transactionRepository.getLatestBalance(accountId);
      final calculated = await env.calculateBalance.execute(accountId);
      expect(latest?.currentBalance, 1500);
      expect(calculated.currentBalance, 1500);
    });

    test('debe rechazar transacción con monto inválido', () async {
      // Dado (Arrange): una cuenta con saldo inicial de 1000
      final env = FinanceTestEnvironment(
        accounts: [buildAccount(id: accountId, initialBalance: 1000)],
      );

      // Cuando (Act): se intentan procesar transacciones con monto cero y negativo
      final zeroAmount = await env.process(
        accountId: accountId,
        amount: 0,
        type: TransactionType.income,
      );
      final negativeAmount = await env.process(
        accountId: accountId,
        amount: -50,
        type: TransactionType.expense,
      );

      // Entonces (Assert): ambas se rechazan con el mensaje de monto inválido
      for (final result in [zeroAmount, negativeAmount]) {
        expect(result.success, isFalse);
        expect(result.errorMessage, 'El monto debe ser mayor a cero');
        expect(result.transaction.status, TransactionStatus.failed);
      }
      // Y no se guarda ninguna transacción ni cambia el saldo
      expect(env.localDataSource.count, 0);
      final balance = await env.calculateBalance.execute(accountId);
      expect(balance.currentBalance, 1000);
    });

    test('debe calcular balance total correctamente', () async {
      // Dado (Arrange): un usuario con dos cuentas, de 1000 y de 500
      final env = FinanceTestEnvironment(
        accounts: [
          buildAccount(id: 'acc_a', initialBalance: 1000),
          buildAccount(id: 'acc_b', initialBalance: 500),
        ],
      );

      // Cuando (Act): se registran un ingreso y un gasto en la cuenta A y un
      // gasto en la cuenta B, y se calcula el resumen del usuario
      await env.process(
          accountId: 'acc_a', amount: 1000, type: TransactionType.income);
      await env.process(
          accountId: 'acc_a', amount: 200, type: TransactionType.expense);
      await env.process(
          accountId: 'acc_b', amount: 100, type: TransactionType.expense);
      final summary = await env.calculateBalance.calculateSummary('user_1');

      // Entonces (Assert): el resumen consolida ambas cuentas
      // (1000 + 1000 - 200) + (500 - 100) = 2200
      expect(summary.accountCount, 2);
      expect(summary.totalIncome, 1000);
      expect(summary.totalExpenses, 300);
      expect(summary.totalBalance, 2200);
      expect(summary.netSavings, 700);
    });

    test('debe mantener consistencia durante actualización concurrente',
        () async {
      // Dado (Arrange): una cuenta con saldo inicial de 1000
      final env = FinanceTestEnvironment(
        accounts: [buildAccount(id: accountId, initialBalance: 1000)],
      );
      const operations = 20;

      // Cuando (Act): se procesan 20 ingresos de 50 al mismo tiempo
      final results = await Future.wait(
        List.generate(
          operations,
          (_) => env.process(
            accountId: accountId,
            amount: 50,
            type: TransactionType.income,
          ),
        ),
      );

      // Entonces (Assert): todas las operaciones se registran
      expect(results.every((r) => r.success), isTrue);
      expect(env.localDataSource.count, operations);
      // Y el balance guardado coincide con el calculado desde el historial
      // (1000 + 20 * 50 = 2000)
      final calculated = await env.calculateBalance.execute(accountId);
      final latest =
          await env.transactionRepository.getLatestBalance(accountId);
      expect(calculated.currentBalance, 2000);
      expect(latest?.currentBalance, calculated.currentBalance);
      expect(latest?.income, calculated.income);
    });

    test('debe notificar transacción procesada', () async {
      // Dado (Arrange): una cuenta con saldo de 1000 y un servicio de
      // notificaciones disponible
      final env = FinanceTestEnvironment(
        accounts: [buildAccount(id: accountId, initialBalance: 1000)],
      );

      // Cuando (Act): se procesa un ingreso de 500 y se notifica al usuario
      final result = await env.process(
        accountId: accountId,
        amount: 500,
        type: TransactionType.income,
        description: 'Salario',
      );
      final notification = await env.notifyTransaction.notifyLargeTransaction(
        result.transaction,
        result.updatedBalance.currentBalance,
      );

      // Entonces (Assert): la notificación se envía una sola vez con prioridad alta
      expect(notification.success, isTrue);
      expect(env.notificationService.sent, hasLength(1));
      final sent = env.notificationService.sent.single;
      expect(sent.priority, NotificationPriority.high);
      // Y su contenido describe la transacción y el saldo actual
      expect(sent.payload.transactionId, result.transaction.id);
      expect(sent.payload.title, 'Transacción recibida');
      expect(sent.payload.body, contains('\$500.00'));
      expect(sent.payload.body, contains('Saldo actual: \$1500.00'));
      expect(sent.payload.body, contains('Salario'));
      expect(sent.payload.metadata?['accountId'], accountId);
    });

    test('debe manejar error de red durante procesamiento', () async {
      // Dado (Arrange): una cuenta con saldo de 1000 y un almacenamiento sin
      // conexión
      final env = FinanceTestEnvironment(
        accounts: [buildAccount(id: accountId, initialBalance: 1000)],
      );
      env.localDataSource.isOffline = true;

      // Cuando (Act): se intenta procesar un ingreso y luego se notifica la falla
      final failed = await env.process(
        accountId: accountId,
        amount: 200,
        type: TransactionType.income,
      );
      await env.notifyTransaction.notifyFailedTransaction(
        failed.transaction,
        failed.errorMessage!,
      );

      // Entonces (Assert): el error se informa sin lanzar excepción y no se
      // guarda nada
      expect(failed.success, isFalse);
      expect(failed.errorMessage, contains('Error al procesar la transacción'));
      expect(failed.errorMessage, contains('Sin conexión'));
      expect(failed.transaction.status, TransactionStatus.failed);
      expect(env.localDataSource.count, 0);
      expect(
          await env.transactionRepository.getLatestBalance(accountId), isNull);
      // Y el usuario recibe una notificación urgente de la falla
      final sent = env.notificationService.sent.single;
      expect(sent.priority, NotificationPriority.urgent);
      expect(sent.payload.title, 'Transacción fallida');

      // Cuando (Act): vuelve la conexión y se reintenta la operación
      env.localDataSource.isOffline = false;
      final retried = await env.process(
        accountId: accountId,
        amount: 200,
        type: TransactionType.income,
      );

      // Entonces (Assert): la operación se completa y el saldo es correcto
      expect(retried.success, isTrue);
      final balance = await env.calculateBalance.execute(accountId);
      expect(balance.currentBalance, 1200);
    });

    test('debe validar cuenta existente antes de procesar', () async {
      // Dado (Arrange): un entorno que solo tiene la cuenta acc_1
      final env = FinanceTestEnvironment(
        accounts: [buildAccount(id: accountId)],
      );

      // Cuando (Act): se procesa una transacción para una cuenta inexistente
      final result = await env.process(
        accountId: 'acc_inexistente',
        amount: 100,
        type: TransactionType.income,
      );

      // Entonces (Assert): se rechaza porque la cuenta no existe
      expect(result.success, isFalse);
      expect(result.errorMessage, 'Cuenta no encontrada');
      // Y no se guarda ninguna transacción
      expect(env.localDataSource.count, 0);
    });

    test('debe aplicar transacción a cuenta específica', () async {
      // Dado (Arrange): dos cuentas del mismo usuario con saldo de 1000
      final env = FinanceTestEnvironment(
        accounts: [
          buildAccount(id: 'acc_a', initialBalance: 1000),
          buildAccount(id: 'acc_b', initialBalance: 1000),
        ],
      );

      // Cuando (Act): se registra un gasto de 300 solo en la cuenta A
      final result = await env.process(
        accountId: 'acc_a',
        amount: 300,
        type: TransactionType.expense,
      );

      // Entonces (Assert): la transacción pertenece a la cuenta A
      expect(result.success, isTrue);
      expect(result.transaction.accountId, 'acc_a');
      final transactionsA =
          await env.transactionRepository.getTransactionsByAccount('acc_a');
      expect(transactionsA, hasLength(1));
      // Y la cuenta B no registra movimientos
      final transactionsB =
          await env.transactionRepository.getTransactionsByAccount('acc_b');
      expect(transactionsB, isEmpty);
      // Y los saldos reflejan el gasto solo en la cuenta A
      expect((await env.calculateBalance.execute('acc_a')).currentBalance, 700);
      expect(
          (await env.calculateBalance.execute('acc_b')).currentBalance, 1000);
    });
  });

  group('Escenarios BDD - Finanzas Personales', () {
    test('Scenario: Usuario registra ingreso exitoso', () async {
      // Dado (Arrange): que el usuario abrió la app con una cuenta de saldo 1000
      final env = FinanceTestEnvironment(
        accounts: [buildAccount(id: accountId, initialBalance: 1000)],
      );
      final viewModel = env.createViewModel();
      await viewModel.loadInitialData();

      // Cuando (Act): el usuario registra un ingreso de 750 por "Freelance"
      final added = await viewModel.addTransaction(
        amount: 750,
        description: 'Freelance',
        category: 'ingreso',
        isIncome: true,
      );

      // Entonces (Assert): la operación es exitosa y no hay errores
      expect(added, isTrue);
      expect(viewModel.error, isNull);
      // Y el ingreso aparece en la lista de transacciones
      expect(viewModel.transactions, hasLength(1));
      expect(viewModel.transactions.single.description, 'Freelance');
      expect(viewModel.transactions.single.status, TransactionStatus.completed);
      // Y el saldo mostrado pasa a 1750
      expect(viewModel.currentBalance?.currentBalance, 1750);
      expect(viewModel.totalIncome, 750);
    });

    test('Scenario: Usuario registra gasto con fondos insuficientes', () async {
      // Dado (Arrange): que el usuario tiene una cuenta con saldo de 100
      final env = FinanceTestEnvironment(
        accounts: [buildAccount(id: accountId, initialBalance: 100)],
      );
      final viewModel = env.createViewModel();
      await viewModel.loadInitialData();

      // Cuando (Act): el usuario intenta registrar un gasto de 500
      final added = await viewModel.addTransaction(
        amount: 500,
        description: 'Televisor',
        category: 'compras',
        isIncome: false,
      );

      // Entonces (Assert): la operación se rechaza y se muestra el error
      expect(added, isFalse);
      expect(viewModel.error, contains('Saldo insuficiente'));
      // Y no se registra la transacción
      expect(viewModel.transactions, isEmpty);
      expect(env.localDataSource.count, 0);
      // Y el saldo sigue en 100
      expect(viewModel.currentBalance?.currentBalance, 100);
    });

    test('Scenario: Consulta de balance en período específico', () async {
      // Dado (Arrange): que el usuario registró movimientos en enero, febrero
      // y marzo
      final env = FinanceTestEnvironment(
        accounts: [buildAccount(id: accountId, initialBalance: 0)],
      );
      await env.process(
        accountId: accountId,
        amount: 1000,
        type: TransactionType.income,
        date: DateTime(2024, 1, 15),
      );
      await env.process(
        accountId: accountId,
        amount: 500,
        type: TransactionType.income,
        date: DateTime(2024, 2, 5),
      );
      await env.process(
        accountId: accountId,
        amount: 200,
        type: TransactionType.expense,
        date: DateTime(2024, 2, 20),
      );
      await env.process(
        accountId: accountId,
        amount: 300,
        type: TransactionType.income,
        date: DateTime(2024, 3, 10),
      );

      // Cuando (Act): el usuario consulta los movimientos de febrero
      final february =
          await env.transactionRepository.getTransactionsByDateRange(
        accountId,
        DateTime(2024, 2, 1),
        DateTime(2024, 2, 29, 23, 59, 59),
      );
      final periodBalance = february.fold<double>(
        0,
        (sum, t) => sum + t.calculateBalanceImpact(),
      );

      // Entonces (Assert): solo aparecen los dos movimientos de febrero
      expect(february, hasLength(2));
      expect(february.every((t) => t.date.month == 2), isTrue);
      // Y el balance del período es 500 - 200 = 300
      expect(periodBalance, 300);
      // Y el balance total de la cuenta no se altera: 1000 + 500 - 200 + 300
      final total = await env.calculateBalance.execute(accountId);
      expect(total.currentBalance, 1600);
    });
  });

  group('Rendimiento y Carga', () {
    test('debe procesar 10000 transacciones en menos de 2 segundos', () async {
      // Dado (Arrange): una cuenta sin saldo inicial
      final env = FinanceTestEnvironment(
        accounts: [buildAccount(id: accountId, initialBalance: 0)],
      );
      const total = 10000;
      var failures = 0;
      final stopwatch = Stopwatch()..start();

      // Cuando (Act): se procesan 10000 ingresos de 10
      for (var i = 0; i < total; i++) {
        final result = await env.process(
          accountId: accountId,
          amount: 10,
          type: TransactionType.income,
        );
        if (!result.success) failures++;
      }
      stopwatch.stop();

      // Entonces (Assert): todas se procesan en menos de 2 segundos
      expect(failures, 0);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
      // Y las 10000 transacciones quedan almacenadas con el saldo correcto
      expect(env.localDataSource.count, total);
      final latest =
          await env.transactionRepository.getLatestBalance(accountId);
      expect(latest?.currentBalance, total * 10);
    });

    test('debe mantener tiempo de respuesta bajo carga concurrente', () async {
      // Dado (Arrange): 20 cuentas sin saldo inicial, cada una con su propio
      // flujo de 50 ingresos de 10
      const accountCount = 20;
      const operationsPerAccount = 50;
      final accountIds = List.generate(accountCount, (i) => 'acc_$i');
      final env = FinanceTestEnvironment(
        accounts: [
          for (final id in accountIds) buildAccount(id: id, initialBalance: 0),
        ],
      );
      final latencies = <Duration>[];

      Future<void> runAccountFlow(String id) async {
        for (var i = 0; i < operationsPerAccount; i++) {
          final stopwatch = Stopwatch()..start();
          final result = await env.process(
            accountId: id,
            amount: 10,
            type: TransactionType.income,
          );
          stopwatch.stop();
          expect(result.success, isTrue);
          latencies.add(stopwatch.elapsed);
        }
      }

      // Cuando (Act): todas las cuentas operan al mismo tiempo
      final totalStopwatch = Stopwatch()..start();
      await Future.wait(accountIds.map(runAccountFlow));
      totalStopwatch.stop();

      // Entonces (Assert): se completan todas las operaciones
      expect(latencies, hasLength(accountCount * operationsPerAccount));
      expect(env.localDataSource.count, accountCount * operationsPerAccount);
      // Y el percentil 95 de la latencia por operación es menor a 500 ms
      latencies.sort();
      final p95 = latencies[(latencies.length * 0.95).floor() - 1];
      expect(p95, lessThan(const Duration(milliseconds: 500)));
      // Y cada cuenta conserva su saldo correcto
      for (final id in accountIds) {
        final balance = await env.calculateBalance.execute(id);
        expect(balance.currentBalance, operationsPerAccount * 10);
      }
    });
  });
}
