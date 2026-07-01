import 'package:flutter/material.dart';

import 'instrument_model.dart';
import 'instrument_screen.dart';
import 'instrument_storage.dart';

class InstrumentsListScreen extends StatefulWidget {
  const InstrumentsListScreen({super.key});

  @override
  State<InstrumentsListScreen> createState() => _InstrumentsListScreenState();
}

class _InstrumentsListScreenState extends State<InstrumentsListScreen> {
  List<InstrumentModel> _instruments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final instruments = await InstrumentStorage.load();
    setState(() {
      _instruments = instruments;
      _isLoading = false;
    });
  }

  Future<void> _createNew() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva ficha'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre del instrumento',
            hintText: 'Ej: Guitarra clasica n°3',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(nameCtrl.text),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (name == null || name.trim().isEmpty) return;

    final instrument = InstrumentModel(
      id: InstrumentStorage.generateId(),
      name: name.trim(),
    );
    await InstrumentStorage.add(instrument);
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InstrumentScreen(instrument: instrument),
      ),
    );
    _load();
  }

  Future<void> _delete(InstrumentModel instrument) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar ficha'),
        content: Text('¿Seguro que quieres borrar "${instrument.name}"?'),
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
      await InstrumentStorage.delete(instrument.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fichas de instrumento'),
        centerTitle: true,
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNew,
        icon: const Icon(Icons.add),
        label: const Text('Nueva ficha'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_instruments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.library_books_outlined,
                  size: 72, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No tienes fichas todavia',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Crea una ficha por cada instrumento en construccion '
                'para registrar sus medidas y asociar grabaciones.',
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
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _instruments.length,
        itemBuilder: (context, index) {
          final inst = _instruments[index];
          final density = inst.densityGcm3;
          return ListTile(
            leading: const Icon(Icons.library_books),
            title: Text(inst.name),
            subtitle: Text(
              density != null
                  ? 'Densidad: ${density.toStringAsFixed(4)} g/cm³  |  '
                      '${inst.recordingPaths.length} grabacion(es)'
                  : '${inst.recordingPaths.length} grabacion(es)',
            ),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => InstrumentScreen(instrument: inst),
                ),
              );
              _load();
            },
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              onPressed: () => _delete(inst),
            ),
          );
        },
      ),
    );
  }
}
