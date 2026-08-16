import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localAuthServiceProvider = Provider((ref) => LocalAuthService());

class LocalAuthService {
  final _storage = const FlutterSecureStorage();
  static const _accountsKey = 'saved_accounts';

  Future<List<Map<String, dynamic>>> getSavedAccounts() async {
    final data = await _storage.read(key: _accountsKey);
    if (data == null || data.isEmpty) return [];
    
    try {
      final List<dynamic> decoded = jsonDecode(data);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveAccount({
    required String id,
    required String email,
    required String displayName,
    required String refreshToken,
    required String pin,
  }) async {
    final accounts = await getSavedAccounts();
    
    // Remove if already exists to update
    accounts.removeWhere((acc) => acc['id'] == id);
    
    accounts.add({
      'id': id,
      'email': email,
      'display_name': displayName,
      'refresh_token': refreshToken,
      'pin': pin,
    });
    
    await _storage.write(key: _accountsKey, value: jsonEncode(accounts));
  }

  Future<void> updateRefreshToken(String id, String newRefreshToken) async {
    final accounts = await getSavedAccounts();
    final index = accounts.indexWhere((acc) => acc['id'] == id);
    if (index != -1) {
      accounts[index]['refresh_token'] = newRefreshToken;
      await _storage.write(key: _accountsKey, value: jsonEncode(accounts));
    }
  }

  Future<void> removeAccount(String id) async {
    final accounts = await getSavedAccounts();
    accounts.removeWhere((acc) => acc['id'] == id);
    await _storage.write(key: _accountsKey, value: jsonEncode(accounts));
  }
}
