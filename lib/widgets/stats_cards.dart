import 'package:flutter/material.dart';
import '../models/questionnaire.dart';

class StatsCards extends StatelessWidget {
  final List<Questionnaire> questionnaires;
  
  const StatsCards({
    super.key,
    required this.questionnaires,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            // Antes contava os formulários CRIADOS hoje no painel, e mostrava
            // 0 com questionário na lista. O que interessa ao entrevistador é
            // quantos ele tem liberados para aplicar agora.
            questionnaires.length.toString(),
            'Formulários liberados para você',
            const Color(0xFFE8962E),
          ),
        ),
        /*const SizedBox(width: 15),
        Expanded(
          child: _buildStatCard(
            _getPendingSyncCount().toString(),
            'Pendentes de Sincronizar',
            Colors.orange,
          ),
        ), */
      ],
    );
  }

  /// Conta quantos questionários estão pendentes de sincronização
  /// (você pode ajustar esta lógica conforme sua necessidade)
  int _getPendingSyncCount() {
    // Exemplo: considerando questionários com status diferente de 'active' como pendentes
    // Ajuste conforme sua lógica de negócio
    return questionnaires.where((questionnaire) {
      return questionnaire.status != 'active';
    }).length;
  }

  Widget _buildStatCard(String number, String label, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: borderColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            number,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF23345F),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}