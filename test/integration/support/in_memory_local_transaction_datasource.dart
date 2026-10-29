import 'dart:io';

import 'package:finance_app/data/datasources/local_transaction_datasource.dart';
import 'package:finance_app/data/models/transaction_model.dart';

/// Implementación en memoria de [LocalTransactionDataSource] para las pruebas
/// de integración. Reemplaza únicamente la base de datos SQLite, de modo que el
/// repositorio real, los modelos y los casos de uso se ejercitan sin cambios.
///
/// Con [isOffline] en `true`, las escrituras fallan con un [SocketException],
/// lo que permite simular una falla de red o de almacenamiento.
class InMemoryLocalTransactionDataSource implements LocalTransactionDataSource {
  final Map<String, TransactionModel> _store = {};

  /// Cuando es `true`, `insertTransaction` y `updateTransaction` lanzan error.
  bool isOffline = false;

  /// Cantidad de transacciones almacenadas.
  int get count => _store.length;

  @override
  Future<void> initialize() async {}

  @override
  Future<List<TransactionModel>> getTransactions() async {
    return _sortedByDateDesc(_store.values);
  }

  @override
  Future<TransactionModel?> getTransactionById(String id) async {
    return _store[id];
  }

  @override
  Future<List<TransactionModel>> getTransactionsByAccountId(
    String accountId,
  ) async {
    return _sortedByDateDesc(
        _store.values.where((t) => t.accountId == accountId));
  }

  @override
  Future<TransactionModel> insertTransaction(
    TransactionModel transaction,
  ) async {
    _failIfOffline();
    _store[transaction.id] = transaction;
    return transaction;
  }

  @override
  Future<TransactionModel> updateTransaction(
    TransactionModel transaction,
  ) async {
    _failIfOffline();
    if (!_store.containsKey(transaction.id)) {
      throw LocalDataSourceException(
        message:
            'No se encontró la transacción para actualizar: ${transaction.id}',
      );
    }
    _store[transaction.id] = transaction;
    return transaction;
  }

  @override
  Future<void> deleteTransaction(String id) async {
    _store.remove(id);
  }

  @override
  Future<void> deleteTransactionsByAccountId(String accountId) async {
    _store.removeWhere((_, t) => t.accountId == accountId);
  }

  @override
  Future<List<TransactionModel>> getTransactionsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    return _sortedByDateDesc(
      _store.values
          .where((t) => !t.date.isBefore(start) && !t.date.isAfter(end)),
    );
  }

  @override
  Future<List<TransactionModel>> getTransactionsByCategory(
    String category,
  ) async {
    return _sortedByDateDesc(
        _store.values.where((t) => t.category == category));
  }

  @override
  Future<void> clearAllTransactions() async {
    _store.clear();
  }

  @override
  Future<void> close() async {}

  void _failIfOffline() {
    if (isOffline) {
      throw const SocketException('Sin conexión');
    }
  }

  List<TransactionModel> _sortedByDateDesc(Iterable<TransactionModel> models) {
    return models.toList()..sort((a, b) => b.date.compareTo(a.date));
  }
}
