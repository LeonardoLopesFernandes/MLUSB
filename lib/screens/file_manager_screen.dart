import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/gerenciador_arquivos.dart';
import '../services/permissao_utils.dart';
import '../widgets/modal_progresso.dart';
import '../widgets/theme_widgets.dart';

/// Gerenciador de arquivos com navegação e operações (copiar, colar,
/// recortar, renomear, excluir, nova pasta, propriedades).
class FileManagerScreen extends StatefulWidget {
  const FileManagerScreen({super.key});

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  List<FileSystemEntity> _entidades = [];
  String _caminhoAtual = '';
  bool _carregando = false;
  String? _mensagemErro;

  // Área de transferência (copiar/recortar).
  List<String> _itensTransferencia = [];
  bool _recortar = false;

  bool _processando = false;
  double _progresso = 0;
  int _bytesLidos = 0;
  int _bytesTotal = 1;
  String? _tituloOperacao;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    final dir = await getApplicationDocumentsDirectory();
    if (!mounted) return;
    _caminhoAtual = dir.path;
    await _recarregar();
  }

  Future<void> _recarregar() async {
    setState(() => _carregando = true);
    try {
      final lista = await GerenciadorArquivos.listar(_caminhoAtual);
      if (!mounted) return;
      setState(() {
        _entidades = lista;
        _carregando = false;
        _mensagemErro = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _mensagemErro = 'Erro ao listar: $e';
      });
    }
  }

  Future<void> _navegarPara(String caminho) async {
    _caminhoAtual = caminho;
    await _recarregar();
  }

  Future<void> _selecionarPasta() async {
    final caminho = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Selecione uma pasta',
    );
    if (caminho == null || caminho.isEmpty) return;
    _caminhoAtual = caminho;
    await _recarregar();
  }

  Future<void> _pedirPermissao() async {
    final ok = await PermissaoUtils.solicitarAcessoArmazenamento();
    if (!ok && mounted) {
      setState(() {
        _mensagemErro =
            'Sem permissão de escrita. Ative "Todos os arquivos" nas '
            'Configurações do app.';
      });
    }
  }

  Future<void> _abrirOperacoes(FileSystemEntity entidade) async {
    final acao = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1B2436),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.content_copy, color: Color(0xFF4169E1)),
              title: const Text('Copiar'),
              onTap: () {
                _itensTransferencia = [entidade.path];
                _recortar = false;
                Navigator.pop(ctx, 'copiar');
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_cut, color: Color(0xFF4169E1)),
              title: const Text('Recortar'),
              onTap: () {
                _itensTransferencia = [entidade.path];
                _recortar = true;
                Navigator.pop(ctx, 'recortar');
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF4169E1)),
              title: const Text('Renomear'),
              onTap: () async {
                await _renomear(entidade);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Color(0xFFEF5350)),
              title: const Text('Excluir'),
              onTap: () async {
                await _excluir(entidade);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info, color: Color(0xFF4169E1)),
              title: const Text('Propriedades'),
              onTap: () {
                Navigator.pop(ctx);
                _mostrarPropriedades(entidade);
              },
            ),
          ],
        ),
      ),
    );
    if (acao != null && mounted) {
      setState(() {
        _mensagemErro = _recortar
            ? '${_itensTransferencia.length} item(ns) pronto(s) para mover. '
                'Use "Colar" na pasta de destino.'
            : '${_itensTransferencia.length} item(ns) copiado(s). '
                'Use "Colar" na pasta de destino.';
      });
    }
  }

  Future<void> _renomear(FileSystemEntity entidade) async {
    final nomeAtual = p.basename(entidade.path);
    final controller = TextEditingController(text: nomeAtual);
    final novoNome = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renomear'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Novo nome'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (novoNome == null || novoNome.isEmpty) return;
    try {
      await GerenciadorArquivos.renomear(
        entidade.path,
        p.join(p.dirname(entidade.path), novoNome),
      );
      await _recarregar();
    } catch (e) {
      _mostrarErro('Erro ao renomear: $e');
    }
  }

  Future<void> _excluir(FileSystemEntity entidade) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir'),
        content: Text('Tem certeza de que deseja excluir '
            '"${p.basename(entidade.path)}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await GerenciadorArquivos.excluir(entidade.path);
      await _recarregar();
    } catch (e) {
      _mostrarErro('Erro ao excluir: $e');
    }
  }

  Future<void> _novaPasta() async {
    final controller = TextEditingController();
    final nome = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova pasta'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome da pasta'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    if (nome == null || nome.isEmpty) return;
    try {
      await GerenciadorArquivos.novaPasta(_caminhoAtual, nome);
      await _recarregar();
    } catch (e) {
      _mostrarErro('Erro ao criar pasta: $e');
    }
  }

  void _mostrarPropriedades(FileSystemEntity entidade) {
    final stat = entidade.statSync();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Propriedades'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nome: ${p.basename(entidade.path)}'),
            const SizedBox(height: 6),
            Text(
              'Tipo: ${entidade is Directory ? 'Pasta' : 'Arquivo'}',
            ),
            const SizedBox(height: 6),
            if (entidade is File)
              Text(
                'Tamanho: '
                '${GerenciadorArquivos.formatarBytes(stat.size)}',
              ),
            const SizedBox(height: 6),
            Text(
              'Modificado: '
              '${GerenciadorArquivos.formatarData(entidade)}',
            ),
            const SizedBox(height: 6),
            Text(
              'Caminho: ${entidade.path}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _colar() async {
    if (_itensTransferencia.isEmpty) return;
    await _pedirPermissao();

    final destino = _caminhoAtual;
    setState(() {
      _processando = true;
      _progresso = 0;
      _tituloOperacao = _recortar ? 'Movendo...' : 'Copiando...';
    });

    void aoProgresso(int lidos, int total, double percentual) {
      if (!mounted) return;
      setState(() {
        _bytesLidos = lidos;
        _bytesTotal = total;
        _progresso = percentual;
      });
    }

    try {
      for (final origem in _itensTransferencia) {
        final nome = p.basename(origem);
        final novoCaminho = p.join(destino, nome);
        final tipo = FileSystemEntity.typeSync(origem);
        if (tipo == FileSystemEntityType.directory) {
          await GerenciadorArquivos.copiarPasta(
            origem: origem,
            destino: novoCaminho,
            aoProgresso: aoProgresso,
          );
        } else {
          await GerenciadorArquivos.copiar(
            origem: origem,
            destino: novoCaminho,
            aoProgresso: aoProgresso,
          );
        }
        if (_recortar) {
          await GerenciadorArquivos.excluir(origem);
        }
      }
      if (!mounted) return;
      setState(() {
        _processando = false;
        _mensagemErro = null;
        _itensTransferencia = [];
        _recortar = false;
      });
      await _recarregar();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processando = false;
        _mensagemErro = 'Erro ao copiar: $e';
      });
    }
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    setState(() => _mensagemErro = mensagem);
  }

  Future<void> _compartilhar(FileSystemEntity entidade) async {
    if (entidade is! File) return;
    await Share.shareXFiles([XFile(entidade.path)]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  color: const Color(0xFF16203A),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.folder_open),
                        color: const Color(0xFF4169E1),
                        onPressed: _selecionarPasta,
                      ),
                      Expanded(
                        child: Text(
                          _caminhoAtual,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_caminhoAtual.isNotEmpty &&
                          _caminhoAtual != '/')
                        IconButton(
                          icon: const Icon(Icons.arrow_upward),
                          color: Colors.white,
                          onPressed: () {
                            final pai = p.dirname(_caminhoAtual);
                            if (pai != _caminhoAtual) _navegarPara(pai);
                          },
                        ),
                    ],
                  ),
                ),
                if (_itensTransferencia.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: const Color(0xFF1E2A4A),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_itensTransferencia.length} item(ns) '
                            '${_recortar ? 'para mover' : 'copiados'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        BotaoAzul(
                          rotulo: 'Colar',
                          icon: Icons.content_paste,
                          onPressed: _colar,
                        ),
                        const SizedBox(width: 8),
                        BotaoAzul(
                          rotulo: 'Cancelar',
                          onPressed: () => setState(() {
                            _itensTransferencia = [];
                            _recortar = false;
                            _mensagemErro = null;
                          }),
                        ),
                      ],
                    ),
                  ),
                if (_mensagemErro != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _mensagemErro!,
                      style: const TextStyle(color: Color(0xFFEF5350)),
                    ),
                  ),
                Expanded(
                  child: _carregando
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF4169E1),
                          ),
                        )
                      : _entidades.isEmpty
                          ? const Center(
                              child: Subtexto('Pasta vazia.', tamanho: 14),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: _entidades.length,
                              itemBuilder: (ctx, i) {
                                final entidade = _entidades[i];
                                final isPasta = entidade is Directory;
                                final nome = p.basename(entidade.path);
                                final stat = entidade.statSync();
                                return ListTile(
                                  leading: Icon(
                                    isPasta
                                        ? Icons.folder
                                        : Icons.insert_drive_file,
                                    color: isPasta
                                        ? const Color(0xFF4169E1)
                                        : const Color(0xFF8E9FAE),
                                  ),
                                  title: Text(
                                    nome,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    isPasta
                                        ? GerenciadorArquivos.formatarData(
                                            entidade)
                                        : '${GerenciadorArquivos.formatarBytes(stat.size)}'
                                            '  '
                                            '${GerenciadorArquivos.formatarData(entidade)}',
                                    style: const TextStyle(
                                      color: Color(0xFF5D7182),
                                      fontSize: 11,
                                    ),
                                  ),
                                  onTap: () {
                                    if (isPasta) {
                                      _navegarPara(entidade.path);
                                    } else {
                                      _compartilhar(entidade);
                                    }
                                  },
                                  onLongPress: () => _abrirOperacoes(entidade),
                                );
                              },
                            ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: BotaoPrincipal(
                    rotulo: 'NOVA PASTA',
                    icon: Icons.create_new_folder,
                    onPressed: _novaPasta,
                  ),
                ),
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