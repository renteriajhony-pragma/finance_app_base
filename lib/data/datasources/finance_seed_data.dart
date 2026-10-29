import 'package:finance_app/data/models/account_model.dart';
import 'package:finance_app/data/models/transaction_model.dart';

/// Datos iniciales compartidos entre el datasource remoto simulado y el
/// datasource local, para que los ids de cuenta de las transacciones
/// correspondan siempre a cuentas existentes.
class FinanceSeedData {
  FinanceSeedData._();

  static const String defaultUserId = 'user_001';
  static const String checkingAccountId = 'acc_checking_001';
  static const String savingsAccountId = 'acc_savings_001';
  static const String creditAccountId = 'acc_credit_001';
  static const String investmentAccountId = 'acc_investment_001';

  static final List<AccountModel> accounts = [
    AccountModel(
      id: checkingAccountId,
      name: 'Cuenta Corriente Principal',
      userId: defaultUserId,
      initialBalance: 5000000,
      currency: 'COP',
      type: 'checking',
      createdAt: DateTime.utc(2024, 1, 15),
    ),
    AccountModel(
      id: savingsAccountId,
      name: 'Cuenta de Ahorros',
      userId: defaultUserId,
      initialBalance: 12000000,
      currency: 'COP',
      type: 'savings',
      createdAt: DateTime.utc(2024, 2, 1),
    ),
    AccountModel(
      id: creditAccountId,
      name: 'Tarjeta de Crédito Visa',
      userId: defaultUserId,
      initialBalance: 0,
      currency: 'COP',
      type: 'credit',
      createdAt: DateTime.utc(2024, 3, 10),
    ),
    AccountModel(
      id: investmentAccountId,
      name: 'Portafolio de Inversión',
      userId: 'user_002',
      initialBalance: 2500,
      currency: 'USD',
      type: 'investment',
      createdAt: DateTime.utc(2024, 4, 5),
    ),
  ];

  /// Transacciones de ejemplo con fechas relativas a [now].
  static List<TransactionModel> transactions(DateTime now) {
    DateTime daysAgo(int days) => now.subtract(Duration(days: days));

    return [
      TransactionModel(
        id: 'txn_001',
        accountId: checkingAccountId,
        amount: 4500000,
        description: 'Pago de nómina',
        date: daysAgo(28),
        category: 'salary',
        type: 'income',
        status: 'completed',
      ),
      TransactionModel(
        id: 'txn_002',
        accountId: checkingAccountId,
        amount: 1200000,
        description: 'Arriendo apartamento',
        date: daysAgo(25),
        category: 'housing',
        type: 'expense',
        status: 'completed',
      ),
      TransactionModel(
        id: 'txn_003',
        accountId: checkingAccountId,
        amount: 350000,
        description: 'Mercado del mes',
        date: daysAgo(18),
        category: 'food',
        type: 'expense',
        status: 'completed',
      ),
      TransactionModel(
        id: 'txn_004',
        accountId: checkingAccountId,
        amount: 89900,
        description: 'Suscripción de streaming',
        date: daysAgo(10),
        category: 'entertainment',
        type: 'expense',
        status: 'completed',
      ),
      TransactionModel(
        id: 'txn_005',
        accountId: checkingAccountId,
        amount: 150000,
        description: 'Recarga de transporte',
        date: daysAgo(2),
        category: 'transport',
        type: 'expense',
        status: 'pending',
      ),
      TransactionModel(
        id: 'txn_006',
        accountId: savingsAccountId,
        amount: 1000000,
        description: 'Ahorro mensual',
        date: daysAgo(27),
        category: 'savings',
        type: 'income',
        status: 'completed',
      ),
      TransactionModel(
        id: 'txn_007',
        accountId: savingsAccountId,
        amount: 62000,
        description: 'Intereses del mes',
        date: daysAgo(5),
        category: 'interest',
        type: 'income',
        status: 'completed',
      ),
      TransactionModel(
        id: 'txn_008',
        accountId: creditAccountId,
        amount: 480000,
        description: 'Compra en tienda de electrónica',
        date: daysAgo(14),
        category: 'shopping',
        type: 'expense',
        status: 'completed',
      ),
      TransactionModel(
        id: 'txn_009',
        accountId: creditAccountId,
        amount: 95000,
        description: 'Cena en restaurante',
        date: daysAgo(3),
        category: 'food',
        type: 'expense',
        status: 'completed',
      ),
      TransactionModel(
        id: 'txn_010',
        accountId: investmentAccountId,
        amount: 300,
        description: 'Compra de ETF',
        date: daysAgo(20),
        category: 'investment',
        type: 'expense',
        status: 'completed',
      ),
    ];
  }
}
