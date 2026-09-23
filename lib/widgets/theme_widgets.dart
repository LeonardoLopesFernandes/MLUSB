import 'package:flutter/material.dart';

/// Card no estilo escuro do layout (fundo azul escuro, bordas 8px).
class ThemeCard extends StatelessWidget {
  const ThemeCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B2436),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }
}

/// Título de card no estilo azul royal.
class TituloCard extends StatelessWidget {
  const TituloCard(this.texto, {super.key, this.icone});

  final String texto;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icone != null) ...[
          Icon(icone, size: 20, color: const Color(0xFF4169E1)),
          const SizedBox(width: 6),
        ],
        Text(
          texto,
          style: const TextStyle(
            color: Color(0xFF4169E1),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Botão azul royal compacto.
class BotaoAzul extends StatelessWidget {
  const BotaoAzul({
    super.key,
    required this.rotulo,
    this.onPressed,
    this.icon,
  });

  final String rotulo;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF3B5BDB),
      borderRadius: BorderRadius.circular(6),
      elevation: 0,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Text(
                rotulo,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botão principal azul royal (largura total).
class BotaoPrincipal extends StatelessWidget {
  const BotaoPrincipal({
    super.key,
    required this.rotulo,
    this.onPressed,
    this.icon,
  });

  final String rotulo;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF3B5BDB),
      borderRadius: BorderRadius.circular(6),
      elevation: 0,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Text(
                rotulo,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Subtexto (cinza claro).
class Subtexto extends StatelessWidget {
  const Subtexto(
    this.texto, {
    super.key,
    this.tamanho = 13,
    this.textoCentralizado = false,
  });

  final String texto;
  final double tamanho;
  final bool textoCentralizado;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      textAlign: textoCentralizado ? TextAlign.center : TextAlign.start,
      style: TextStyle(color: const Color(0xFF8E9FAE), fontSize: tamanho),
    );
  }
}