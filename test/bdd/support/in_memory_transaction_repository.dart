import 'package:finance_app/domain/entities/balance.dart';
import 'package:finance_app/domain/entities/transaction.dart';
import 'package:finance_app/domain/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Implementación en memoria de [TransactionRepository] para las pruebas
/// funcionales (BDD). Conserva el estado entre pasos de un escenario, de modo
/// que los casos de uso reales se ejercitan de extremo a extremo sin mocks.
///
/// Solo implementa los métodos que usan los escenarios; el resto lanza
/// [UnimplementedError] (comportamiento de [Fake]).
class InMemoryTransactionRepository extends Fake
    implements TransactionRepository {
  final Map<String, Transaction> _transactions = {};
  final Map<String, Balance> _balances = {};

  /// Ids de las transacciones almacenadas, útil para verificar en los escenarios.
  List<Transaction> get stored => _transactions.values.toList();

  @override
  Future<List<Transaction>> getTransactionsByAccount(String accountId) async {
    return _transactions.values.where((t) => t.accountId == accountId).toList();
  }

  @override
  Future<List<Transaction>> getPendingTransactions(String accountId) async {
    return _transactions.values
        .where((t) =>
            t.accountId == accountId && t.status == TransactionStatus.pending)
        .toList();
  }

  @override
  Future<Transaction?> getTransactionById(String id) async {
    return _transactions[id];
  }

  @override
  Future<Transaction> createTransaction(Transaction transaction) async {
    _transactions[transaction.id] = transaction;
    return transaction;
  }

  @override
  Future<Transaction> saveTransaction(Transaction transaction) async {
    _transactions[transaction.id] = transaction;
    return transaction;
  }

  @override
  Future<Transaction> updateTransaction(Transaction transaction) async {
    if (!_transactions.containsKey(transaction.id)) {
      throw StateError('Transacción ${transaction.id} no existe');
    }
    _transactions[transaction.id] = transaction;
    return transaction;
  }

  @override
  Future<Balance?> getLatestBalance(String accountId) async {
    return _balances[accountId];
  }

  @override
  Future<void> updateBalance(Balance balance) async {
    _balances[balance.accountId] = balance;
  }
}
