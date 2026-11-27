import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'pwa_install/pwa_install.dart';

/// Registro automático de erros em campo (Prompt 20, item 7).
///
/// Guarda no aparelho (até 30) e envia ao painel quando houver sinal:
/// aparelho, versão do app, tela e a mensagem do erro. Nunca envia dado do
/// entrevistado — só o erro técnico.
class ErrorReporter {
  static const _key = 'erros_pendentes';
  static String currentScreen = '';

  static void install() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      record(details.exceptionAsString(), details.stack);
      if (previous != null) previous(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      record(error.toString(), stack);
      return false;
    };
  }

  static Future<void> record(String message, StackTrace? stack) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key) ?? <String>[];
      String version = '';
      try {
        final info = await PackageInfo.fromPlatform();
        version = '${info.version}+${info.buildNumber}';
      } catch (_) {}
      list.add(jsonEncode({
        'at': DateTime.now().toIso8601String(),
        'app_version': version,
        'device': PwaInstall.aparelho.isNotEmpty ? PwaInstall.aparelho : defaultTargetPlatform.name,
        'screen': currentScreen,
        'message': message.length > 1500 ? message.substring(0, 1500) : message,
        'stack': (stack?.toString() ?? '').split('\n').take(25).join('\n'),
      }));
      while (list.length > 30) {
        list.removeAt(0);
      }
      await prefs.setStringList(_key, list);
    } catch (_) {}
  }

  /// Envia os erros guardados. Chamado na sincronização e ao abrir o app.
  static Future<void> flush() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key) ?? <String>[];
      if (list.isEmpty) return;
      final token = prefs.getString('auth_token');
      final r = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/system/error_report'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'errors': list.map((e) => jsonDecode(e)).toList()}),
          )
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) await prefs.remove(_key);
    } catch (_) {
      // Sem sinal: tenta de novo na próxima vez.
    }
  }
}
