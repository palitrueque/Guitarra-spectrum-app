import 'dart:io';

import 'package:flutter/material.dart';

import 'analysis/analysis_screen.dart';
import 'instrument_model.dart';
import 'instrument_storage.dart';
import 'recording_storage.dart';

class InstrumentScreen extends StatefulWidget {
  final InstrumentModel instrument;

  const InstrumentScreen({super.key, required this.instrument});

  @override
  State<InstrumentScreen> createState() => _InstrumentScreenState();
}

class _InstrumentScreenState extends State<InstrumentScreen> {
  late InstrumentModel _instrument;
  bool _isDirty = false;

  // Controladores para los campos de texto
  late final TextEditingController _nameCtrl;
  late final TextEditingController _upperBoutCtrl;
  late final TextEditingController _waistCtrl;
  late final TextEditingController _lowerBoutCtrl;
  late final TextEditingController _lengthCtrl;
  late final TextEditingController _thicknessCtrl;
  late final TextEditingController _weightCtrl;

  @override
  void initState() {
    super.initState();
    _instrument = widget.instrument;
    _nameCtrl = TextEditingController(text: _instrument.name);
    _upperBoutCtrl = TextEditingController(
        text: _instrument.upperBoutWidth?.toString() ?? '');
    _waistCtrl = TextEditingController(
        text: _instrument.waistWidth?.toString() ?? '');
    _lowerBoutCtrl = TextEditingController(
        text: _instrument.lowerBoutWidth?.toString() ?? '');
    _lengthCtrl = TextEditingController(
        text: _instrument.totalLength?.toString() ?? '');
    _thicknessCtrl = TextEditingController(
        text: _instrument.thickness?.toString() ?? '');
    _weightCtrl = TextEditingController(
        text: _instrument.weight?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _upperBoutCtrl.dispose();
    _waistCtrl.dispose();
    _lowerBoutCtrl.dispose();
    _lengthCtrl.dispose();
    _thicknessCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {
      _instrument.name = _nameCtrl.text;
      _instrument.upperBoutWidth = double.tryParse(_upperBoutCtrl.text);
      _instrument.waistWidth = double.tryParse(_waistCtrl.text);
      _instrument.lowerBoutWidth = double.tryParse(_lowerBoutCtrl.text);
      _instrument.totalLength = double.tryParse(_lengthCtrl.text);
      _instrument.thickness = double.tryParse(_thicknessCtrl.text);
      _instrument.weight = double.tryParse(_weightCtrl.text);
      _isDirty = true;
    });
  }

  Future<void> _save() async {
    await InstrumentStorage.update(_instrument);
    setState(() => _isDirty = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ficha guardada')),
    );
  }

