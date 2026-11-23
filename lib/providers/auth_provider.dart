import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  bool _isInitialized = false; // Para controlar se já verificou o status

  /// O servidor já recusou este token, mas a sessão local foi mantida para
  /// não bloquear o acesso ao que ainda não subiu.
  ///
  /// Existe porque a expiração era silenciosa: o app verificava o token na
  /// abertura, ouvia do servidor que tinha vencido e guardava a informação
  /// para si. O aplicador seguia coletando o dia inteiro e só descobria ao
  /// tentar sincronizar — quando descobria.
  bool _sessaoRejeitadaPeloServidor = false;

  User? get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get hasUser => _user != null;
  bool get isInitialized => _isInitialized;
  String? get userToken => null;
  bool get sessaoRejeitadaPeloServidor => _sessaoRejeitadaPeloServidor;

  /// Registra que o servidor recusou a sessão. Chamado na verificação de
  /// abertura e também quando uma sincronização volta com 401 — é comum a
  /// sessão vencer com o app já aberto.
  void marcarSessaoExpirada() {
    if (_sessaoRejeitadaPeloServidor) return;
    _sessaoRejeitadaPeloServidor = true;
    if (kDebugMode) {
      print('⚠️ Sessão marcada como expirada no servidor');
    }
    notifyListeners();
  }

  /// Verifica se o app foi atualizado e força logout se necessário
  Future<bool> _checkAppVersionAndForceLogoutIfUpdated() async {
    print('🔍 ========================================');
    print('🔍 INICIANDO VERIFICAÇÃO DE VERSÃO DO APP');
    print('🔍 ========================================');

    try {
      final prefs = await SharedPreferences.getInstance();

      print('📦 Obtendo informações do pacote...');
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();

      // Versão completa: version+buildNumber (ex: 1.0.0+1)
      final String currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      final String? savedVersion = prefs.getString('app_version');

      print('🔍 === VERIFICANDO VERSÃO DO APP ===');
      print('📱 Versão atual do APK: $currentVersion');
      print('📱 packageInfo.version: ${packageInfo.version}');
      print('📱 packageInfo.buildNumber: ${packageInfo.buildNumber}');
      print('💾 Versão salva em SharedPreferences: $savedVersion');
      print('🔍 ========================================');

      if (savedVersion == null) {
        // Primeira instalação - salvar versão atual
        print('⚠️ PRIMEIRA INSTALAÇÃO DETECTADA');
        print('💾 Salvando versão atual: $currentVersion');
        await prefs.setString('app_version', currentVersion);
        print('✅ Versão salva com sucesso');
        return false; // Não houve atualização
      }

      print('🔍 Comparando versões...');
      print('   Salva: "$savedVersion"');
      print('   Atual: "$currentVersion"');
      print('   São iguais? ${savedVersion == currentVersion}');

      if (savedVersion != currentVersion) {
        // APP FOI ATUALIZADO - Forçar logout
        print('🆕 ========================================');
        print('🆕 === APP ATUALIZADO DETECTADO!!! ===');
        print('🆕 ========================================');
        print('📱 Versão anterior: $savedVersion');
        print('📱 Nova versão: $currentVersion');
        print('🚪 Forçando logout por segurança...');
        print('🆕 ========================================');

        // Fazer logout completo (limpar token)
        print('🧹 Removendo auth_token...');
        await prefs.remove('auth_token');
        print('🧹 Removendo login_timestamp...');
        await prefs.remove('login_timestamp');

        // Atualizar versão salva
        print('💾 Atualizando versão salva para: $currentVersion');
        await prefs.setString('app_version', currentVersion);

        // Verificar se salvou
        final String? verificacao = prefs.getString('app_version');
        print('✅ Verificação: versão salva agora é: $verificacao');

        // Resetar estado de autenticação
        _isAuthenticated = false;
        _user = null;

        print('✅ Logout forçado concluído!');
        print('🆕 ========================================');

        return true; // Houve atualização e logout
      }

      print('✅ Mesma versão - sem necessidade de logout');
      return false; // Não houve atualização

    } catch (e, stackTrace) {
      print('❌ ========================================');
      print('❌ ERRO ao verificar versão do app: $e');
      print('📋 Stack trace: $stackTrace');
      print('❌ ========================================');
      return false;
    }
  }

  /// Mensagem do servidor (ou do app) sobre a última tentativa de login.
  String? _loginMensagem;
  String? get loginMensagem => _loginMensagem;

  /// Login sempre pelo servidor. Não existe mais login sem internet com senha
  /// guardada no aparelho (a senha ficava em texto aberto no navegador): sem
  /// sinal, quem já está logado continua usando o app normalmente, porque a
  /// sessão (token com validade) fica no aparelho até a pessoa tocar em Sair.
  Future<LoginResultado> login(String username, String password,
      {String? code}) async {
    _isLoading = true;
    _loginMensagem = null;
    notifyListeners();

    try {
      Map<String, dynamic> response;
      try {
        response = await ApiService.login(username, password, code: code);
      } on SemConexaoException {
        _loginMensagem = 'Sem conexão com o servidor. Para entrar é preciso '
            'internet; depois o app funciona sem sinal até você tocar em Sair.';
        return LoginResultado.semConexao;
      }

      if (response['success'] != true) {
        _loginMensagem = response['message']?.toString();
        switch (response['code']) {
          case 'TWO_FACTOR_REQUIRED':
            return LoginResultado.codigoNecessario;
          case 'TWO_FACTOR_INVALID':
            return LoginResultado.codigoInvalido;
          case 'PASSWORD_CHANGE_REQUIRED':
            return LoginResultado.trocaDeSenha;
          case 'TWO_FACTOR_SETUP_REQUIRED':
            return LoginResultado.ativarVerificacao;
          case 'LOCKED':
            return LoginResultado.bloqueado;
        }
        _loginMensagem ??= 'Usuário ou senha incorretos.';
        return response['statusCode'] == 401
            ? LoginResultado.credenciaisInvalidas
            : LoginResultado.erro;
      }

      _isAuthenticated = true;
      if (response['user'] != null) {
        try {
          _user = User.fromJson(response['user']);
        } catch (_) {
          _user = null;
        }
      }
      await _saveAuthData(response);
      await _apagarCredenciaisAntigas();
      notifyListeners();
      return LoginResultado.sucesso;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erro inesperado no login: $e');
      }
      _loginMensagem = 'Erro inesperado ao entrar. Tente de novo.';
      return LoginResultado.erro;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Troca de senha obrigatória feita pelo app. Devolve null se deu certo, ou
  /// a mensagem do problema (senha fraca, senha atual errada, sem conexão).
  Future<String?> trocarSenha(
      String username, String senhaAtual, String novaSenha) async {
    try {
      final r = await ApiService.changePassword(username, senhaAtual, novaSenha);
      if (r['success'] == true) return null;
      return r['message']?.toString() ?? 'Não foi possível trocar a senha.';
    } on SemConexaoException {
      return 'Sem conexão com o servidor. Tente de novo com internet.';
    }
  }

  /// Versões anteriores guardavam usuário e SENHA em texto aberto no aparelho
  /// (flutter.offline_username / flutter.offline_password) para o login sem
  /// internet. Apaga o que tiver ficado.
  Future<void> _apagarCredenciaisAntigas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('offline_password');
      await prefs.remove('offline_username');
    } catch (_) {}
  }

  // Método privado para salvar dados de autenticação
  Future<void> _saveAuthData(Map<String, dynamic> response) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Salvar token
      if (response.containsKey('token') && response['token'] != null) {
        await prefs.setString('auth_token', response['token']);
        // Token novo em folha: o alerta de sessão vencida deixa de valer.
        _sessaoRejeitadaPeloServidor = false;
        if (kDebugMode) {
          print('Token saved: ${response['token'].toString().substring(0, 10)}...');
        }
      }

      // Salvar dados do usuário como JSON string para recuperação offline
      if (_user != null) {
        await prefs.setInt('user_id', _user!.id);
        final userJsonString = '${_user!.toJson()}';
        await prefs.setString('user_data', userJsonString);
        await prefs.setString('user_full_name', _user!.fullName);
        await prefs.setString('user_username', _user!.username);
        await prefs.setString('user_email', _user!.email);
        await prefs.setString('user_role', _user!.role);
        await prefs.setBool('user_is_active', _user!.isActive);
        if (kDebugMode) {
          print('User data saved: ${_user!.fullName} (${_user!.username})');
        }
      }

      // Salvar timestamp do login
      await prefs.setInt('login_timestamp', DateTime.now().millisecondsSinceEpoch);

      if (kDebugMode) {
        print('Auth data saved successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving auth data: $e');
      }
    }
  }

  void setUser(dynamic userData) {
    if (userData != null) {
      try {
        if (userData is User) {
          _user = userData;
        } else if (userData is Map<String, dynamic>) {
          _user = User.fromJson(userData);
        } else {
          throw Exception('Invalid user data type: ${userData.runtimeType}');
        }
        
        _isAuthenticated = true;
        
        if (kDebugMode) {
          print('User set successfully: ${_user?.id}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error setting user: $e');
        }
        _user = null;
        _isAuthenticated = false;
      }
    } else {
      _user = null;
      _isAuthenticated = false;
    }
    
    notifyListeners();
  }

  void clearUser() {
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
    
    if (kDebugMode) {
      print('User cleared');
    }
  }

  Future<void> saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      
      if (_user != null) {
        await prefs.setInt('user_id', _user!.id);
      }
      
      if (kDebugMode) {
        print('Token saved: ${token.substring(0, 10)}...');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving token: $e');
      }
    }
  }

  void updateUserData(Map<String, dynamic> updates) {
    if (_user != null) {
      try {
        final currentData = _user!.toJson();
        currentData.addAll(updates);
        _user = User.fromJson(currentData);
        
        // Atualizar dados salvos
        _saveUpdatedUserData();
        
        notifyListeners();
        
        if (kDebugMode) {
          print('User data updated: $updates');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error updating user data: $e');
        }
      }
    }
  }

  // Método para salvar dados atualizados do usuário
  Future<void> _saveUpdatedUserData() async {
    if (_user != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', _user!.toJson().toString());
        await prefs.setInt('user_id', _user!.id);
        await prefs.setString('user_full_name', _user!.fullName);
        await prefs.setString('user_username', _user!.username);
        await prefs.setString('user_email', _user!.email);
        await prefs.setString('user_role', _user!.role);
        await prefs.setBool('user_is_active', _user!.isActive);
      } catch (e) {
        if (kDebugMode) {
          print('Error saving updated user data: $e');
        }
      }
    }
  }

  /// Coletas deste usuário que ainda não subiram (para avisar antes de sair).
  Future<int> coletasPendentesDoUsuario() async {
    final id = _user?.id;
    if (id == null) return 0;
    try {
      return await LocalStorageService.countPendingFormsOf(id);
    } catch (_) {
      return 0;
    }
  }

  /// Sair: encerra a sessão e apaga do aparelho o que identifica a pessoa —
  /// token, dados do usuário, metas individuais em cache e as entrevistas JÁ
  /// confirmadas pelo painel. Entrevistas ainda não enviadas FICAM no aparelho
  /// e sobem quando o mesmo aplicador entrar de novo (a sincronização só envia
  /// as coletas de quem está logado).
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final chave in const [
        'auth_token',
        'login_timestamp',
        'user_id',
        'user_data',
        'user_full_name',
        'user_username',
        'user_email',
        'user_role',
        'user_is_active',
        'offline_username',
        'offline_password',
        'cached_history',
        // Questionários atribuídos a quem saiu: o próximo usuário recebe os
        // dele do servidor (LocalStorageService também confere o dono).
        'questionnaires',
        'questionnaires_owner',
      ]) {
        await prefs.remove(chave);
      }

      // Metas individuais de quem estava logado: o próximo aplicador do
      // aparelho não pode vê-las como "Suas metas".
      await LocalStorageService.clearStratifications();
      await LocalStorageService.removeSyncedFormResponses();

      _user = null;
      _isAuthenticated = false;
      _sessaoRejeitadaPeloServidor = false;
    } catch (e) {
      if (kDebugMode) {
        print('Error during logout: $e');
      }
    }

    notifyListeners();
  }

  // Verificar status de autenticação - chamado na inicialização do app
  Future<void> checkAuthStatus() async {
    if (kDebugMode) {
      print('Checking authentication status...');
    }

    try {
      // A senha guardada por versões antigas sai do aparelho logo na abertura.
      await _apagarCredenciaisAntigas();

      // PRIMEIRO: Verificar se o app foi atualizado e forçar logout se necessário
      final bool wasUpdated = await _checkAppVersionAndForceLogoutIfUpdated();

      if (wasUpdated) {
        // App foi atualizado e logout foi forçado
        _isAuthenticated = false;
        _user = null;
        _isInitialized = true;
        notifyListeners();

        if (kDebugMode) {
          print('🆕 App atualizado - usuário deslogado automaticamente');
        }
        return; // Encerra aqui, usuário precisa fazer login novamente
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userId = prefs.getInt('user_id');

      if (token != null && userId != null) {
        if (kDebugMode) {
          print('Found saved token and user ID');
        }
        
        // Tentar carregar dados do usuário salvos localmente primeiro
        await _loadSavedUserData(prefs, userId);
        
        // Verificar token com servidor (opcional - só se houver conexão)
        await _verifyTokenWithServer(token, prefs);
      } else {
        if (kDebugMode) {
          print('No saved authentication data found');
        }
        _isAuthenticated = false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking auth status: $e');
      }
      // Em caso de erro, mantém o usuário logado se há dados locais
      // Não faz logout automático por erro de rede
    }
    
    _isInitialized = true;
    notifyListeners();
  }

  // Carregar dados do usuário salvos localmente
  Future<void> _loadSavedUserData(SharedPreferences prefs, int userId) async {
    try {
      // Tentar restaurar o usuário a partir dos dados salvos individualmente
      final fullName = prefs.getString('user_full_name');
      final username = prefs.getString('user_username');
      final email = prefs.getString('user_email');
      final role = prefs.getString('user_role');
      final isActive = prefs.getBool('user_is_active');

      if (fullName != null && username != null && email != null && role != null) {
        // Criar objeto User com os dados salvos
        _user = User(
          id: userId,
          fullName: fullName,
          username: username,
          email: email,
          role: role,
          isActive: isActive ?? true, // Default para true se não encontrado
        );
        _isAuthenticated = true;

        if (kDebugMode) {
          print('✅ User restored from saved data: ${_user!.fullName} (${_user!.username})');
        }
      } else {
        if (kDebugMode) {
          print('⚠️ Incomplete user data in storage');
        }
        _isAuthenticated = false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading saved user data: $e');
      }
      _isAuthenticated = false;
    }
  }

  // Verificar token com servidor (não obrigatório)
  Future<void> _verifyTokenWithServer(String token, SharedPreferences prefs) async {
    try {
      final response = await ApiService.verifyToken(token);

      if (response.containsKey('success') && response['success'] == true) {
        if (kDebugMode) {
          print('✅ Token verificado com sucesso no servidor');
        }

        // Renovação deslizante: se o servidor devolver um token novo nesta
        // verificação, ele substitui o atual e o prazo recomeça. Assim o
        // aplicador que abre o app de tempos em tempos nunca chega a expirar,
        // em vez de depender só do prazo fixo do backend.
        //
        // Antes esse campo era ignorado — se o servidor já mandasse um token
        // renovado, ele era jogado fora e a expiração vinha do mesmo jeito.
        final novoToken = response['token'];
        if (novoToken is String && novoToken.isNotEmpty) {
          await prefs.setString('auth_token', novoToken);
          if (kDebugMode) {
            print('🔄 Token renovado pelo servidor');
          }
        }

        // Atualizar dados do usuário se disponível
        if (response.containsKey('user') && response['user'] != null) {
          _user = User.fromJson(response['user']);
          await _saveUpdatedUserData();
        }

        _isAuthenticated = true;
        // O servidor aceitou: qualquer alerta anterior de sessão vencida
        // deixa de valer.
        _sessaoRejeitadaPeloServidor = false;
      } else {
        // Token inválido no servidor - NÃO fazer logout automático
        // O usuário só perde a sessão ao clicar em "Sair"
        if (kDebugMode) {
          print('⚠️ Token inválido no servidor, mas mantendo sessão offline');
          print('⚠️ Usuário permanece logado até fazer logout manual');
        }
        // Mantém autenticado com dados locais — derrubar aqui faria o
        // aplicador perder o acesso ao que ainda não sincronizou.
        _isAuthenticated = true;

        // Mas o app para de guardar isso só para si: a interface avisa, e o
        // aplicador refaz o login antes de acumular um dia de trabalho que
        // não vai subir.
        marcarSessaoExpirada();
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Erro ao verificar token com servidor: $e');
        print('✅ Mantendo usuário logado com dados locais (modo offline)');
      }
      // Em caso de erro de rede, manter usuário logado
      // Não fazer logout automático
      if (_isAuthenticated) {
        if (kDebugMode) {
          print('✅ Sessão mantida mesmo sem conexão com servidor');
        }
      }
    }
  }

  // Método para forçar re-verificação do token (opcional)
  Future<bool> refreshAuthStatus() async {
    if (!_isAuthenticated) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token != null) {
        final response = await ApiService.verifyToken(token);

        if (response.containsKey('success') && response['success'] == true) {
          return true;
        } else {
          await logout();
          return false;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error refreshing auth status: $e');
      }
      // Manter logado em caso de erro de rede
      return true;
    }

    return false;
  }

}

/// Resultado do login (cada um leva a uma tela ou mensagem diferente).
enum LoginResultado {
  sucesso,
  credenciaisInvalidas,
  codigoNecessario,
  codigoInvalido,
  trocaDeSenha,
  ativarVerificacao,
  bloqueado,
  semConexao,
  erro,
}
