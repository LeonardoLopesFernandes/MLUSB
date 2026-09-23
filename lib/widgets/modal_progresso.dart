import 'package:flutter/material.dart';

/// Modal de progresso: caixa branca com título, barra de progresso e
/// informações (percentual + progresso/limite).
class ModalProgresso extends StatelessWidget {
  const ModalProgresso({
    super.key,
    required this.percentual,
    required this.progresso,
    required this.limite,
    this.titulo = 'Processando...',
  });

  final double percentual;
  final int progresso;
  final int limite;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    final pct = (percentual.clamp(0.0, 1.0) * 100).round();

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              titulo,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: percentual.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: const Color(0xFFE0E0E0),
                color: const Color(0xFF4169E1),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$pct%',
                  style: const TextStyle(
                    color: Color(0xFF555555),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '$progresso/$limite',
                  style: const TextStyle(
                    color: Color(0xFF555555),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}