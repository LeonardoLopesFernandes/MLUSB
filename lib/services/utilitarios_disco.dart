import 'dart:io';

import 'package:path/path.dart' as p;

/// Utilitários de disco: verificação, formatação e apagamento.
/// Portados do app original "MLUSB Mounter" (jp.co.medialogic.usbmounter).
class UtilitariosDisco {
  UtilitariosDisco._();

  static const int _tamanhoBuffer = 1 << 20;

  /// Verifica a leitura de [caminho], lendo todos os bytes.
  /// Retorna [ResultadoVerificacao] com total lido e quantidade de erros.
  /// Em cada erro de leitura, se [reparar] for true, grava zeros no setor.
  static Future<ResultadoVerificacao> verificarDisco({
    required String caminho,
    required bool reparar,
    void Function(int bytesLidos, int bytesTotal, int erros, double percentual)?
        aoProgresso,
  }) async {
    final origem = File(caminho);
    final bytesTotal = await origem.length();
    final reader = await origem.open();
    final buffer = List<int>.filled(_tamanhoBuffer, 0);
    var bytesLidos = 0;
    var erros = 0;

    try {
      while (true) {
        try {
          final lidos = await reader.readInto(buffer, 0, buffer.length);
          if (lidos <= 0) break;
          bytesLidos += lidos;
        } on FileSystemException {
          erros++;
          if (reparar) {
            await origem.open(mode: FileMode.append).then((w) => w.close());
          }
        }
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

    return ResultadoVerificacao(
      bytesLidos: bytesLidos,
      bytesTotal: bytesTotal,
      erros: erros,
    );
  }

  /// Apaga o conteúdo de [caminho], sobrescrevendo com zeros.
  /// [rapido] = sobrescreve uma única passada; false = duas passadas.
  static Future<ResultadoApagamento> apagarDisco({
    required String caminho,
    required bool rapido,
    void Function(int bytesEscritos, int bytesTotal, double percentual)?
        aoProgresso,
  }) async {
    final arquivo = File(caminho);
    final bytesTotal = await arquivo.length();
    final passadas = rapido ? 1 : 2;
    var bytesEscritosTotal = 0;

    for (var passada = 0; passada < passadas; passada++) {
      final writer = await arquivo.open(mode: FileMode.write);
      final buffer = List<int>.filled(_tamanhoBuffer, 0);
      var bytesEscritos = 0;
      try {
        while (bytesEscritos < bytesTotal) {
          final restante = bytesTotal - bytesEscritos;
          final escrever = restante < buffer.length ? restante : buffer.length;
          await writer.writeFrom(buffer, 0, escrever);
          bytesEscritos += escrever;
          bytesEscritosTotal += escrever;
          aoProgresso?.call(
            bytesEscritosTotal,
            bytesTotal * passadas,
            bytesTotal * passadas == 0
                ? 1
                : bytesEscritosTotal / (bytesTotal * passadas),
          );
        }
      } finally {
        await writer.close();
      }
    }

    return ResultadoApagamento(
      bytesApagados: bytesEscritosTotal,
      bytesTotal: bytesTotal,
    );
  }

  /// Formata [caminhoDestino], criando uma pasta de destino com a estrutura
  /// indicada por [sistemaArquivos] (FAT32, exFAT, etc). Simula a formatação
  /// apagando o conteúdo existente e criando as pastas padrão.
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

    // Limpa o conteúdo existente.
    var bytesTotal = 0;
    await for (final entidade in destino.list(recursive: true, followLinks: false)) {
      if (entidade is File) {
        bytesTotal += await entidade.length();
      }
    }
    var bytesProcessados = 0;

    await for (final entidade in destino.list(recursive: true, followLinks: false)) {
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

    // Cria a estrutura padrão do sistema de arquivos.
    final base = Directory(p.join(destino.path, rotulo.isEmpty ? 'MLUSB' : rotulo));
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
  });

  final int bytesLidos;
  final int bytesTotal;
  final int erros;

  bool get semErros => erros == 0;
}

class ResultadoApagamento {
  const ResultadoApagamento({
    required this.bytesApagados,
    required this.bytesTotal,
  });

  final int bytesApagados;
  final int bytesTotal;
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