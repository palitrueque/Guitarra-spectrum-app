import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'analysis/analysis_screen.dart';
import 'compare_screen.dart';
import 'instruments_list_screen.dart';
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
  bool _isComparing = false;
  final Set<String> _selectedPaths = {};
  static const int _maxCompare = 5;

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

  void _toggleCompareMode() {
    setState(() {
      _isComparing = !_isComparing;
      _selectedPaths.clear();
    });
  }

  void _toggleSelected(RecordingInfo info) {
    setState(() {
      final path = info.file.path;
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        if (_selectedPaths.length >= _maxCompare) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Maximo $_maxCompare grabaciones a la vez')),
          );
          return;
        }
        _selectedPaths.add(path);
      }
    });
  }

  void _openCompare() {
    final selected = _recordings
        .where((r) => _selectedPaths.contains(r.file.path))
        .toList();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CompareScreen(
          wavPaths: selected.map((r) => r.file.path).toList(),
          names: selected.map((r) => r.name).toList(),
        ),
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
        title: Text(_isComparing
            ? 'Selecciona hasta $_maxCompare (${_selectedPaths.length})'
            : 'Guitarra Spectrum'),
        centerTitle: true,
      ),
      body: _buildBody(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: _isComparing ? _buildComparingBar() : _buildNormalBar(),
        ),
      ),
    );
  }

  Widget _buildNormalBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Boton Grabar centrado y destacado
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _openRecorder,
            icon: const Icon(Icons.fiber_manual_record),
            label: const Text('Grabar'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 7),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Fila de 3 botones secundarios
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _toggleCompareMode,
                icon: const Icon(Icons.compare_arrows, size: 18),
                label: const Text('Comparar'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _importFile,
                icon: const Icon(Icons.file_upload_outlined, size: 18),
                label: const Text('Importar'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const InstrumentsListScreen(),
                  ),
                ),
                icon: const Icon(Icons.library_books_outlined, size: 18),
                label: const Text('Fichas'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildComparingBar() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _toggleCompareMode,
            icon: const Icon(Icons.close),
            label: const Text('Cancelar'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: _selectedPaths.length >= 2 ? _openCompare : null,
            icon: const Icon(Icons.bar_chart),
            label: Text('Comparar (${_selectedPaths.length})'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
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
          final isSelected = _selectedPaths.contains(info.file.path);
          return ListTile(
            leading: _isComparing
                ? Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleSelected(info),
                  )
                : const Icon(Icons.audiotrack),
            title: Text(info.name),
            subtitle: Text(
              '${DateFormat('dd/MM/yyyy HH:mm').format(info.modified)}  '
              '|  ${(info.sizeBytes / 1024).toStringAsFixed(1)} KB',
            ),
            onTap: _isComparing
                ? () => _toggleSelected(info)
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            AnalysisScreen(wavFilePath: info.file.path),
                      ),
                    );
                  },
            trailing: _isComparing
                ? null
                : PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'share') _share(info);
                      if (value == 'rename') _rename(info);
                      if (value == 'delete') _delete(info);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                          value: 'share', child: Text('Compartir')),
                      const PopupMenuItem(
                          value: 'rename', child: Text('Renombrar')),
                      const PopupMenuItem(
                          value: 'delete', child: Text('Borrar')),
                    ],
                  ),
          );
        },
      ),
    );
  }
}
