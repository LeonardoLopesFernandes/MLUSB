import 'package:flutter/material.dart';

/// Diálogos e telas auxiliares do MLUSB (Sobre, Extensões, WebDAV,
/// Configurações, Modo de exibição, Tamanho da fonte, Organizar, Tipo de arquivo).
class DialogosMlusb {
  DialogosMlusb._();

  /// Diálogo "Sobre o montador MLUSB".
  static Future<void> sobre(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151D2A),
        title: const Text(
          'Sobre o montador MLUSB',
          style: TextStyle(color: Color(0xFF4169E1)),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MLUSB Flutter',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            SizedBox(height: 4),
            Text(
              'Versão 1.0.0',
              style: TextStyle(color: Color(0xFF8B9BB4)),
            ),
            SizedBox(height: 12),
            Text(
              'Gerenciador de arquivos e utilitários de disco, '
              'baseado no MLUSB Mounter (jp.co.medialogic.usbmounter).',
              style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Fechar',
              style: TextStyle(color: Color(0xFF4169E1)),
            ),
          ),
        ],
      ),
    );
  }

  /// Diálogo "Informações sobre extensões".
  static Future<void> extensoes(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151D2A),
        title: const Text(
          'Informações sobre extensões',
          style: TextStyle(color: Color(0xFF4169E1)),
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LinhaExtensao('NTFS', 'Suporte a escrita NTFS'),
              _LinhaExtensao('exFAT', 'Suporte a sistema de arquivos exFAT'),
              _LinhaExtensao('ISO', 'Montagem de arquivos de imagem ISO'),
              _LinhaExtensao('WebDAV', 'Acesso a servidores WebDAV'),
              _LinhaExtensao('SMB', 'Acesso a compartilhamentos de rede'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Fechar',
              style: TextStyle(color: Color(0xFF4169E1)),
            ),
          ),
        ],
      ),
    );
  }

  /// Diálogo de configuração WebDAV.
  static Future<void> webDav(BuildContext context) async {
    final nome = TextEditingController();
    final endereco = TextEditingController();
    final usuario = TextEditingController();
    final senha = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151D2A),
        title: const Text(
          'Configuração WebDAV',
          style: TextStyle(color: Color(0xFF4169E1)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _campo(ctx, nome, 'Nome de exibição'),
              const SizedBox(height: 8),
              _campo(ctx, endereco, 'Endereço (http://)'),
              const SizedBox(height: 8),
              _campo(ctx, usuario, 'Usuário'),
              const SizedBox(height: 8),
              _campo(ctx, senha, 'Senha', obscure: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF8B9BB4)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Salvar',
              style: TextStyle(color: Color(0xFF4169E1)),
            ),
          ),
        ],
      ),
    );
    nome.dispose();
    endereco.dispose();
    usuario.dispose();
    senha.dispose();
  }

  /// Diálogo de configurações gerais.
  static Future<void> configuracoes(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151D2A),
        title: const Text(
          'Configurações',
          style: TextStyle(color: Color(0xFF4169E1)),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.visibility, color: Color(0xFF79A0EB)),
              title: Text('Mostrar arquivos ocultos',
                  style: TextStyle(color: Colors.white)),
              trailing: Icon(Icons.check_box_outline_blank,
                  color: Color(0xFF3B485E)),
            ),
            ListTile(
              leading: Icon(Icons.folder, color: Color(0xFF79A0EB)),
              title: Text('Mostrar sistema de arquivos',
                  style: TextStyle(color: Colors.white)),
              trailing: Icon(Icons.check_box_outline_blank,
                  color: Color(0xFF3B485E)),
            ),
            ListTile(
              leading: Icon(Icons.tune, color: Color(0xFF79A0EB)),
              title: Text('Opções avançadas',
                  style: TextStyle(color: Colors.white)),
              trailing: Icon(Icons.chevron_right,
                  color: Color(0xFF8B9BB4)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Fechar',
              style: TextStyle(color: Color(0xFF4169E1)),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _campo(
      BuildContext ctx, TextEditingController controller, String rotulo,
      {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: rotulo,
        labelStyle: const TextStyle(color: Color(0xFF8B9BB4)),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF3B485E)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF4169E1)),
        ),
      ),
    );
  }
}

class _LinhaExtensao extends StatelessWidget {
  const _LinhaExtensao(this.nome, this.descricao);

  final String nome;
  final String descricao;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF3B485E)),
            ),
            child: Text(
              nome,
              style: const TextStyle(
                color: Color(0xFF79A0EB),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              descricao,
              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}