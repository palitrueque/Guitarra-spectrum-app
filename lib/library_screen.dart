import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'analysis/analysis_screen.dart';
import 'recorder_screen.dart';
import 'recording_storage.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<RecordingInfo> _recordings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final recordings = await RecordingStorage.listRecordings();
    setState(() {
      _recordings = recordings;
      _isLoading = false;
    });
  }

  Future<void> _openRecorder() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const RecorderScreen()),
    );
    if (saved == true) {
      _load();
    }
  }

  Future<void> _importFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav'],
    );
    if (result == null || result.files.isEmpty) return;

    final pickedPath = result.files.single.path;
    if (pickedPath == null) return;

    final suggestedName = result.files.single.name.replaceAll('.wav', '');
    if (!mounted) return;

    final name = await _askForName(
      title: 'Importar grabacion',
      initialValue: suggestedName,
    );
    if (name == null) return;

    await RecordingStorage.importFile(pickedPath, name);
    _load();
  }

  Future<String?> _askForName({
    required String title,
    required String initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(RecordingInfo info) async {
    final newName = await _askForName(
      title: 'Renombrar grabacion',
      initialValue: info.name,
    );
    if (newName == null || newName.trim() == info.name) return;
    await RecordingStorage.renameRecording(info.file, newName);
    _load();
  }

  Future<void> _share(RecordingInfo info) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(info.file.path)],
        text: 'Grabacion: ${info.name}',
      ),
    );
  }

  Future<void> _delete(RecordingInfo info) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar grabacion'),
        content: Text('¿Seguro que quieres borrar "${info.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await RecordingStorage.deleteRecording(info.file);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guitarra Spectrum'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _importFile,
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Importar archivo .wav',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRecorder,
        icon: const Icon(Icons.fiber_manual_record),
        label: const Text('Grabar'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_recordings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.library_music_outlined,
                  size: 72, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Aun no tienes grabaciones',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Pulsa "Grabar" para crear tu primera grabacion, '
                'o importa un archivo .wav existente.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _recordings.length,
        itemBuilder: (context, index) {
          final info = _recordings[index];
          return ListTile(
            leading: const Icon(Icons.audiotrack),
            title: Text(info.name),
            subtitle: Text(
              '${DateFormat('dd/MM/yyyy HH:mm').format(info.modified)}  '
              '|  ${(info.sizeBytes / 1024).toStringAsFixed(1)} KB',
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AnalysisScreen(wavFilePath: info.file.path),
                ),
              );
            },
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'share') _share(info);
                if (value == 'rename') _rename(info);
                if (value == 'delete') _delete(info);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'share', child: Text('Compartir')),
                const PopupMenuItem(value: 'rename', child: Text('Renombrar')),
                const PopupMenuItem(value: 'delete', child: Text('Borrar')),
              ],
            ),
          );
        },
      ),
    );
  }
}
