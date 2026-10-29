import 'package:finance_app/data/datasources/mock_remote_account_datasource.dart';
import 'package:finance_app/data/models/account_model.dart';
import 'package:finance_app/data/repositories/account_repository_impl.dart';
import 'package:finance_app/data/repositories/transaction_repository_impl.dart';
import 'package:finance_app/domain/entities/account.dart';
import 'package:finance_app/domain/entities/transaction.dart';
import 'package:finance_app/domain/usecases/calculate_balance_usecase.dart';
import 'package:finance_app/domain/usecases/notify_transaction_usecase.dart';
import 'package:finance_app/domain/usecases/process_transaction_usecase.dart';
import 'package:finance_app/presentation/viewmodels/finance_viewmodel.dart';

import 'in_memory_local_transaction_datasource.dart';
import 'recording_push_notification_service.dart';

/// Construye la aplicación real, de la capa de presentación a la de datos,
/// cambiando solo los bordes externos (API remota, SQLite y push) por
/// implementaciones en memoria. Sin mocks: cada prueba de integración recorre
/// ViewModel, casos de uso, repositorios y modelos reales.
class FinanceTestEnvironment {
  final InMemoryLocalTransactionDataSource localDataSource;
  final RecordingPushNotificationService notificationService;
  final AccountRepositoryImpl accountRepository;
  final TransactionRepositoryImpl transactionRepository;
  final ProcessTransactionUseCase processTransaction;
  final CalculateBalanceUseCase calculateBalance;
  final NotifyTransactionUseCase notifyTransaction;

  FinanceTestEnvironment._({
    required this.localDataSource,
    required this.notificationService,
    required this.accountRepository,
    required this.transactionRepository,
    required this.processTransaction,
    required this.calculateBalance,
    required this.notifyTransaction,
  });

  factory FinanceTestEnvironment({required List<Account> accounts}) {
    final remote = MockRemoteAccountDataSource(
      initialAccounts: accounts.map(AccountModel.fromEntity).toList(),
      latency: Duration.zero,
    );
    final local = InMemoryLocalTransactionDataSource();
    final notifications = RecordingPushNotificationService();

    final accountRepository = AccountRepositoryImpl(remoteDataSource: remote);
    final transactionRepository =
        TransactionRepositoryImpl(localDataSource: local);

    return FinanceTestEnvironment._(
      localDataSource: local,
      notificationService: notifications,
      accountRepository: accountRepository,
      transactionRepository: transactionRepository,
      processTransaction: ProcessTransactionUseCase(
        transactionRepository: transactionRepository,
        accountRepository: accountRepository,
      ),
      calculateBalance: CalculateBalanceUseCase(
        accountRepository: accountRepository,
        transactionRepository: transactionRepository,
      ),
      notifyTransaction:
          NotifyTransactionUseCase(notificationService: notifications),
    );
  }

  /// Crea un [FinanceViewModel] conectado a los mismos repositorios y casos de
  /// uso del entorno.
  FinanceViewModel createViewModel() {
    return FinanceViewModel(
      transactionRepository: transactionRepository,
      accountRepository: accountRepository,
      calculateBalanceUseCase: calculateBalance,
      processTransactionUseCase: processTransaction,
    );
  }

  /// Registra una transacción a través del caso de uso real.
  Future<ProcessTransactionResult> process({
    required String accountId,
    required double amount,
    required TransactionType type,
    String description = 'Movimiento',
    String category = 'general',
    DateTime? date,
  }) {
    return processTransaction.execute(
      ProcessTransactionParams(
        accountId: accountId,
        amount: amount,
        description: description,
        category: category,
        type: type,
        date: date,
      ),
    );
  }
}

/// Crea una cuenta de prueba con valores por defecto.
Account buildAccount({
  String id = 'acc_1',
  String userId = 'user_1',
  double initialBalance = 1000,
  Currency currency = Currency.usd,
  AccountType type = AccountType.checking,
}) {
  return Account(
    id: id,
    name: 'Cuenta $id',
    userId: userId,
    initialBalance: initialBalance,
    currency: currency,
    type: type,
    createdAt: DateTime(2024, 1, 1),
  );
}
