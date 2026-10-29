import 'package:finance_app/data/datasources/finance_seed_data.dart';
import 'package:finance_app/data/datasources/remote_account_datasource.dart';
import 'package:finance_app/data/models/account_model.dart';
import 'package:finance_app/domain/entities/account.dart';

/// Implementación en memoria de [RemoteAccountDataSource] para usar mientras
/// la API real no está disponible. Reproduce el contrato y las excepciones de
/// [RemoteAccountDataSourceImpl].
class MockRemoteAccountDataSource implements RemoteAccountDataSource {
  final Map<String, AccountModel> _accounts;
  final Duration _latency;

  MockRemoteAccountDataSource({
    List<AccountModel>? initialAccounts,
    Duration latency = const Duration(milliseconds: 300),
  })  : _accounts = {
          for (final account in initialAccounts ?? FinanceSeedData.accounts)
            account.id: account,
        },
        _latency = latency;

  @override
  Future<List<AccountModel>> fetchAccounts() async {
    await _simulateLatency();
    return _accounts.values.toList();
  }

  @override
  Future<AccountModel?> fetchAccountById(String id) async {
    await _simulateLatency();
    return _accounts[id];
  }

  @override
  Future<AccountModel> createAccount(Account account) async {
    await _simulateLatency();
    _validate(account);

    if (_accounts.containsKey(account.id)) {
      throw const ValidationException(
        message: 'Datos inválidos',
        fieldErrors: {'id': 'Ya existe una cuenta con este id'},
      );
    }

    final created = AccountModel.fromEntity(account);
    _accounts[created.id] = created;
    return created;
  }

  @override
  Future<AccountModel> updateAccount(Account account) async {
    await _simulateLatency();

    if (!_accounts.containsKey(account.id)) {
      throw NotFoundException(
        message: 'Recurso no encontrado',
        resourceId: account.id,
      );
    }
    _validate(account);

    final updated = AccountModel.fromEntity(account).copyWith(
      updatedAt: DateTime.now(),
    );
    _accounts[updated.id] = updated;
    return updated;
  }

  @override
  Future<void> deleteAccount(String id) async {
    await _simulateLatency();

    if (_accounts.remove(id) == null) {
      throw NotFoundException(
        message: 'Cuenta no encontrada',
        resourceId: id,
      );
    }
  }

  @override
  Future<List<AccountModel>> fetchAccountsByUserId(String userId) async {
    await _simulateLatency();
    return _accounts.values.where((a) => a.userId == userId).toList();
  }

  Future<void> _simulateLatency() async {
    if (_latency > Duration.zero) {
      await Future<void>.delayed(_latency);
    }
  }

  void _validate(Account account) {
    final errors = <String, String>{
      if (account.name.trim().isEmpty) 'name': 'El nombre es obligatorio',
      if (account.userId.trim().isEmpty) 'user_id': 'El usuario es obligatorio',
      if (!account.isValidInitialBalance())
        'initial_balance': 'El saldo inicial no puede ser negativo',
    };

    if (errors.isNotEmpty) {
      throw ValidationException(message: 'Datos inválidos', fieldErrors: errors);
    }
  }
}
