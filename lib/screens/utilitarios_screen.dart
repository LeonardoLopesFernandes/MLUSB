import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../services/permissao_utils.dart';
import '../services/utilitarios_disco.dart';
import '../widgets/modal_progresso.dart';
import '../widgets/theme_widgets.dart';

/// Utilitários de disco: verificar, formatar e apagar.
class UtilitariosScreen extends StatefulWidget {
  const UtilitariosScreen({super.key});

  @override
  State<UtilitariosScreen> createState() => _UtilitariosScreenState();
}

class _UtilitariosScreenState extends State<UtilitariosScreen> {
  String? _caminhoAlvo;
  bool _processando = false;
  double _progresso = 0;
  int _bytesLidos = 0;
  int _bytesTotal = 1;
  String? _tituloOperacao;
  String? _mensagemErro;

  Future<void> _selecionarAlvo() async {
    final caminho = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Selecione a pasta/dispositivo',
    );
    if (caminho == null || caminho.isEmpty) return;
    setState(() {
      _caminhoAlvo = caminho;
      _mensagemErro = null;
    });
  }

  Future<bool> _confirmar(String titulo, String mensagem) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    return confirmar == true;
  }

  void _iniciarOperacao(String titulo) {
    setState(() {
      _processando = true;
      _progresso = 0;
      _bytesLidos = 0;
      _bytesTotal = 1;
      _tituloOperacao = titulo;
      _mensagemErro = null;
    });
  }

  void _aoProgresso(int lidos, int total, double percentual) {
    if (!mounted) return;
    setState(() {
      _bytesLidos = lidos;
      _bytesTotal = total;
      _progresso = percentual;
    });
  }

  void _aoProgressoVerificacao(
      int lidos, int total, int erros, double percentual) {
    _aoProgresso(lidos, total, percentual);
  }

  void _finalizar() {
    if (!mounted) return;
    setState(() => _processando = false);
  }

  void _mostrarResultado(String titulo, String mensagem) {
    _finalizar();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _verificar(bool reparar) async {
    if (_caminhoAlvo == null) {
      setState(() => _mensagemErro = 'Selecione uma pasta/dispositivo.');
      return;
    }
    await PermissaoUtils.solicitarAcessoArmazenamento();

    _iniciarOperacao('Verificando...');
    try {
      final resultado = await UtilitariosDisco.verificarDisco(
        caminho: _caminhoAlvo!,
        reparar: reparar,
        aoProgresso: _aoProgressoVerificacao,
      );
      _mostrarResultado(
        'Verificação concluída',
        'Bytes lidos: '
        '${UtilitariosDisco.formatarBytes(resultado.bytesLidos)}\n'
        'Erros encontrados: ${resultado.erros}\n'
        '${resultado.semErros ? 'Nenhum erro de leitura.' : reparar ? 'Erros foram reparados.' : 'Considere reparar os erros.'}',
      );
    } catch (e) {
      _finalizar();
      setState(() => _mensagemErro = 'Falha na verificação: $e');
    }
  }

  Future<void> _apagar() async {
    if (_caminhoAlvo == null) {
      setState(() => _mensagemErro = 'Selecione uma pasta/dispositivo.');
      return;
    }
    final confirmar = await _confirmar(
      'Apagar disco',
      'Tem certeza de que deseja apagar? Todos os dados de '
      '"${p.basename(_caminhoAlvo!)}" serão apagados.',
    );
    if (!confirmar || !mounted) return;

    await PermissaoUtils.solicitarAcessoArmazenamento();

    final rapido = await _escolherModoApagar();
    if (rapido == null || !mounted) return;

    _iniciarOperacao('Apagando...');
    try {
      final resultado = await UtilitariosDisco.apagarDisco(
        caminho: _caminhoAlvo!,
        rapido: rapido,
        aoProgresso: _aoProgresso,
      );
      _mostrarResultado(
        'Apagamento concluído',
        'Bytes apagados: '
        '${UtilitariosDisco.formatarBytes(resultado.bytesApagados)}\n'
        'Modo: ${rapido ? 'Rápido' : 'Completo'}',
      );
    } catch (e) {
      _finalizar();
      setState(() => _mensagemErro = 'Falha ao apagar: $e');
    }
  }

  Future<bool?> _escolherModoApagar() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modo de apagamento'),
        content: const Text(
          'Rápido: sobrescreve com zeros em uma passada.\n'
          'Completo: duas passadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rápido'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Completo'),
          ),
        ],
      ),
    );
  }

  Future<void> _formatar() async {
    if (_caminhoAlvo == null) {
      setState(() => _mensagemErro = 'Selecione uma pasta/dispositivo.');
      return;
    }
    final confirmar = await _confirmar(
      'Formatar disco',
      'Deseja executar o processo de formatação? Todos os dados de '
      '"${p.basename(_caminhoAlvo!)}" serão apagados.',
    );
    if (!confirmar || !mounted) return;

    await PermissaoUtils.solicitarAcessoArmazenamento();

    final fs = await _escolherSistemaArquivos();
    if (fs == null || !mounted) return;

    final rotuloController = TextEditingController();
    final rotulo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rótulo do volume'),
        content: TextField(
          controller: rotuloController,
          decoration: const InputDecoration(labelText: 'Rótulo (ex.: MLUSB)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, rotuloController.text.trim()),
            child: const Text('Formatar'),
          ),
        ],
      ),
    );
    if (rotulo == null || !mounted) return;

    _iniciarOperacao('Formatando...');
    try {
      final resultado = await UtilitariosDisco.formatarDisco(
        caminhoDestino: _caminhoAlvo!,
        sistemaArquivos: fs,
        rotulo: rotulo,
        aoProgresso: _aoProgresso,
      );
      _mostrarResultado(
        'Formatação concluída',
        'Sistema de arquivos: ${resultado.sistemaArquivos}\n'
        'Rótulo: ${resultado.rotulo}\n'
        'Pasta de destino: $_caminhoAlvo',
      );
    } catch (e) {
      _finalizar();
      setState(() => _mensagemErro = 'Falha ao formatar: $e');
    }
  }

  Future<String?> _escolherSistemaArquivos() {
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Selecione o sistema de arquivos'),
        children: ['FAT32', 'exFAT', 'FAT16', 'FAT12', 'NTFS']
            .map(
              (fs) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, fs),
                child: Text(fs),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ThemeCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TituloCard(
                        'Dispositivo alvo',
                        icone: Icons.usb,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _caminhoAlvo ?? 'Nenhum dispositivo selecionado',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          BotaoAzul(
                            rotulo: 'SELECIONAR',
                            onPressed: _selecionarAlvo,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ThemeCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TituloCard(
                        'Verificador de disco',
                        icone: Icons.verified,
                      ),
                      const SizedBox(height: 8),
                      const Subtexto(
                        'Verifica a leitura da unidade e detecta erros.',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: BotaoAzul(
                              rotulo: 'VERIFICAR',
                              icon: Icons.play_arrow,
                              onPressed: () => _verificar(false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: BotaoAzul(
                              rotulo: 'REPARAR',
                              icon: Icons.healing,
                              onPressed: () => _verificar(true),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ThemeCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TituloCard(
                        'Apagador de disco',
                        icone: Icons.delete_forever,
                      ),
                      const SizedBox(height: 8),
                      const Subtexto(
                        'Apaga todos os dados do dispositivo.',
                      ),
                      const SizedBox(height: 12),
                      BotaoAzul(
                        rotulo: 'APAGAR',
                        icon: Icons.delete_sweep,
                        onPressed: _apagar,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ThemeCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TituloCard(
                        'Formatador de disco',
                        icone: Icons.drive_file_move,
                      ),
                      const SizedBox(height: 8),
                      const Subtexto(
                        'Inicializa (formata) a unidade USB (FAT/exFAT).',
                      ),
                      const SizedBox(height: 12),
                      BotaoAzul(
                        rotulo: 'FORMATAR',
                        icon: Icons.format_align_left,
                        onPressed: _formatar,
                      ),
                    ],
                  ),
                ),
                if (_mensagemErro != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _mensagemErro!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFEF5350)),
                  ),
                ],
              ],
            ),
            if (_processando)
              Positioned.fill(
                child: ColoredBox(
                  color: const Color(0x99000000),
                  child: Center(
                    child: ModalProgresso(
                      titulo: _tituloOperacao ?? 'Processando...',
                      percentual: _progresso,
                      progresso: _bytesLidos,
                      limite: _bytesTotal,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}