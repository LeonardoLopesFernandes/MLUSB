import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../services/gerenciador_arquivos.dart';
import '../services/permissao_utils.dart';
import '../services/preferencias_arquivo.dart';
import '../widgets/dialogos_mlusb.dart';
import '../widgets/menu_lateral.dart';
import '../widgets/modal_progresso.dart';
import '../widgets/theme_widgets.dart';

/// Gerenciador de arquivos com navegação e operações (copiar, colar,
/// recortar, renomear, excluir, nova pasta, propriedades).
class FileManagerScreen extends StatefulWidget {
  const FileManagerScreen({
    super.key,
    this.aoIrParaUtilitarios,
    this.aoIrParaBackup,
  });

  final VoidCallback? aoIrParaUtilitarios;
  final VoidCallback? aoIrParaBackup;

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  List<FileSystemEntity> _entidades = [];
  List<FileSystemEntity> _todos = [];
  String _caminhoAtual = '';
  bool _carregando = false;
  String? _mensagemErro;

  // Preferências.
  ModoExibicao _modoExibicao = ModoExibicao.lista;
  double _tamanhoFonte = 14;
  String _ordenacao = 'nome';
  bool _ordenacaoDecrescente = false;
  String _filtroTipo = 'todos';

  // Modo de seleção múltipla.
  final Set<String> _selecionados = {};
  bool _modoSelecao = false;

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
    _modoExibicao = await PreferenciasArquivo.obterModo();
    _tamanhoFonte = await PreferenciasArquivo.obterTamanhoFonte();
    _ordenacao = await PreferenciasArquivo.obterOrdenacao();
    _ordenacaoDecrescente = await PreferenciasArquivo.obterDecrescente();
    _filtroTipo = await PreferenciasArquivo.obterFiltro();
    if (!mounted) return;
    _caminhoAtual = '/storage/emulated/0';
    await _recarregar();
  }

  Future<void> _recarregar() async {
    setState(() => _carregando = true);
    try {
      final lista = await GerenciadorArquivos.listar(_caminhoAtual);
      if (!mounted) return;
      _todos = lista;
      setState(() {
        _entidades = _aplicarFiltro(lista);
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

  List<FileSystemEntity> _aplicarFiltro(List<FileSystemEntity> lista) {
    final filtrados = lista.where((e) {
      final nome = p.basename(e.path);
      if (e is Directory) return true;
      return PreferenciasArquivo.correspondeFiltro(nome, _filtroTipo);
    }).toList();

    filtrados.sort((a, b) {
      final aDir = a is Directory;
      final bDir = b is Directory;
      if (aDir != bDir) return aDir ? -1 : 1;
      int resultado;
      switch (_ordenacao) {
        case 'tamanho':
          resultado = _tamanho(a).compareTo(_tamanho(b));
          break;
        case 'data':
          resultado = a.statSync().modified
              .compareTo(b.statSync().modified);
          break;
        default:
          resultado = a.path.toLowerCase().compareTo(b.path.toLowerCase());
      }
      return _ordenacaoDecrescente ? -resultado : resultado;
    });
    return filtrados;
  }

  int _tamanho(FileSystemEntity e) {
    if (e is File) return e.lengthSync();
    return 0;
  }

  Future<void> _navegarPara(String caminho) async {
    _caminhoAtual = caminho;
    await _recarregar();
  }

  void _limparSelecao() {
    setState(() {
      _selecionados.clear();
      _modoSelecao = false;
    });
  }

  void _alternarSelecao(String caminho) {
    setState(() {
      _modoSelecao = true;
      if (_selecionados.contains(caminho)) {
        _selecionados.remove(caminho);
        if (_selecionados.isEmpty) _modoSelecao = false;
      } else {
        _selecionados.add(caminho);
      }
    });
  }

  List<String> _caminhosSelecionados() => _selecionados.toList();

  void _prepararTransferencia(bool recortar) {
    setState(() {
      _itensTransferencia = _caminhosSelecionados();
      _recortar = recortar;
      _mensagemErro = recortar
          ? '${_itensTransferencia.length} item(ns) pronto(s) para mover. '
              'Use "Colar" na pasta de destino.'
          : '${_itensTransferencia.length} item(ns) copiado(s). '
              'Use "Colar" na pasta de destino.';
    });
    _limparSelecao();
  }

  Future<void> _renomearSelecionado() async {
    final caminhos = _caminhosSelecionados();
    if (caminhos.isEmpty) return;
    if (caminhos.length > 1) {
      _mostrarErro('Renomeie um item por vez.');
      return;
    }
    final entidade = _entidades
        .where((e) => e.path == caminhos.first)
        .firstOrNull;
    if (entidade != null) {
      await _renomear(entidade);
    }
    _limparSelecao();
  }

  Future<void> _excluirSelecionados() async {
    final caminhos = _caminhosSelecionados();
    if (caminhos.isEmpty) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir'),
        content: Text(
          'Tem certeza de que deseja excluir ${caminhos.length} '
          'item(ns) selecionado(s)?',
        ),
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
      for (final caminho in caminhos) {
        await GerenciadorArquivos.excluir(caminho);
      }
      await _recarregar();
    } catch (e) {
      _mostrarErro('Erro ao excluir: $e');
    }
    _limparSelecao();
  }

  Future<void> _procurar() async {
    final controller = TextEditingController();
    final termo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Procurar'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome do arquivo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Procurar'),
          ),
        ],
      ),
    );
    if (termo == null || termo.isEmpty) return;
    setState(() {
      _mensagemErro = null;
      _carregando = true;
    });
    try {
      final dir = Directory(_caminhoAtual);
      final todos = await dir
          .list(recursive: true, followLinks: false)
          .toList();
      final filtrados = todos
          .where((e) =>
              p.basename(e.path).toLowerCase().contains(termo.toLowerCase()))
          .toList();
      filtrados.sort((a, b) {
        final aDir = a is Directory;
        final bDir = b is Directory;
        if (aDir != bDir) return aDir ? -1 : 1;
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });
      if (!mounted) return;
      setState(() {
        _entidades = filtrados;
        _carregando = false;
        if (filtrados.isEmpty) {
          _mensagemErro = 'Nenhum resultado encontrado para "$termo".';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _mensagemErro = 'Erro ao procurar: $e';
      });
    }
  }

  Future<void> _selecionarPasta() async {
    final caminho = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Selecione uma pasta',
    );
    if (caminho == null || caminho.isEmpty) return;
    _caminhoAtual = caminho;
    await _recarregar();
  }

  Future<void> _modoExibicaoDialog() async {
    final opcoes = {
      'Lista': ModoExibicao.lista,
      'Detalhes': ModoExibicao.detalhes,
      'Ícones': ModoExibicao.icones,
    };
    final selecionado = await showDialog<ModoExibicao>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: const Color(0xFF151D2A),
        title: const Text(
          'Modo de exibição',
          style: TextStyle(color: Color(0xFF4169E1)),
        ),
        children: opcoes.entries.map((e) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, e.value),
            child: Row(
              children: [
                Icon(
                  e.value == ModoExibicao.icones
                      ? Icons.grid_view
                      : e.value == ModoExibicao.detalhes
                          ? Icons.view_list
                          : Icons.list,
                  color: _modoExibicao == e.value
                      ? const Color(0xFF4169E1)
                      : const Color(0xFF8B9BB4),
                ),
                const SizedBox(width: 12),
                Text(
                  e.key,
                  style: TextStyle(
                    color: _modoExibicao == e.value
                        ? Colors.white
                        : const Color(0xFFE2E8F0),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (selecionado == null) return;
    setState(() => _modoExibicao = selecionado);
    await PreferenciasArquivo.salvarModo(selecionado);
  }

  Future<void> _tamanhoFonteDialog() async {
    var valor = _tamanhoFonte;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          backgroundColor: const Color(0xFF151D2A),
          title: const Text(
            'Tamanho da fonte',
            style: TextStyle(color: Color(0xFF4169E1)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                valor.toStringAsFixed(0),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: valor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Slider(
                value: valor,
                min: 10,
                max: 24,
                divisions: 7,
                activeColor: const Color(0xFF4169E1),
                onChanged: (v) => setLocalState(() => valor = v),
              ),
            ],
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
                'OK',
                style: TextStyle(color: Color(0xFF4169E1)),
              ),
            ),
          ],
        ),
      ),
    );
    setState(() => _tamanhoFonte = valor);
    await PreferenciasArquivo.salvarTamanhoFonte(valor);
  }

  Future<void> _organizarDialog() async {
    var criterio = _ordenacao;
    var decrescente = _ordenacaoDecrescente;
    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          backgroundColor: const Color(0xFF151D2A),
          title: const Text(
            'Organizar',
            style: TextStyle(color: Color(0xFF4169E1)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ordenar por',
                style: TextStyle(color: Color(0xFF8B9BB4), fontSize: 13),
              ),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: criterio,
                dropdownColor: const Color(0xFF1E293B),
                items: const [
                  DropdownMenuItem(value: 'nome', child: Text('Nome')),
                  DropdownMenuItem(value: 'tamanho', child: Text('Tamanho')),
                  DropdownMenuItem(value: 'data', child: Text('Data')),
                ],
                onChanged: (v) => setLocalState(() => criterio = v!),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Decrescente',
                    style: TextStyle(color: Colors.white)),
                value: decrescente,
                activeColor: const Color(0xFF4169E1),
                onChanged: (v) => setLocalState(() => decrescente = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Color(0xFF8B9BB4)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Aplicar',
                style: TextStyle(color: Color(0xFF4169E1)),
              ),
            ),
          ],
        ),
      ),
    );
    if (resultado != true) return;
    setState(() {
      _ordenacao = criterio;
      _ordenacaoDecrescente = decrescente;
      _entidades = _aplicarFiltro(_todos);
    });
    await PreferenciasArquivo.salvarOrdenacao(criterio, decrescente);
  }

  Future<void> _tipoArquivoDialog() async {
    final filtros = {
      'todos': 'Todos',
      'audio': 'Áudio',
      'video': 'Vídeo',
      'imagem': 'Imagem',
      'iso': 'ISO',
      'documento': 'Documento',
    };
    final selecionado = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: const Color(0xFF151D2A),
        title: const Text(
          'Tipo de arquivo',
          style: TextStyle(color: Color(0xFF4169E1)),
        ),
        children: filtros.entries.map((e) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, e.key),
            child: Row(
              children: [
                Icon(
                  _iconeFiltro(e.key),
                  color: _filtroTipo == e.key
                      ? const Color(0xFF4169E1)
                      : const Color(0xFF8B9BB4),
                ),
                const SizedBox(width: 12),
                Text(
                  e.value,
                  style: const TextStyle(color: Color(0xFFE2E8F0)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (selecionado == null) return;
    setState(() {
      _filtroTipo = selecionado;
      _entidades = _aplicarFiltro(_todos);
    });
    await PreferenciasArquivo.salvarFiltro(selecionado);
  }

  IconData _iconeFiltro(String filtro) {
    switch (filtro) {
      case 'audio':
        return Icons.music_note;
      case 'video':
        return Icons.movie;
      case 'imagem':
        return Icons.image;
      case 'iso':
        return Icons.disc_full;
      case 'documento':
        return Icons.description;
      default:
        return Icons.all_inbox;
    }
  }

  Future<void> _excluirConteudoAtual() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir'),
        content: Text(
          'Deseja excluir o conteúdo da pasta atual '
          '(${_entidades.length} item(ns))?',
        ),
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
      for (final e in _entidades) {
        await GerenciadorArquivos.excluir(e.path);
      }
      await _recarregar();
    } catch (e) {
      _mostrarErro('Erro ao excluir: $e');
    }
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

  Widget _barraAcoesSelecao() {
    Widget botao(IconData icone, String rotulo, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icone, size: 22, color: const Color(0xFF8B9BB4)),
                const SizedBox(height: 4),
                Text(
                  rotulo,
                  style: const TextStyle(
                    color: Color(0xFF8B9BB4),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF151D2A),
        border: Border.all(color: const Color(0xFF202B3D)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          botao(Icons.content_copy, 'Copiar', () {
            _prepararTransferencia(false);
          }),
          botao(Icons.drive_file_move_outline, 'Mover', () {
            _prepararTransferencia(true);
          }),
          botao(Icons.edit_outlined, 'Renomear', _renomearSelecionado),
          botao(Icons.delete_outline, 'Excluir', _excluirSelecionados),
          Expanded(
            child: InkWell(
              onTap: _limparSelecao,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_selecionados.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Fechar',
                      style: TextStyle(
                        color: Color(0xFF8B9BB4),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: const Color(0xFF16203A),
        foregroundColor: Colors.white,
        title: const Text('MLUSB'),
        centerTitle: true,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      drawer: MenuLateral(
        aoRecarregar: _recarregar,
        aoExcluir: _excluirConteudoAtual,
        aoNovaPasta: _novaPasta,
        aoProcurar: _procurar,
        aoModoExibicao: _modoExibicaoDialog,
        aoTamanhoFonte: _tamanhoFonteDialog,
        aoOrganizar: _organizarDialog,
        aoTipoArquivo: _tipoArquivoDialog,
        aoAutoBackup: () {
          Navigator.pop(context);
          widget.aoIrParaBackup?.call();
        },
        aoSobre: () {
          Navigator.pop(context);
          DialogosMlusb.sobre(context);
        },
        aoConfiguracoes: () {
          Navigator.pop(context);
          DialogosMlusb.configuracoes(context);
        },
        aoExtensoes: () {
          Navigator.pop(context);
          DialogosMlusb.extensoes(context);
        },
        aoWebDav: () {
          Navigator.pop(context);
          DialogosMlusb.webDav(context);
        },
        aoIrParaUtilitarios: () {
          Navigator.pop(context);
          widget.aoIrParaUtilitarios?.call();
        },
        aoSair: () async {
          Navigator.pop(context);
          final confirmar = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Saída'),
              content: const Text('Deseja sair do app?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Sair'),
                ),
              ],
            ),
          );
          if (confirmar == true) {
            // ignore: use_build_context_synchronously
            Navigator.of(context).pop();
          }
        },
      ),
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
                              padding: const EdgeInsets.only(
                                top: 8,
                                left: 8,
                                right: 8,
                                bottom: 80,
                              ),
                              itemCount: _entidades.length,
                              itemBuilder: (ctx, i) {
                                final entidade = _entidades[i];
                                final isPasta = entidade is Directory;
                                final nome = p.basename(entidade.path);
                                final stat = entidade.statSync();
                                final selecionado =
                                    _selecionados.contains(entidade.path);
                                return Container(
                                  decoration: selecionado
                                      ? const BoxDecoration(
                                          color: Color(0xFF1E293B),
                                          border: Border(
                                            left: BorderSide(
                                              color: Color(0xFF3B82F6),
                                              width: 3,
                                            ),
                                          ),
                                        )
                                      : null,
                                  child: ListTile(
                                    leading: _modoSelecao
                                        ? Checkbox(
                                            value: selecionado,
                                            activeColor:
                                                const Color(0xFF3B82F6),
                                            onChanged: (_) => _alternarSelecao(
                                              entidade.path,
                                            ),
                                          )
                                        : Icon(
                                            isPasta
                                                ? Icons.folder
                                                : Icons.insert_drive_file,
                                            color: isPasta
                                                ? const Color(0xFF4169E1)
                                                : const Color(0xFF8E9FAE),
                                          ),
                                    title: Text(
                                      nome,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: _tamanhoFonte,
                                        fontWeight: selecionado
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: _modoExibicao ==
                                            ModoExibicao.lista
                                        ? null
                                        : Text(
                                            isPasta
                                                ? GerenciadorArquivos
                                                    .formatarData(entidade)
                                                : '${GerenciadorArquivos.formatarBytes(stat.size)}'
                                                    '  '
                                                    '${GerenciadorArquivos.formatarData(entidade)}',
                                            style: const TextStyle(
                                              color: Color(0xFF5D7182),
                                              fontSize: 11,
                                            ),
                                          ),
                                    onTap: () {
                                      if (_modoSelecao) {
                                        _alternarSelecao(entidade.path);
                                      } else if (isPasta) {
                                        _navegarPara(entidade.path);
                                      } else {
                                        _compartilhar(entidade);
                                      }
                                    },
                                    onLongPress: () {
                                      if (!_modoSelecao) {
                                        _alternarSelecao(entidade.path);
                                      } else {
                                        _abrirOperacoes(entidade);
                                      }
                                    },
                                  ),
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
            if (_modoSelecao)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _barraAcoesSelecao(),
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