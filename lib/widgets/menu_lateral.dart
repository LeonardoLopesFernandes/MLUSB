import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Menu lateral (drawer) do MLUSB, com cards de dispositivo e opções.
class MenuLateral extends StatelessWidget {
  const MenuLateral({
    super.key,
    this.aoRecarregar,
    this.aoExcluir,
    this.aoNovaPasta,
    this.aoProcurar,
    this.aoModoExibicao,
    this.aoTamanhoFonte,
    this.aoOrganizar,
    this.aoTipoArquivo,
    this.aoAutoBackup,
    this.aoSobre,
    this.aoConfiguracoes,
    this.aoExtensoes,
    this.aoWebDav,
    this.aoIrParaUtilitarios,
    this.aoSair,
  });

  final VoidCallback? aoRecarregar;
  final VoidCallback? aoExcluir;
  final VoidCallback? aoNovaPasta;
  final VoidCallback? aoProcurar;
  final VoidCallback? aoModoExibicao;
  final VoidCallback? aoTamanhoFonte;
  final VoidCallback? aoOrganizar;
  final VoidCallback? aoTipoArquivo;
  final VoidCallback? aoAutoBackup;
  final VoidCallback? aoSobre;
  final VoidCallback? aoConfiguracoes;
  final VoidCallback? aoExtensoes;
  final VoidCallback? aoWebDav;
  final VoidCallback? aoIrParaUtilitarios;
  final VoidCallback? aoSair;

  static const Color _azulClaro = Color(0xFF79A0EB);
  static const Color _fundoCard = Color(0xFF151D2A);
  static const Color _texto = Color(0xFFE2E8F0);
  static const Color _textoMuted = Color(0xFF8B9BB4);
  static const Color _borda = Color(0xFF202B3D);

  Future<String> _obterCaminho() async {
    final dirs = await getExternalStorageDirectories();
    return dirs?.isNotEmpty == true ? dirs!.first.path : '/storage/emulated/0';
  }

  Widget _itemMenu(IconData icone, String rotulo, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icone, size: 20, color: _textoMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                rotulo,
                style: const TextStyle(color: _texto, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0F1626),
      width: 300,
      child: SafeArea(
        child: Column(
          children: [
            // Cabeçalho com ícones superiores.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh, color: _textoMuted),
                    tooltip: 'Recarregar',
                    onPressed: aoRecarregar,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: _textoMuted),
                    tooltip: 'Excluir',
                    onPressed: aoExcluir,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Card: Armazenamento interno.
                  FutureBuilder<String>(
                    future: _obterCaminho(),
                    builder: (ctx, snapshot) => _card(
                      icone: Icons.storage,
                      titulo: 'Armazenamento interno',
                      subtitulo: null,
                      caminho:
                          snapshot.data ?? '/storage/emulated/0',
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Card: WebDAV.
                  _card(
                    icone: Icons.cloud_outlined,
                    titulo: 'WebDAV',
                    subtitulo: null,
                    caminho: '/WEB',
                    onTap: aoWebDav,
                  ),
                  const SizedBox(height: 12),
                  // Menu de opções.
                  Container(
                    decoration: BoxDecoration(
                      color: _fundoCard,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: Text(
                            'Opções do Dispositivo',
                            style: TextStyle(
                              color: _textoMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Divider(height: 1, color: _borda),
                        _itemMenu(
                          Icons.grid_view,
                          'Modo de exibição',
                          aoModoExibicao,
                        ),
                        _itemMenu(
                          Icons.format_size,
                          'Tamanho da fonte',
                          aoTamanhoFonte,
                        ),
                        _itemMenu(Icons.sort, 'Organizar', aoOrganizar),
                        _itemMenu(
                          Icons.create_new_folder,
                          'Nova pasta',
                          aoNovaPasta,
                        ),
                        _itemMenu(
                          Icons.search,
                          'Procurar',
                          aoProcurar,
                        ),
                        _itemMenu(
                          Icons.description_outlined,
                          'Tipo de arquivo',
                          aoTipoArquivo,
                        ),
                        _itemMenu(
                          Icons.backup_outlined,
                          'Auto Backup',
                          aoAutoBackup,
                        ),
                        _itemMenu(
                          Icons.info_outline,
                          'Sobre o montador MLUSB',
                          aoSobre,
                        ),
                        _itemMenu(
                          Icons.settings_outlined,
                          'Configurações',
                          aoConfiguracoes,
                        ),
                        _itemMenu(
                          Icons.extension_outlined,
                          'Informações sobre extensões',
                          aoExtensoes,
                        ),
                        _itemMenu(
                          Icons.dns_outlined,
                          'Utilitários de disco',
                          aoIrParaUtilitarios,
                        ),
                        _itemMenu(
                          Icons.logout,
                          'Saída',
                          aoSair,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({
    required IconData icone,
    required String titulo,
    String? subtitulo,
    required String caminho,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _fundoCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icone, size: 32, color: _azulClaro),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  if (subtitulo != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitulo,
                      style: const TextStyle(fontSize: 13, color: _azulClaro),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    caminho,
                    style: const TextStyle(fontSize: 13, color: _textoMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}