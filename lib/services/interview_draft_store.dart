import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Entrevista em andamento guardada no aparelho a cada resposta (Prompt 5).
///
/// Se o app fecha, o celular desliga ou a bateria acaba no meio da
/// entrevista, ao reabrir o app oferece retomar do ponto em que parou.
///
/// Android/iPhone: guardado criptografado pelo sistema (Keystore/Keychain,
/// via flutter_secure_storage). Navegador: o flutter_secure_storage cifra com
/// WebCrypto; se não estiver disponível, cai no armazenamento local comum.
/// O rascunho é apagado quando a entrevista é concluída (vai para a fila de
/// envio) ou descartada pelo entrevistador.
class InterviewDraftStore {
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static String _key(int userId) => 'entrevista_em_andamento_$userId';

  static Future<void> save(int userId, Map<String, dynamic> data) async {
    final value = jsonEncode(data);
    try {
      await _secure.write(key: _key(userId), value: value);
      return;
    } catch (e) {
      debugPrint('Rascunho: armazenamento seguro indisponível ($e)');
    }
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(userId), value);
    }
  }

  static Future<Map<String, dynamic>?> load(int userId) async {
    String? value;
    try {
      value = await _secure.read(key: _key(userId));
    } catch (_) {}
    if (value == null && kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      value = prefs.getString(_key(userId));
    }
    if (value == null || value.isEmpty) return null;
    try {
      final d = jsonDecode(value);
      return d is Map ? Map<String, dynamic>.from(d) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(int userId) async {
    try {
      await _secure.delete(key: _key(userId));
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(userId));
    } catch (_) {}
  }
}
