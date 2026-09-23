import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Utilitário para solicitar permissões de armazenamento.
class PermissaoUtils {
  PermissaoUtils._();

  /// Solicita acesso de escrita ao armazenamento.
  /// No Android 11+ (API 30) usa "Todos os arquivos" (MANAGE_EXTERNAL_STORAGE).
  static Future<bool> solicitarAcessoArmazenamento() async {
    if (!Platform.isAndroid) return true;

    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }

    final status = await Permission.manageExternalStorage.request();
    return status.isGranted;
  }

  /// Retorna true se o app já tem acesso de escrita ao armazenamento.
  static Future<bool> temAcessoArmazenamento() async {
    if (!Platform.isAndroid) return true;
    return Permission.manageExternalStorage.isGranted;
  }
}