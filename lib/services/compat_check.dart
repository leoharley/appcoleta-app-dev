import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'pwa_install/pwa_install.dart';

/// Compatibilidade com os aparelhos de campo (Prompt 20, itens 3 e 4).
///
/// Ao abrir, confere a versão do Android e do Chrome (pelo que o navegador
/// informa). Se estiver abaixo do mínimo, explica em português simples o que
/// fazer — sem travar nem fechar o app. Também oferece o passo a passo para
/// tirar o app da economia de bateria, que em alguns aparelhos (Motorola,
/// Samsung, Xiaomi) corta a gravação e o envio.
class CompatCheck {
  static const int minAndroid = 9;
  static const int minChrome = 110;
  static bool _shown = false;

  static int? _major(String? v) => v == null ? null : int.tryParse(v.split('.').first.trim());

  /// Lê "modelo=...;plataforma=Android;versao=13.0.0;chrome=120.0..." (client hints do Chrome).
  static Map<String, String> _parse(String s) {
    final out = <String, String>{};
    for (final part in s.split(';')) {
      final i = part.indexOf('=');
      if (i > 0) out[part.substring(0, i)] = part.substring(i + 1);
    }
    return out;
  }

  static Future<void> showIfNeeded(BuildContext context) async {
    if (_shown || !kIsWeb) return;
    // Os dados do aparelho chegam alguns segundos depois de abrir.
    await Future.delayed(const Duration(seconds: 4));
    final info = _parse(PwaInstall.aparelho);
    if (info.isEmpty) return;
    final problemas = <String>[];
    final android = (info['plataforma'] ?? '').toLowerCase() == 'android' ? _major(info['versao']) : null;
    final chrome = _major(info['chrome']);
    if (android != null && android > 0 && android < minAndroid) {
      problemas.add('Este celular está com Android $android. O app precisa do Android $minAndroid ou mais novo para gravar e enviar sem falhas.');
    }
    if (chrome != null && chrome > 0 && chrome < minChrome) {
      problemas.add('O Chrome deste celular está na versão $chrome. Atualize o Chrome pela Play Store (precisa ser $minChrome ou mais nova).');
    }
    if (problemas.isEmpty || !context.mounted) return;
    _shown = true;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Atenção com este aparelho'),
        content: Text('${problemas.join('\n\n')}\n\nVocê pode continuar, mas avise a coordenação: há risco de perder gravação ou envio.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BatteryGuideScreen()));
            },
            child: const Text('Ver cuidados com a bateria'),
          ),
          ElevatedButton(onPressed: () => Navigator.pop(c), child: const Text('Entendi')),
        ],
      ),
    );
  }
}

/// Passo a passo, por marca, para o sistema não fechar o app no meio da
/// entrevista (economia de bateria).
class BatteryGuideScreen extends StatelessWidget {
  const BatteryGuideScreen({super.key});

  static const _guias = <String, List<String>>{
    'Motorola': [
      'Abra Configurações > Apps > Chrome (ou Coleta Alves Lima).',
      'Toque em Bateria e escolha "Sem restrições".',
      'Em Configurações > Bateria, desligue a "Bateria adaptável" durante o campo.',
    ],
    'Samsung': [
      'Abra Configurações > Aplicativos > Chrome (ou Coleta Alves Lima) > Bateria.',
      'Escolha "Irrestrito".',
      'Em Configurações > Assistência do aparelho e bateria > Bateria > Limites de uso em segundo plano, tire o app de "Apps em suspensão" e "Apps em suspensão profunda".',
    ],
    'Xiaomi / Redmi / Poco': [
      'Abra Configurações > Apps > Gerenciar apps > Chrome (ou Coleta Alves Lima).',
      'Toque em Economia de bateria e escolha "Sem restrições".',
      'Ligue "Inicialização automática" para o app.',
      'Na tela de apps recentes, segure o app e toque no cadeado para ele não ser fechado.',
    ],
    'Outros aparelhos': [
      'Procure em Configurações por "Bateria" e depois "Otimização de bateria".',
      'Escolha "Todos os apps", encontre o Chrome (ou o app) e marque "Não otimizar".',
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cuidados com a bateria')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Alguns celulares fecham apps "parados" para economizar bateria. Durante a entrevista isso pode cortar a gravação ou o envio. Faça estes passos uma vez no seu aparelho:',
            style: TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 12),
          for (final e in _guias.entries)
            Card(
              child: ExpansionTile(
                title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                children: [
                  for (var i = 0; i < e.value.length; i++)
                    ListTile(dense: true, leading: CircleAvatar(radius: 12, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))), title: Text(e.value[i])),
                ],
              ),
            ),
          const SizedBox(height: 8),
          const Text('Durante a entrevista, mantenha a tela do app aberta: o app já impede a tela de apagar.', style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