  Future<void> _addRecording() async {
    final recordings = await RecordingStorage.listRecordings();
    final available = recordings
        .where((r) => !_instrument.recordingPaths.contains(r.file.path))
        .toList();

    if (!mounted) return;

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay grabaciones disponibles para asociar')),
      );
      return;
    }

    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Selecciona una grabacion'),
        children: [
          for (final r in available)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(r.file.path),
              child: Text(r.name),
            ),
        ],
      ),
    );

    if (selected == null) return;

    setState(() {
      _instrument.recordingPaths.add(selected);
      _isDirty = true;
    });
    await InstrumentStorage.update(_instrument);
  }

  Future<void> _removeRecording(String path) async {
    setState(() {
      _instrument.recordingPaths.remove(path);
      _isDirty = true;
    });
    await InstrumentStorage.update(_instrument);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_instrument.name.isEmpty ? 'Nueva ficha' : _instrument.name),
        centerTitle: true,
        actions: [
          if (_isDirty)
            IconButton(
              onPressed: _save,
              icon: const Icon(Icons.save),
              tooltip: 'Guardar',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNameField(),
            const SizedBox(height: 24),
            _buildSectionTitle('Medidas de la tapa'),
            const SizedBox(height: 12),
            _buildMeasureFields(),
            const SizedBox(height: 24),
            _buildCalculatedValues(),
            const SizedBox(height: 24),
            _buildSectionTitle('Grabaciones asociadas'),
            const SizedBox(height: 12),
            _buildRecordingsList(),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addRecording,
                icon: const Icon(Icons.add),
                label: const Text('Asociar grabacion'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: _isDirty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar cambios'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildNameField() {
    return TextField(
      controller: _nameCtrl,
      onChanged: (_) => _onChanged(),
      decoration: const InputDecoration(
        labelText: 'Nombre del instrumento',
        hintText: 'Ej: Guitarra clasica n°3',
        border: OutlineInputBorder(),
      ),
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }

  Widget _buildMeasureFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _measureField(
                controller: _upperBoutCtrl,
                label: 'Lóbulo superior',
                unit: 'cm',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _measureField(
                controller: _waistCtrl,
                label: 'Cintura',
                unit: 'cm',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _measureField(
                controller: _lowerBoutCtrl,
                label: 'Lóbulo inferior',
                unit: 'cm',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _measureField(
                controller: _lengthCtrl,
                label: 'Longitud total',
                unit: 'cm',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _measureField(
                controller: _thicknessCtrl,
                label: 'Espesor medio',
                unit: 'mm',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _measureField(
                controller: _weightCtrl,
                label: 'Peso',
                unit: 'g',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _measureField({
    required TextEditingController controller,
    required String label,
    required String unit,
  }) {
    return TextField(
      controller: controller,
      onChanged: (_) => _onChanged(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: unit,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _buildCalculatedValues() {
    final surface = _instrument.surfaceCm2;
    final volume = _instrument.volumeCm3;
    final density = _instrument.densityGcm3;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Valores calculados',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            _calcRow(
              'Superficie',
              surface != null ? '${surface.toStringAsFixed(1)} cm²' : '—',
            ),
            _calcRow(
              'Volumen',
              volume != null ? '${volume.toStringAsFixed(2)} cm³' : '—',
            ),
            _calcRow(
              'Densidad',
              density != null
                  ? '${density.toStringAsFixed(4)} g/cm³'
                  : '—',
              highlight: density != null,
            ),
            if (density != null) ...[
              const SizedBox(height: 8),
              _densityReference(density),
            ],
          ],
        ),
      ),
    );
  }

  Widget _calcRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight:
                  highlight ? FontWeight.bold : FontWeight.normal,
              fontSize: highlight ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Referencia orientativa de densidad para maderas de tapa comunes.
  Widget _densityReference(double density) {
    String ref;
    Color color;
    if (density < 0.35) {
      ref = 'Muy ligera (inusual para tapa)';
      color = Colors.orange;
    } else if (density < 0.45) {
      ref = 'Ligera — típica de abeto de alta calidad';
      color = Colors.green;
    } else if (density < 0.55) {
      ref = 'Media — abeto o cedro estándar';
      color = Colors.green;
    } else if (density < 0.65) {
      ref = 'Media-alta — cedro denso o maderas tropicales';
      color = Colors.orange;
    } else {
      ref = 'Alta — madera densa (poco habitual para tapa)';
      color = Colors.red;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(ref, style: TextStyle(color: color, fontSize: 12)),
    );
  }

  Widget _buildRecordingsList() {
    if (_instrument.recordingPaths.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Ninguna grabacion asociada todavia.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        for (final path in _instrument.recordingPaths)
          _buildRecordingTile(path),
      ],
    );
  }

  Widget _buildRecordingTile(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    final name =
        fileName.endsWith('.wav') ? fileName.substring(0, fileName.length - 4) : fileName;
    final exists = File(path).existsSync();

    return ListTile(
      leading: Icon(
        Icons.audiotrack,
        color: exists ? null : Colors.red,
      ),
      title: Text(name),
      subtitle: exists ? null : const Text('Archivo no encontrado', style: TextStyle(color: Colors.red)),
      onTap: exists
          ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AnalysisScreen(wavFilePath: path),
                ),
              )
          : null,
      trailing: IconButton(
        icon: const Icon(Icons.link_off, color: Colors.grey),
        tooltip: 'Desasociar',
        onPressed: () => _removeRecording(path),
      ),
    );
  }
}
