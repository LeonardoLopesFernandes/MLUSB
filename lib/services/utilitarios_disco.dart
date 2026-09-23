import 'dart:io';

import 'package:path/path.dart' as p;

/// Utilitários de disco: verificação, formatação e apagamento.
/// Portados do app original "MLUSB Mounter" (jp.co.medialogic.usbmounter).
/// Atuam sobre a pasta/dispositivo selecionado (emulando o volume).
class UtilitariosDisco {
  UtilitariosDisco._();

  static const int _tamanhoBuffer = 1 << 20;

  /// Lista recursivamente todos os arquivos de [caminho].
  static Future<List<File>> _listarArquivos(String caminho) async {
    final dir = Directory(caminho);
    final arquivos = <File>[];
    await for (final entidade
        in dir.list(recursive: true, followLinks: false)) {
      if (entidade is File) arquivos.add(entidade);
    }
    return arquivos;
  }

  /// Verifica a leitura de todos os arquivos de [caminho].
  /// Lê cada arquivo por completo; erros de leitura são contados e,
  /// se [reparar] for true, o setor/arquivo é sobrescrito com zeros.
  static Future<ResultadoVerificacao> verificarDisco({
    required String caminho,
    required bool reparar,
    void Function(int bytesLidos, int bytesTotal, int erros, double percentual)?
        aoProgresso,
  }) async {
    final dir = Directory(caminho);
    if (!await dir.exists()) {
      throw const FormatException('Pasta/dispositivo não encontrado.');
    }

    final arquivos = await _listarArquivos(caminho);
    var bytesTotal = 0;
    for (final f in arquivos) {
      bytesTotal += await f.length();
    }

    var bytesLidos = 0;
    var erros = 0;

    for (final arquivo in arquivos) {
      final reader = await arquivo.open();
      final buffer = List<int>.filled(_tamanhoBuffer, 0);
      try {
        while (true) {
          int lidos;
          try {
            lidos = await reader.readInto(buffer, 0, buffer.length);
          } on FileSystemException {
            erros++;
            lidos = -1;
          }
          if (lidos <= 0) break;
          bytesLidos += lidos;
          aoProgresso?.call(
            bytesLidos,
            bytesTotal,
            erros,
            bytesTotal == 0 ? 1 : bytesLidos / bytesTotal,
          );
        }
      } finally {
        await reader.close();
      }
      if (reparar && erros > 0) {
        // Sobrescreve o arquivo com problema para tentar recuperar o setor.
        try {
          await arquivo.writeAsBytes(List.filled(arquivo.lengthSync(), 0));
        } catch (_) {}
      }
    }

    return ResultadoVerificacao(
      bytesLidos: bytesLidos,
      bytesTotal: bytesTotal,
      erros: erros,
      arquivos: arquivos.length,
    );
  }

  /// Apaga o conteúdo de [caminho] (pasta/dispositivo), sobrescrevendo os
  /// arquivos com zeros antes de removê-los.
  /// [rapido] = sobrescreve uma única passada; false = duas passadas.
  static Future<ResultadoApagamento> apagarDisco({
    required String caminho,
    required bool rapido,
    void Function(int bytesEscritos, int bytesTotal, double percentual)?
        aoProgresso,
  }) async {
    final dir = Directory(caminho);
    if (!await dir.exists()) {
      throw const FormatException('Pasta/dispositivo não encontrado.');
    }

    final arquivos = await _listarArquivos(caminho);
    final passadas = rapido ? 1 : 2;
    var bytesTotal = 0;
    for (final f in arquivos) {
      bytesTotal += await f.length();
    }
    var bytesApagados = 0;

    for (var passada = 0; passada < passadas; passada++) {
      for (final arquivo in arquivos) {
        try {
          final tamanho = await arquivo.length();
          final writer = await arquivo.open(mode: FileMode.write);
          final buffer = List<int>.filled(_tamanhoBuffer, 0);
          var escrito = 0;
          try {
            while (escrito < tamanho) {
              final restante = tamanho - escrito;
              final escrever =
                  restante < buffer.length ? restante : buffer.length;
              await writer.writeFrom(buffer, 0, escrever);
              escrito += escrever;
              bytesApagados += escrever;
              aoProgresso?.call(
                bytesApagados,
                bytesTotal * passadas,
                bytesTotal * passadas == 0
                    ? 1
                    : bytesApagados / (bytesTotal * passadas),
              );
            }
          } finally {
            await writer.close();
          }
        } on FileSystemException {
          // Ignora arquivos que não podem ser sobrescritos.
        }
      }
    }

    // Remove o conteúdo após sobrescrever.
    try {
      for (final entidade in await dir.list(followLinks: false).toList()) {
        if (entidade is Directory) {
          await entidade.delete(recursive: true);
        } else if (entidade is File) {
          await entidade.delete();
        }
      }
    } on FileSystemException {
      // Pode não conseguir remover a pasta raiz; mantém o resultado.
    }

    return ResultadoApagamento(
      bytesApagados: bytesApagados,
      bytesTotal: bytesTotal,
      arquivos: arquivos.length,
    );
  }

