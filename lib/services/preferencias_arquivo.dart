import 'package:shared_preferences/shared_preferences.dart';

/// Modos de exibição do gerenciador de arquivos.
enum ModoExibicao { lista, detalhes, icones }

/// Preferências do gerenciador de arquivos (modo de exibição, fonte,
/// ordenação, filtro de tipo).
class PreferenciasArquivo {
  PreferenciasArquivo._();

  static const _chaveModo = 'mlusb_modo_exibicao';
  static const _chaveFonte = 'mlusb_tamanho_fonte';
  static const _chaveOrdenacao = 'mlusb_ordenacao';
  static const _chaveDecrescente = 'mlusb_ordenacao_desc';
  static const _chaveFiltro = 'mlusb_filtro_tipo';

  /// Obtém o modo de exibição salvo.
  static Future<ModoExibicao> obterModo() async {
    final prefs = await SharedPreferences.getInstance();
    final indice = prefs.getInt(_chaveModo) ?? 0;
    return ModoExibicao.values[indice];
  }

  static Future<void> salvarModo(ModoExibicao modo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_chaveModo, modo.index);
  }

  /// Obtém o tamanho da fonte salvo (padrão: 14).
  static Future<double> obterTamanhoFonte() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getDouble(_chaveFonte) ?? 14).toDouble();
  }

  static Future<void> salvarTamanhoFonte(double tamanho) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_chaveFonte, tamanho);
  }

  /// Critério de ordenação: 'nome', 'tamanho' ou 'data'.
  static Future<String> obterOrdenacao() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_chaveOrdenacao) ?? 'nome';
  }

  static Future<bool> obterDecrescente() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_chaveDecrescente) ?? false;
  }

  static Future<void> salvarOrdenacao(
      String criterio, bool decrescente) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveOrdenacao, criterio);
    await prefs.setBool(_chaveDecrescente, decrescente);
  }

  /// Filtro de tipo: 'todos', 'audio', 'video', 'imagem', 'iso', 'documento'.
  static Future<String> obterFiltro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_chaveFiltro) ?? 'todos';
  }

  static Future<void> salvarFiltro(String filtro) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveFiltro, filtro);
  }

  /// Aplica [filtro] em [nome], verificando a extensão.
  static bool correspondeFiltro(String nome, String filtro) {
    if (filtro == 'todos') return true;
    final ext = nome.split('.').last.toLowerCase();
    switch (filtro) {
      case 'audio':
        return const ['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a']
            .contains(ext);
      case 'video':
        return const ['mp4', 'mkv', 'avi', 'mov', 'wmv', 'mts', '3gp']
            .contains(ext);
      case 'imagem':
        return const ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp']
            .contains(ext);
      case 'iso':
        return const ['iso', 'img', 'cue', 'bin'].contains(ext);
      case 'documento':
        return const [
              'pdf',
              'doc',
              'docx',
              'xls',
              'xlsx',
              'ppt',
              'pptx',
              'txt',
              'csv',
            ]
            .contains(ext);
      default:
        return true;
    }
  }
}