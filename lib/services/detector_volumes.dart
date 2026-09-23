import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Representa um volume/dispositivo de armazenamento montado.
class VolumeArmazenamento {
  const VolumeArmazenamento({
    required this.caminho,
    required this.nome,
    required this.removivel,
    required this.tipo,
  });

  final String caminho;
  final String nome;
  final bool removivel;
  final String tipo; // 'interno', 'sdcard', 'usb', 'webdav'

  String get rotulo {
    switch (tipo) {
      case 'sdcard':
        return 'Cartão SD';
      case 'usb':
        return 'USB';
      case 'webdav':
        return 'WebDAV';
      default:
        return 'Armazenamento interno';
    }
  }

  @override
  bool operator ==(Object other) =>
      other is VolumeArmazenamento && other.caminho == caminho;

  @override
  int get hashCode => caminho.hashCode;
}

/// Detecta os volumes de armazenamento disponíveis no dispositivo.
/// Lista /storage (para cartão SD e USB OTG montados) e o armazenamento interno.
class DetectorVolumes {
  DetectorVolumes._();

  static const List<String> _ignorar = ['emulated', 'self'];

  /// Obtém o armazenamento interno.
  static Future<VolumeArmazenamento> _armazenamentoInterno() async {
    String caminho = '/storage/emulated/0';
    try {
      final dirs = await getExternalStorageDirectories();
      if (dirs?.isNotEmpty == true) {
        caminho = dirs!.first.path;
      }
    } catch (_) {
      // Em ambiente de teste ou sem suporte, usa o caminho padrão.
    }
    return VolumeArmazenamento(
      caminho: caminho,
      nome: 'Armazenamento interno',
      removivel: false,
      tipo: 'interno',
    );
  }

  /// Lista os volumes em /storage (microSD, USB OTG).
  static Future<List<VolumeArmazenamento>> _volumesEmStorage() async {
    final volumes = <VolumeArmazenamento>[];
    try {
      final storage = Directory('/storage');
      if (!await storage.exists()) return volumes;
      final entradas = await storage.list(followLinks: false).toList();
      for (final entidade in entradas) {
        if (entidade is! Directory) continue;
        final nome = entidade.path.split('/').last;
        if (_ignorar.contains(nome)) continue;
        if (nome == '0') continue;

        final tipo = nome.length == 4 || nome.contains('-')
            ? 'sdcard'
            : nome.toUpperCase().contains('USB')
                ? 'usb'
                : 'sdcard';
        volumes.add(VolumeArmazenamento(
          caminho: entidade.path,
          nome: nome,
          removivel: true,
          tipo: tipo,
        ));
      }
    } catch (_) {}
    return volumes;
  }

  /// Lista todos os volumes: interno + removíveis (SD/USB via OTG).
  static Future<List<VolumeArmazenamento>> listarVolumes() async {
    final volumes = <VolumeArmazenamento>[];
    volumes.add(await _armazenamentoInterno());
    volumes.addAll(await _volumesEmStorage());
    return volumes;
  }
}