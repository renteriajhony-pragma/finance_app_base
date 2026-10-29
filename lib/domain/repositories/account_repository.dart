import '../entities/account.dart';
import '../entities/balance.dart';

abstract class AccountRepository {
  Future<List<Account>> getAccounts();

  Future<Account?> getAccount(String id);

  Future<List<Account>> getAccountsByUser(String userId);

  Future<Account?> getAccountById(String id);

  Future<Account> createAccount(Account account);

  Future<Account> updateAccount(Account account);

  Future<void> deleteAccount(String id);

  Future<Balance?> getAccountBalance(String accountId);

  Future<Balance> updateAccountBalance(String accountId, Balance balance);

  Future<List<Account>> getAccountsByType(String userId, AccountType type);

  Future<bool> accountExists(String accountId);

  Future<double> getTotalBalanceByUser(String userId);

  Future<void> transferBetweenAccounts(
    String fromAccountId,
    String toAccountId,
    double amount,
  );

  Future<List<Account>> searchAccounts(String userId, String query);

  Stream<Account> watchAccount(String accountId);

  Stream<List<Account>> watchAccountsByUser(String userId);
}