import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/local_storage_service.dart';
import '../models/form_response.dart';

class SyncStatusCard extends StatefulWidget {
  const SyncStatusCard({super.key});

  @override
  State<SyncStatusCard> createState() => _SyncStatusCardState();
}

class _SyncStatusCardState extends State<SyncStatusCard> {
  ConnectivityResult _connectionStatus = ConnectivityResult.none;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isOnline = false;
  int _pendentes = 0;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadPendentes();
  }

  Future<List<FormResponse>> _pendentesList() async {
    final all = await LocalStorageService.getFormResponses();
    return all.where((f) => f.syncStatus != 'synced').toList();
  }

  Future<void> _loadPendentes() async {
    try {
      final l = await _pendentesList();
      if (mounted) setState(() => _pendentes = l.length);
    } catch (_) {}
  }

  /// Entrevistas que ainda não chegaram ao painel e o motivo da última falha (Prompt 5).
  Future<void> _showPendentes() async {
    final l = await _pendentesList();
    if (!mounted) return;
    setState(() => _pendentes = l.length);
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: l.isEmpty
            ? const Padding(padding: EdgeInsets.all(24), child: Text('Nenhuma entrevista esperando envio.'))
            : ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('${l.length} entrevista(s) ainda não confirmada(s) pelo painel. Elas estão guardadas no aparelho.',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  for (final f in l)
                    ListTile(
                      leading: Icon(f.syncStatus == 'error' ? Icons.error : Icons.schedule,
                          color: f.syncStatus == 'error' ? Colors.red : Colors.orange),
                      title: Text('Entrevista de ${f.completedAt != null ? '${f.completedAt!.day.toString().padLeft(2, '0')}/${f.completedAt!.month.toString().padLeft(2, '0')} ${f.completedAt!.hour.toString().padLeft(2, '0')}:${f.completedAt!.minute.toString().padLeft(2, '0')}' : 'data desconhecida'}'),
                      subtitle: Text(f.meta['ultimo_erro']?.toString() ??
                          (f.syncStatus == 'error' ? 'O servidor recusou. Avise a coordenação.' : 'Ainda não enviada (sem sinal ou aguardando sincronizar).')),
                    ),
                ],
              ),
      ),
    );
  }

  @override
  void dispose() {
    // IMPORTANTE: Cancelar subscription antes do dispose
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    try {
      final connectivity = Connectivity();
      
      // Verificar status inicial
      final result = await connectivity.checkConnectivity();
      
      // CORREÇÃO: Verificar se widget ainda está montado antes de setState
      if (mounted) {
        setState(() {
          _connectionStatus = result;
          _isOnline = result != ConnectivityResult.none;
        });
      }
      
      // Escutar mudanças de conectividade
      _connectivitySubscription = connectivity.onConnectivityChanged.listen(
        (ConnectivityResult result) {
          // CORREÇÃO: Sempre verificar se mounted antes de setState
          if (mounted) {
            setState(() {
              _connectionStatus = result;
              _isOnline = result != ConnectivityResult.none;
            });
          }
        },
        onError: (error) {
          print('⚠️ Erro na verificação de conectividade: $error');
          // CORREÇÃO: Verificar mounted mesmo em caso de erro
          if (mounted) {
            setState(() {
              _connectionStatus = ConnectivityResult.none;
              _isOnline = false;
            });
          }
        },
      );
      
    } catch (e) {
      print('❌ Erro ao verificar conectividade: $e');
      // CORREÇÃO: Verificar mounted em catch também
      if (mounted) {
        setState(() {
          _connectionStatus = ConnectivityResult.none;
          _isOnline = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showPendentes,
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _isOnline 
                ? const Color(0xFFE8962E).withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _isOnline ? Icons.wifi : Icons.wifi_off,
              color: _isOnline ? const Color(0xFFE8962E) : Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isOnline ? 'Conectado' : 'Offline',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF23345F),
                  ),
                ),
                const SizedBox(height: 2),
                if (_pendentes > 0)
                  Text('$_pendentes entrevista(s) esperando envio — toque para ver',
                      style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600)),
                Text(
                  _getConnectionDescription(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isOnline 
                ? const Color(0xFFE8962E).withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isOnline ? Icons.check_circle : Icons.error,
              size: 16,
              color: _isOnline ? const Color(0xFFE8962E) : Colors.red,
            ),
          ),
        ],
      ),
    ),
    );
  }

  String _getConnectionDescription() {
    if (!_isOnline) {
      return 'Dados serão sincronizados quando conectar';
    }
    
    switch (_connectionStatus) {
      case ConnectivityResult.wifi:
        return 'Conectado via Wi-Fi';
      case ConnectivityResult.mobile:
        return 'Conectado via dados móveis';
      case ConnectivityResult.ethernet:
        return 'Conectado via Ethernet';
      default:
        return 'Status de conexão desconhecido';
    }
  }
}