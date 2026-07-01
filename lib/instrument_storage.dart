import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'instrument_model.dart';

class InstrumentStorage {
  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/instruments.json');
  }

  static Future<List<InstrumentModel>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      return InstrumentModel.listFromJson(content);
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<InstrumentModel> instruments) async {
    final file = await _file();
    await file.writeAsString(InstrumentModel.listToJson(instruments));
  }

  static Future<void> add(InstrumentModel instrument) async {
    final list = await load();
    list.add(instrument);
    await save(list);
  }

  static Future<void> update(InstrumentModel instrument) async {
    final list = await load();
    final idx = list.indexWhere((i) => i.id == instrument.id);
    if (idx >= 0) {
      list[idx] = instrument;
      await save(list);
    }
  }

  static Future<void> delete(String id) async {
    final list = await load();
    list.removeWhere((i) => i.id == id);
    await save(list);
  }

  static String generateId() =>
      DateTime.now().millisecondsSinceEpoch.toString();
}
