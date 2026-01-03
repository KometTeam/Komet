import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gwid/models/account.dart';
import 'package:gwid/models/profile.dart';
import 'package:uuid/uuid.dart';
import 'package:gwid/utils/fresh_mode_helper.dart';

class AccountManager {
  static final AccountManager _instance = AccountManager._internal();
  factory AccountManager() => _instance;
  AccountManager._internal();

  static const String _accountsKey = 'multi_accounts';
  static const String _currentAccountIdKey = 'current_account_id';

  Account? _currentAccount;
  List<Account> _accounts = [];

  Account? get currentAccount => _currentAccount;
  List<Account> get accounts => List.unmodifiable(_accounts);

  Future<void> initialize() async {
    await _loadAccounts();
    await _loadCurrentAccount();
  }

  Future<void> _loadAccounts() async {
    if (FreshModeHelper.shouldSkipLoad()) {
      _accounts = [];
      return;
    }
    try {
      final prefs = await FreshModeHelper.getSharedPreferences();
      final accountsJson = prefs.getString(_accountsKey);
      if (accountsJson != null) {
        final List<dynamic> accountsList = jsonDecode(accountsJson);
        _accounts = accountsList
            .map((json) => Account.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('Ошибка загрузки аккаунтов: $e');
      _accounts = [];
    }
  }

  Future<void> _loadCurrentAccount() async {
    if (FreshModeHelper.shouldSkipLoad()) {
      _currentAccount = null;
      return;
    }
    try {
      final prefs = await FreshModeHelper.getSharedPreferences();
      final currentAccountId = prefs.getString(_currentAccountIdKey);

      if (currentAccountId != null) {
        _currentAccount = _accounts.firstWhere(
          (account) => account.id == currentAccountId,
          orElse: () => _accounts.isNotEmpty
              ? _accounts.first
              : Account(id: '', token: '', createdAt: DateTime.now()),
        );
      } else if (_accounts.isNotEmpty) {
        _currentAccount = _accounts.first;
        await _saveCurrentAccountId(_currentAccount!.id);
      }
    } catch (e) {
      print('Ошибка загрузки текущего аккаунта: $e');
      if (_accounts.isNotEmpty) {
        _currentAccount = _accounts.first;
      }
    }
  }

  Future<void> _saveAccounts() async {
    if (FreshModeHelper.shouldSkipSave()) return;
    try {
      final prefs = await FreshModeHelper.getSharedPreferences();
      final accountsJson = jsonEncode(
        _accounts.map((account) => account.toJson()).toList(),
      );
      await prefs.setString(_accountsKey, accountsJson);
    } catch (e) {
      print('Ошибка сохранения аккаунтов: $e');
    }
  }

  Future<void> _saveCurrentAccountId(String accountId) async {
    if (FreshModeHelper.shouldSkipSave()) return;
    try {
      final prefs = await FreshModeHelper.getSharedPreferences();
      await prefs.setString(_currentAccountIdKey, accountId);
    } catch (e) {
      print('Ошибка сохранения текущего аккаунта: $e');
    }
  }

  Future<Account> addAccount({
    required String token,
    String? userId,
    Profile? profile,
  }) async {
    final account = Account(
      id: const Uuid().v4(),
      token: token,
      userId: userId,
      profile: profile,
      createdAt: DateTime.now(),
      lastUsedAt: DateTime.now(),
    );

    final existingIndex = _accounts.indexWhere((acc) => acc.token == token);
    if (existingIndex != -1) {
      _accounts[existingIndex] = account.copyWith(
        id: _accounts[existingIndex].id,
      );
    } else {
      _accounts.add(account);
    }

    await _saveAccounts();
    return account;
  }

  Future<void> switchAccount(String accountId) async {
    // Не падаем, если аккаунт пропал: берем найденный, первый или создаем заглушку.
    Account? account;
    final idx = _accounts.indexWhere((acc) => acc.id == accountId);
    if (idx != -1) {
      account = _accounts[idx];
    } else if (_accounts.isNotEmpty) {
      account = _accounts.first;
    }

    if (account == null) {
      final fallback = Account(
        id: accountId,
        token: '',
        createdAt: DateTime.now(),
        lastUsedAt: DateTime.now(),
      );
      _accounts.add(fallback);
      _currentAccount = fallback;
      await _saveAccounts();
      await _saveCurrentAccountId(fallback.id);
      return;
    }

    final resolved =
        account; // account гарантированно не null после возврата выше

    _currentAccount = resolved;
    await _saveCurrentAccountId(resolved.id);

    final index = _accounts.indexWhere((acc) => acc.id == resolved.id);
    if (index == -1) {
      // Если почему-то нет в списке, добавим актуальный экземпляр
      _accounts.add(resolved.copyWith(lastUsedAt: DateTime.now()));
    } else {
      _accounts[index] = _accounts[index].copyWith(lastUsedAt: DateTime.now());
    }

    await _saveAccounts();
  }

  Future<void> updateAccountProfile(String accountId, Profile profile) async {
    final index = _accounts.indexWhere((acc) => acc.id == accountId);
    if (index != -1) {
      _accounts[index] = _accounts[index].copyWith(profile: profile);
      await _saveAccounts();

      if (_currentAccount?.id == accountId) {
        _currentAccount = _accounts[index];
      }
    }
  }

  Future<void> removeAccount(String accountId) async {
    if (_accounts.length <= 1) {
      throw Exception('Нельзя удалить последний аккаунт');
    }

    _accounts.removeWhere((acc) => acc.id == accountId);

    if (_currentAccount?.id == accountId) {
      _currentAccount = _accounts.isNotEmpty ? _accounts.first : null;
      if (_currentAccount != null) {
        await _saveCurrentAccountId(_currentAccount!.id);
      }
    }

    await _saveAccounts();
  }

  Future<void> migrateOldAccount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final oldToken = prefs.getString('authToken');
      final oldUserId = prefs.getString('userId');

      if (oldToken != null && _accounts.isEmpty) {
        await addAccount(token: oldToken, userId: oldUserId);
        print('Старый аккаунт мигрирован в мультиаккаунтинг');
      }
    } catch (e) {
      print('Ошибка миграции старого аккаунта: $e');
    }
  }
}
