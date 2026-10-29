import 'package:finance_app/data/datasources/remote_account_datasource.dart';
import 'package:finance_app/domain/entities/account.dart';
import 'package:finance_app/domain/entities/balance.dart';
import 'package:finance_app/domain/repositories/account_repository.dart';

class AccountRepositoryImpl implements AccountRepository {
  final RemoteAccountDataSource _remoteDataSource;
  final List<Account> _cache = [];
  final Map<String, Balance> _balances = {};
  bool _isCacheValid = false;

  AccountRepositoryImpl({
    required RemoteAccountDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  Future<List<Account>> getAccounts() async {
    if (_isCacheValid && _cache.isNotEmpty) {
      return List.unmodifiable(_cache);
    }

    try {
      final accountModels = await _remoteDataSource.fetchAccounts();
      _cache
        ..clear()
        ..addAll(accountModels.map((m) => m.toEntity()));
      _isCacheValid = true;
      return List.unmodifiable(_cache);
    } on DataSourceException catch (e) {
      throw RepositoryException(
        message: 'Error al obtener cuentas: ${e.message}',
        originalError: e,
      );
    } on NetworkException catch (e) {
      throw RepositoryException(
        message: 'Error de red al obtener cuentas: ${e.message}',
        originalError: e,
      );
    }
  }

  @override
  Future<Account?> getAccount(String id) => getAccountById(id);

  @override
  Future<Account?> getAccountById(String id) async {
    final cached = _cache.where((a) => a.id == id).firstOrNull;
    if (cached != null && _isCacheValid) {
      return cached;
    }

    try {
      final accountModel = await _remoteDataSource.fetchAccountById(id);
      if (accountModel == null) return null;
      final account = accountModel.toEntity();
      final existingIndex = _cache.indexWhere((a) => a.id == id);
      if (existingIndex >= 0) {
        _cache[existingIndex] = account;
      } else {
        _cache.add(account);
      }
      return account;
    } on DataSourceException catch (e) {
      throw RepositoryException(
        message: 'Error al obtener cuenta por ID: ${e.message}',
        originalError: e,
      );
    }
  }

  @override
  Future<Account> createAccount(Account account) async {
    try {
      final created = (await _remoteDataSource.createAccount(account)).toEntity();
      _cache.add(created);
      _invalidateCache();
      return created;
    } on DataSourceException catch (e) {
      throw RepositoryException(
        message: 'Error al crear cuenta: ${e.message}',
        originalError: e,
      );
    } on ValidationException catch (e) {
      throw RepositoryException(
        message: 'Validación fallida al crear cuenta: ${e.message}',
        originalError: e,
      );
    }
  }

  @override
  Future<Account> updateAccount(Account account) async {
    try {
      final updated = (await _remoteDataSource.updateAccount(account)).toEntity();
      final index = _cache.indexWhere((a) => a.id == account.id);
      if (index >= 0) {
        _cache[index] = updated;
      }
      _invalidateCache();
      return updated;
    } on DataSourceException catch (e) {
      throw RepositoryException(
        message: 'Error al actualizar cuenta: ${e.message}',
        originalError: e,
      );
    } on NotFoundException catch (e) {
      throw RepositoryException(
        message: 'Cuenta no encontrada para actualizar: ${e.message}',
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteAccount(String id) async {
    try {
      await _remoteDataSource.deleteAccount(id);
      _cache.removeWhere((a) => a.id == id);
      _balances.remove(id);
      _invalidateCache();
    } on DataSourceException catch (e) {
      throw RepositoryException(
        message: 'Error al eliminar cuenta: ${e.message}',
        originalError: e,
      );
    } on NotFoundException catch (e) {
      throw RepositoryException(
        message: 'Cuenta no encontrada para eliminar: ${e.message}',
        originalError: e,
      );
    }
  }

  @override
  Future<List<Account>> getAccountsByUser(String userId) async {
    try {
      final models = await _remoteDataSource.fetchAccountsByUserId(userId);
      return models.map((m) => m.toEntity()).toList();
    } on DataSourceException catch (e) {
      throw RepositoryException(
        message: 'Error al obtener cuentas del usuario: ${e.message}',
        originalError: e,
      );
    } on NetworkException catch (e) {
      throw RepositoryException(
        message: 'Error de red al obtener cuentas del usuario: ${e.message}',
        originalError: e,
      );
    }
  }

  @override
  Future<Balance?> getAccountBalance(String accountId) async {
    return _balances[accountId];
  }

  @override
  Future<Balance> updateAccountBalance(String accountId, Balance balance) async {
    _balances[accountId] = balance;
    return balance;
  }

  @override
  Future<List<Account>> getAccountsByType(String userId, AccountType type) async {
    final accounts = await getAccountsByUser(userId);
    return accounts.where((a) => a.type == type).toList();
  }

  @override
  Future<bool> accountExists(String accountId) async {
    return (await getAccountById(accountId)) != null;
  }

  @override
  Future<double> getTotalBalanceByUser(String userId) async {
    final accounts = await getAccountsByUser(userId);
    return accounts.fold<double>(
      0.0,
      (sum, a) => sum + (_balances[a.id]?.currentBalance ?? a.initialBalance),
    );
  }

  @override
  Future<void> transferBetweenAccounts(
    String fromAccountId,
    String toAccountId,
    double amount,
  ) async {
    final from = await getAccountById(fromAccountId);
    final to = await getAccountById(toAccountId);
    if (from == null || to == null) {
      throw RepositoryException(message: 'Cuenta de origen o destino no encontrada');
    }
    final fromBalance = _balances[fromAccountId]?.currentBalance ?? from.initialBalance;
    final toBalance = _balances[toAccountId]?.currentBalance ?? to.initialBalance;
    _balances[fromAccountId] = _balanceFor(from, fromBalance - amount);
    _balances[toAccountId] = _balanceFor(to, toBalance + amount);
  }

  Balance _balanceFor(Account account, double currentBalance) {
    return Balance(
      id: 'balance_${account.id}',
      accountId: account.id,
      currentBalance: currentBalance,
      date: DateTime.now(),
      income: 0,
      expenses: 0,
      currency: account.currency,
    );
  }

  @override
  Future<List<Account>> searchAccounts(String userId, String query) async {
    final accounts = await getAccountsByUser(userId);
    final lower = query.toLowerCase();
    return accounts.where((a) => a.name.toLowerCase().contains(lower)).toList();
  }

  @override
  Stream<Account> watchAccount(String accountId) async* {
    final account = await getAccountById(accountId);
    if (account != null) yield account;
  }

  @override
  Stream<List<Account>> watchAccountsByUser(String userId) async* {
    yield await getAccountsByUser(userId);
  }

  Future<void> invalidateCache() async {
    _invalidateCache();
  }

  void _invalidateCache() {
    _isCacheValid = false;
  }
}

class RepositoryException implements Exception {
  final String message;
  final Object? originalError;

  const RepositoryException({
    required this.message,
    this.originalError,
  });

  @override
  String toString() => 'RepositoryException: $message';
}

class DataSourceException implements Exception {
  final String message;
  final int? statusCode;

  const DataSourceException({required this.message, this.statusCode});

  @override
  String toString() => 'DataSourceException: $message (status: $statusCode)';
}

class NetworkException implements Exception {
  final String message;
  final int? statusCode;

  const NetworkException({required this.message, this.statusCode});

  @override
  String toString() => 'NetworkException: $message';
}

class ValidationException implements Exception {
  final String message;
  final Map<String, String>? fieldErrors;

  const ValidationException({required this.message, this.fieldErrors});

  @override
  String toString() => 'ValidationException: $message';
}

class NotFoundException implements Exception {
  final String message;
  final String? resourceId;

  const NotFoundException({required this.message, this.resourceId});

  @override
  String toString() => 'NotFoundException: $message';
}