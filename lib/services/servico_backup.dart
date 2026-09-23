import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Serviço de backup e restauração de dados.
/// Portado do app original "MLUSB Mounter" (Auto Backup).
class ServicoBackup {
  ServicoBackup._();

  static const _chaveIntervalo = 'mlusb_backup_intervalo';
  static const _chaveHabilitado = 'mlusb_backup_habilitado';
  static const _chaveSubpasta = 'mlusb_backup_subpasta';
  static const _chaveTiposArquivo = 'mlusb_backup_tipos';

  /// Obtém as configurações de backup salvas.
  static Future<ConfigBackup> obterConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return ConfigBackup(
      habilitado: prefs.getBool(_chaveHabilitado) ?? false,
      intervaloHoras: prefs.getInt(_chaveIntervalo) ?? 1,
      subpasta: prefs.getString(_chaveSubpasta) ?? 'MLUSB',
      tiposArquivo: prefs.getStringList(_chaveTiposArquivo) ??
          ['Fotos', 'Músicas', 'Filmes', 'Documentos'],
    );
  }

  /// Salva as configurações de backup.
  static Future<void> salvarConfig(ConfigBackup config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chaveHabilitado, config.habilitado);
    await prefs.setInt(_chaveIntervalo, config.intervaloHoras);
    await prefs.setString(_chaveSubpasta, config.subpasta);
    await prefs.setStringList(_chaveTiposArquivo, config.tiposArquivo);
  }

  /// Executa o backup dos arquivos de [origem] para [destino],
  /// filtrando pelos [tiposArquivo] selecionados.
  static Future<ResultadoBackup> executarBackup({
    required String origem,
    required String destino,
    required ConfigBackup config,
    void Function(int arquivos, int total, double percentual)? aoProgresso,
  }) async {
    final origemDir = Directory(origem);
    final destinoBase = Directory(destino);
    if (!await origemDir.exists()) {
      throw const FormatException('A pasta de origem não foi encontrada.');
    }
    await destinoBase.create(recursive: true);

    final destinoBackup = Directory(p.join(destinoBase.path, config.subpasta));
    await destinoBackup.create(recursive: true);

    // Coleta os arquivos compatíveis.
    final arquivos = <File>[];
    await for (final entidade
        in origemDir.list(recursive: true, followLinks: false)) {
      if (entidade is File && _arquivoCompativel(entidade, config.tiposArquivo)) {
        arquivos.add(entidade);
      }
    }

    var processados = 0;
    final copiados = <String>[];
    for (final arquivo in arquivos) {
      final relativo = p.relative(arquivo.path, from: origemDir.path);
      final novoCaminho = p.join(destinoBackup.path, relativo);
      await File(novoCaminho).parent.create(recursive: true);
      await arquivo.copy(novoCaminho);
      copiados.add(novoCaminho);
      processados++;
      aoProgresso?.call(
        processados,
        arquivos.length,
        arquivos.isEmpty ? 1 : processados / arquivos.length,
      );
    }

    return ResultadoBackup(
      arquivosCopiados: copiados,
      quantidade: copiados.length,
    );
  }

  /// Restaura os arquivos de [origemBackup] para [destino],
  /// mantendo a estrutura de pastas relativa.
  static Future<ResultadoRestauracao> restaurarBackup({
    required String origemBackup,
    required String destino,
    void Function(int arquivos, int total, double percentual)? aoProgresso,
  }) async {
    final origemDir = Directory(origemBackup);
    final destinoDir = Directory(destino);
    if (!await origemDir.exists()) {
      throw const FormatException('A pasta de backup não foi encontrada.');
    }
    await destinoDir.create(recursive: true);

    final arquivos = <File>[];
    await for (final entidade
        in origemDir.list(recursive: true, followLinks: false)) {
      if (entidade is File) arquivos.add(entidade);
    }

    var processados = 0;
    final restaurados = <String>[];
    for (final arquivo in arquivos) {
      final relativo = p.relative(arquivo.path, from: origemDir.path);
      final novoCaminho = p.join(destinoDir.path, relativo);
      await File(novoCaminho).parent.create(recursive: true);
      await arquivo.copy(novoCaminho);
      restaurados.add(novoCaminho);
      processados++;
      aoProgresso?.call(
        processados,
        arquivos.length,
        arquivos.isEmpty ? 1 : processados / arquivos.length,
      );
    }

    return ResultadoRestauracao(
      arquivosRestaurados: restaurados,
      quantidade: restaurados.length,
    );
  }

  static bool _arquivoCompativel(File arquivo, List<String> tipos) {
    final extensao = p.extension(arquivo.path).toLowerCase();
    for (final tipo in tipos) {
      switch (tipo) {
        case 'Fotos':
          if (['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp']
              .contains(extensao)) {
            return true;
          }
          break;
        case 'Músicas':
          if (['.mp3', '.wav', '.flac', '.aac', '.ogg', '.m4a']
              .contains(extensao)) {
            return true;
          }
          break;
        case 'Filmes':
          if (['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.mts', '.3gp']
              .contains(extensao)) {
            return true;
          }
          break;
        case 'Documentos':
          if (['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
                  '.txt', '.csv', '.iso']
              .contains(extensao)) {
            return true;
          }
          break;
      }
    }
    return false;
  }
}

class ConfigBackup {
  const ConfigBackup({
    required this.habilitado,
    required this.intervaloHoras,
    required this.subpasta,
    required this.tiposArquivo,
  });

  final bool habilitado;
  final int intervaloHoras;
  final String subpasta;
  final List<String> tiposArquivo;
}

class ResultadoBackup {
  const ResultadoBackup({
    required this.arquivosCopiados,
    required this.quantidade,
  });

  final List<String> arquivosCopiados;
  final int quantidade;
}

class ResultadoRestauracao {
  const ResultadoRestauracao({
    required this.arquivosRestaurados,
    required this.quantidade,
  });

  final List<String> arquivosRestaurados;
  final int quantidade;
}