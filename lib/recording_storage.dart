import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Informacion de una grabacion guardada en la biblioteca.
class RecordingInfo {
  final File file;
  final String name; // nombre sin extension, elegido por el usuario
  final DateTime modified;
  final int sizeBytes;

  RecordingInfo({
    required this.file,
    required this.name,
    required this.modified,
    required this.sizeBytes,
  });
}

/// Gestiona la carpeta "recordings" donde se guardan las grabaciones:
/// guardar grabaciones nuevas con un nombre elegido por el usuario,
/// listar la biblioteca, importar archivos .wav externos, renombrar y
/// borrar.
class RecordingStorage {
  static Future<Directory> recordingsDir() async {
    Directory base;
    if (!kIsWeb && Platform.isAndroid) {
      // Carpeta especifica de la app en el almacenamiento EXTERNO
      // (visible con cualquier explorador de archivos en
      // Android/data/<paquete>/files/recordings), a diferencia del
      // almacenamiento interno privado que no se puede ver sin ADB.
      final external = await getExternalStorageDirectory();
      base = external ?? await getApplicationDocumentsDirectory();
    } else {
      // iOS no tiene almacenamiento externo publico; usamos la carpeta
      // de Documentos de la app (visible en la app Archivos si se
      // habilita "compartir archivos", configuracion aparte).
      base = await getApplicationDocumentsDirectory();
    }
    final dir = Directory('${base.path}/recordings');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Limpia un nombre elegido por el usuario para que sea un nombre de
  /// archivo valido (solo letras, numeros, espacios, guiones).
  static String sanitizeFileName(String input) {
    final trimmed = input.trim();
    final cleaned = trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9 _\-]'), '');
    return cleaned.isEmpty ? 'grabacion' : cleaned;
  }

  static Future<String> _uniquePath(Directory dir, String desiredName) async {
    final base = sanitizeFileName(desiredName);
    String candidate = '$base.wav';
    int counter = 1;
    while (await File('${dir.path}/$candidate').exists()) {
      candidate = '${base}_$counter.wav';
      counter++;
    }
    return '${dir.path}/$candidate';
  }

  /// Mueve un archivo recien grabado (en una ubicacion temporal) a la
  /// carpeta de la biblioteca, con el nombre elegido por el usuario.
  static Future<File> saveRecording(File tempFile, String desiredName) async {
    final dir = await recordingsDir();
    final destPath = await _uniquePath(dir, desiredName);
    final saved = await tempFile.copy(destPath);
    try {
      await tempFile.delete();
    } catch (_) {
      // No pasa nada si no se puede borrar el temporal.
    }
    return saved;
  }

  /// Copia un archivo .wav externo (elegido con el selector de archivos
  /// del sistema) dentro de la biblioteca de la app.
  static Future<File> importFile(String sourcePath, String desiredName) async {
    final dir = await recordingsDir();
    final destPath = await _uniquePath(dir, desiredName);
    return await File(sourcePath).copy(destPath);
  }

  static Future<List<RecordingInfo>> listRecordings() async {
    final dir = await recordingsDir();
    if (!await dir.exists()) return [];

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.wav'))
        .toList();

    final infos = <RecordingInfo>[];
    for (final f in files) {
      final stat = await f.stat();
      final fileName = f.path.split(Platform.pathSeparator).last;
      final name = fileName.endsWith('.wav')
          ? fileName.substring(0, fileName.length - 4)
          : fileName;
      infos.add(RecordingInfo(
        file: f,
        name: name,
        modified: stat.modified,
        sizeBytes: stat.size,
      ));
    }

    infos.sort((a, b) => b.modified.compareTo(a.modified));
    return infos;
  }

  static Future<void> deleteRecording(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<File> renameRecording(File file, String newName) async {
    final dir = file.parent;
    final destPath = await _uniquePath(dir, newName);
    return await file.rename(destPath);
  }
}
