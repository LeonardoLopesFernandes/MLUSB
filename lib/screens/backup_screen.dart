import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../services/permissao_utils.dart';
import '../services/servico_backup.dart';
import '../widgets/modal_progresso.dart';
import '../widgets/theme_widgets.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  String? _origem;
  String? _destino;
  final TextEditingController _subpastaController = TextEditingController();
  ConfigBackup _config = const ConfigBackup(
    habilitado: false,
    intervaloHoras: 1,
    subpasta: 'MLUSB',
    tiposArquivo: ['Fotos', 'Músicas', 'Filmes', 'Documentos'],
  );

  bool _processando = false;
  double _progresso = 0;
  int _bytesLidos = 0;
  int _bytesTotal = 1;
  String? _tituloOperacao;
  String? _mensagemErro;

  @override
  void initState() {
    super.initState();
    _carregarConfig();
  }

  @override
  void dispose() {
    _subpastaController.dispose();
    super.dispose();
  }

  Future<void> _carregarConfig() async {
    final config = await ServicoBackup.obterConfig();
    if (!mounted) return;
    _subpastaController.text = config.subpasta;
    setState(() => _config = config);
  }

  Future<void> _selecionarOrigem() async {
    final caminho = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Selecione a pasta de origem',
    );
    if (caminho == null || caminho.isEmpty) return;
    setState(() {
      _origem = caminho;
      _mensagemErro = null;
    });
  }

  Future<void> _selecionarDestino() async {
    final caminho = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Selecione a pasta de destino',
    );
    if (caminho == null || caminho.isEmpty) return;
    setState(() {
      _destino = caminho;
      _mensagemErro = null;
    });
  }

  Future<void> _executarBackup() async {
    setState(() => _mensagemErro = null);
    if (_origem == null || _destino == null) {
      setState(() => _mensagemErro = 'Selecione a origem e o destino.');
      return;
    }
    await PermissaoUtils.solicitarAcessoArmazenamento();

    setState(() {
      _processando = true;
      _progresso = 0;
      _bytesLidos = 0;
      _bytesTotal = 1;
      _tituloOperacao = 'Fazendo backup...';
    });

    try {
      final resultado = await ServicoBackup.executarBackup(
        origem: _origem!,
        destino: _destino!,
        config: _config,
        aoProgresso: (arquivos, total, percentual) {
          if (!mounted) return;
          setState(() {
            _bytesLidos = arquivos;
            _bytesTotal = total;
            _progresso = percentual;
          });
        },
      );
      if (!mounted) return;
      setState(() => _processando = false);
      _mostrarResultado(
        'Backup concluído',
        '${resultado.quantidade} arquivo(s) copiado(s).',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processando = false;
        _mensagemErro = 'Falha no backup: $e';
      });
    }
  }

  Future<void> _restaurar() async {
    setState(() => _mensagemErro = null);
    if (_origem == null || _destino == null) {
      setState(() => _mensagemErro = 'Selecione a pasta de backup (origem) '
          'e o destino da restauração.');
      return;
    }
    await PermissaoUtils.solicitarAcessoArmazenamento();

    setState(() {
      _processando = true;
      _progresso = 0;
      _bytesLidos = 0;
      _bytesTotal = 1;
      _tituloOperacao = 'Restaurando...';
    });

    try {
      final resultado = await ServicoBackup.restaurarBackup(
        origemBackup: _origem!,
        destino: _destino!,
        aoProgresso: (arquivos, total, percentual) {
          if (!mounted) return;
          setState(() {
            _bytesLidos = arquivos;
            _bytesTotal = total;
            _progresso = percentual;
          });
        },
      );
      if (!mounted) return;
      setState(() => _processando = false);
      _mostrarResultado(
        'Restauração concluída',
        '${resultado.quantidade} arquivo(s) restaurado(s).',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processando = false;
        _mensagemErro = 'Falha na restauração: $e';
      });
    }
  }

  void _mostrarResultado(String titulo, String mensagem) {
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

  Future<void> _abrirConfiguracoes() async {
    var config = _config;
    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Configurações de backup'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Ativar backup'),
                  value: config.habilitado,
                  activeColor: const Color(0xFF4169E1),
                  onChanged: (v) => setLocalState(
                    () => config = ConfigBackup(
                      habilitado: v,
                      intervaloHoras: config.intervaloHoras,
                      subpasta: config.subpasta,
                      tiposArquivo: config.tiposArquivo,
                    ),
                  ),
                ),
                ListTile(
                  title: const Text('Intervalo (horas)'),
                  trailing: Text('${config.intervaloHoras}'),
                ),
                Slider(
                  value: config.intervaloHoras.toDouble(),
                  min: 1,
                  max: 24,
                  divisions: 23,
                  activeColor: const Color(0xFF4169E1),
                  onChanged: (v) => setLocalState(
                    () => config = ConfigBackup(
                      habilitado: config.habilitado,
                      intervaloHoras: v.round(),
                      subpasta: config.subpasta,
                      tiposArquivo: config.tiposArquivo,
                    ),
                  ),
                ),
                TextField(
                  controller: _subpastaController,
                  decoration: const InputDecoration(labelText: 'Subpasta'),
                  onChanged: (v) => config = ConfigBackup(
                    habilitado: config.habilitado,
                    intervaloHoras: config.intervaloHoras,
                    subpasta: v,
                    tiposArquivo: config.tiposArquivo,
                  ),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Tipos de arquivo:'),
                ),
                for (final tipo in const [
                  'Fotos',
                  'Músicas',
                  'Filmes',
                  'Documentos',
                ])
                  CheckboxListTile(
                    dense: true,
                    title: Text(tipo),
                    value: config.tiposArquivo.contains(tipo),
                    activeColor: const Color(0xFF4169E1),
                    onChanged: (v) => setLocalState(() {
                      final tipos = [...config.tiposArquivo];
                      if (v == true) {
                        if (!tipos.contains(tipo)) tipos.add(tipo);
                      } else {
                        tipos.remove(tipo);
                      }
                      config = ConfigBackup(
                        habilitado: config.habilitado,
                        intervaloHoras: config.intervaloHoras,
                        subpasta: config.subpasta,
                        tiposArquivo: tipos,
                      );
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (resultado == true) {
      await ServicoBackup.salvarConfig(config);
      if (!mounted) return;
      setState(() => _config = config);
    }
  }

  Future<void> _usarPastasPadrao() async {
    final docs = await getApplicationDocumentsDirectory();
    if (!mounted) return;
    setState(() {
      _origem = docs.path;
      _destino = '/storage/emulated/0/Download';
    });
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
                      const TituloCard('Backup de dados', icone: Icons.backup),
                      const SizedBox(height: 12),
                      _campoPasta(
                        rotulo: 'Origem:',
                        valor: _origem,
                        onSelecionar: _selecionarOrigem,
                      ),
                      const SizedBox(height: 8),
                      _campoPasta(
                        rotulo: 'Destino:',
                        valor: _destino,
                        onSelecionar: _selecionarDestino,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: BotaoAzul(
                              rotulo: 'BACKUP',
                              icon: Icons.cloud_upload,
                              onPressed: _executarBackup,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: BotaoAzul(
                              rotulo: 'RESTAURAR',
                              icon: Icons.cloud_download,
                              onPressed: _restaurar,
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
                      const TituloCard('Configurações', icone: Icons.settings),
                      const SizedBox(height: 8),
                      Text(
                        'Habilitado: '
                        '${_config.habilitado ? 'Sim' : 'Não'}\n'
                        'Intervalo: ${_config.intervaloHoras} hora(s)\n'
                        'Subpasta: ${_config.subpasta}\n'
                        'Tipos: ${_config.tiposArquivo.join(', ')}',
                        style: const TextStyle(
                          color: Color(0xFF8E9FAE),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: BotaoAzul(
                              rotulo: 'CONFIGURAR',
                              icon: Icons.tune,
                              onPressed: _abrirConfiguracoes,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: BotaoAzul(
                              rotulo: 'PASTAS PADRÃO',
                              icon: Icons.folder,
                              onPressed: _usarPastasPadrao,
                            ),
                          ),
                        ],
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

  Widget _campoPasta({
    required String rotulo,
    required String? valor,
    required VoidCallback onSelecionar,
  }) {
    return Row(
      children: [
        Text(
          rotulo,
          style: const TextStyle(color: Color(0xFF8E9FAE), fontSize: 13),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            valor ?? 'Não selecionado',
            style: const TextStyle(color: Colors.white, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        BotaoAzul(rotulo: 'SELECIONAR', onPressed: onSelecionar),
      ],
    );
  }
}