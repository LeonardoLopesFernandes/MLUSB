import 'dart:io';

import 'package:path/path.dart' as p;

/// Operações do gerenciador de arquivos.
class GerenciadorArquivos {
  GerenciadorArquivos._();

  /// Lista as entidades (arquivos/pastas) de [caminho] ordenadas
  /// (pastas primeiro, depois arquivos, ambos alfabeticamente).
  static Future<List<FileSystemEntity>> listar(String caminho) async {
    final dir = Directory(caminho);
    if (!await dir.exists()) return [];
    final entidades = await dir.list(followLinks: false).toList();
    entidades.sort((a, b) {
      final aDir = a is Directory;
      final bDir = b is Directory;
      if (aDir != bDir) return aDir ? -1 : 1;
      return a.path.toLowerCase().compareTo(b.path.toLowerCase());
    });
    return entidades;
  }

  /// Copia [origem] para [destino].
  static Future<void> copiar({
    required String origem,
    required String destino,
    void Function(int bytesLidos, int bytesTotal, double percentual)? aoProgresso,
  }) async {
    final origemFile = File(origem);
    final destinoFile = File(destino);
    final bytesTotal = await origemFile.length();
    if (await destinoFile.exists()) {
      throw const FormatException('O arquivo de destino já existe.');
    }
    await destinoFile.parent.create(recursive: true);
    await origemFile.copy(destinoFile.path);
    aoProgresso?.call(bytesTotal, bytesTotal, 1);
  }

  /// Copia recursivamente uma pasta [origem] para [destino].
  static Future<void> copiarPasta({
    required String origem,
    required String destino,
    void Function(int bytesLidos, int bytesTotal, double percentual)? aoProgresso,
  }) async {
    final origemDir = Directory(origem);
    final destinoDir = Directory(destino);
    await destinoDir.create(recursive: true);

    var bytesTotal = 0;
    await for (final entidade
        in origemDir.list(recursive: true, followLinks: false)) {
      if (entidade is File) {
        bytesTotal += await entidade.length();
      }
    }

    var bytesLidos = 0;
    await for (final entidade
        in origemDir.list(recursive: true, followLinks: false)) {
      final relativo = p.relative(entidade.path, from: origemDir.path);
      final novoCaminho = p.join(destinoDir.path, relativo);
      if (entidade is Directory) {
        await Directory(novoCaminho).create(recursive: true);
      } else if (entidade is File) {
        await File(novoCaminho).parent.create(recursive: true);
        await entidade.copy(novoCaminho);
        bytesLidos += await entidade.length();
        aoProgresso?.call(
          bytesLidos,
          bytesTotal,
          bytesTotal == 0 ? 1 : bytesLidos / bytesTotal,
        );
      }
    }
  }

  /// Exclui [caminho] (arquivo ou pasta recursivamente).
  static Future<void> excluir(String caminho) async {
    final entidade = FileSystemEntity.typeSync(caminho);
    if (entidade == FileSystemEntityType.directory) {
      await Directory(caminho).delete(recursive: true);
    } else if (entidade == FileSystemEntityType.file) {
      await File(caminho).delete();
    }
  }

  /// Renomeia [origem] para [destino].
  static Future<void> renomear(String origem, String destino) async {
    final destinoExiste = FileSystemEntity.typeSync(destino) !=
        FileSystemEntityType.notFound;
    if (destinoExiste) {
      throw const FormatException('Já existe um item com esse nome.');
    }
    final entidade = FileSystemEntity.typeSync(origem);
    if (entidade == FileSystemEntityType.directory) {
      await Directory(origem).rename(destino);
    } else if (entidade == FileSystemEntityType.file) {
      await File(origem).rename(destino);
    } else {
      throw const FormatException('Item não encontrado.');
    }
  }

  /// Cria uma nova pasta em [caminhoPai] com [nome].
  static Future<String> novaPasta(String caminhoPai, String nome) async {
    final nova = Directory(p.join(caminhoPai, nome));
    if (await nova.exists()) {
      throw const FormatException('Já existe uma pasta com esse nome.');
    }
    await nova.create();
    return nova.path;
  }

  /// Formata o tamanho em bytes para exibição.
  static String formatarBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Formata a data de modificação.
  static String formatarData(FileSystemEntity entidade) {
    final data = entidade.statSync().modified;
    String doisDigitos(int v) => v.toString().padLeft(2, '0');
    return '${doisDigitos(data.day)}/${doisDigitos(data.month)}/'
        '${data.year} ${doisDigitos(data.hour)}:'
        '${doisDigitos(data.minute)}:${doisDigitos(data.second)}';
  }
}