  /// Formata [caminhoDestino] (pasta/dispositivo): apaga o conteúdo e cria
  /// a estrutura padrão com [rotulo] e as pastas DCIM/Movies/Music/Pictures.
  static Future<ResultadoFormatacao> formatarDisco({
    required String caminhoDestino,
    required String sistemaArquivos,
    required String rotulo,
    void Function(int bytesProcessados, int bytesTotal, double percentual)?
        aoProgresso,
  }) async {
    final destino = Directory(caminhoDestino);
    if (!await destino.exists()) {
      throw const FormatException('Pasta de destino não encontrada.');
    }

    // Conta o total de bytes.
    var bytesTotal = 0;
    await for (final entidade
        in destino.list(recursive: true, followLinks: false)) {
      if (entidade is File) bytesTotal += await entidade.length();
    }
    var bytesProcessados = 0;

    // Remove o conteúdo.
    await for (final entidade
        in destino.list(recursive: true, followLinks: false)) {
      try {
        if (entidade is File) {
          final tamanho = await entidade.length();
          await entidade.delete();
          bytesProcessados += tamanho;
          aoProgresso?.call(
            bytesProcessados,
            bytesTotal,
            bytesTotal == 0 ? 1 : bytesProcessados / bytesTotal,
          );
        }
      } on FileSystemException {
        // Ignora arquivos em uso.
      }
    }
    // Remove subpastas vazias restantes.
    final subpastas = await destino.list(recursive: true, followLinks: false).toList();
    for (final entidade in subpastas) {
      try {
        if (entidade is Directory) {
          await entidade.delete(recursive: true);
        }
      } on FileSystemException {
        // Ignora.
      }
    }

    // Cria a estrutura padrão do sistema de arquivos.
    final base =
        Directory(p.join(destino.path, rotulo.isEmpty ? 'MLUSB' : rotulo));
    await base.create(recursive: true);
    await Directory(p.join(base.path, 'DCIM')).create(recursive: true);
    await Directory(p.join(base.path, 'Movies')).create(recursive: true);
    await Directory(p.join(base.path, 'Music')).create(recursive: true);
    await Directory(p.join(base.path, 'Pictures')).create(recursive: true);

    return ResultadoFormatacao(
      sistemaArquivos: sistemaArquivos,
      rotulo: rotulo,
      bytesProcessados: bytesProcessados,
    );
  }

  static String formatarBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class ResultadoVerificacao {
  const ResultadoVerificacao({
    required this.bytesLidos,
    required this.bytesTotal,
    required this.erros,
    required this.arquivos,
  });

  final int bytesLidos;
  final int bytesTotal;
  final int erros;
  final int arquivos;

  bool get semErros => erros == 0;
}

class ResultadoApagamento {
  const ResultadoApagamento({
    required this.bytesApagados,
    required this.bytesTotal,
    required this.arquivos,
  });

  final int bytesApagados;
  final int bytesTotal;
  final int arquivos;
}

class ResultadoFormatacao {
  const ResultadoFormatacao({
    required this.sistemaArquivos,
    required this.rotulo,
    required this.bytesProcessados,
  });

  final String sistemaArquivos;
  final String rotulo;
  final int bytesProcessados;
}