import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'analysis/analysis_screen.dart';
import 'recording_storage.dart';

class RecorderScreen extends StatefulWidget {
  const RecorderScreen({super.key});

  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isRecording = false;
  String? _lastRecordingPath;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  String _statusMessage = 'Listo para grabar';

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<bool> _ensureMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<String> _newTempFilePath() async {
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/temp_recording_$timestamp.wav';
  }

  Future<void> _startRecording() async {
    final hasPermission = await _ensureMicPermission();
    if (!hasPermission) {
      setState(() {
        _statusMessage = 'Permiso de microfono denegado';
      });
      return;
    }

    if (!await _audioRecorder.hasPermission()) {
      setState(() {
        _statusMessage = 'No se pudo acceder al microfono';
      });
      return;
    }

    final filePath = await _newTempFilePath();

    // Grabamos en WAV PCM 16-bit, mono, 44100 Hz: formato directo
    // de leer luego con un parser de cabecera WAV estandar.
    const config = RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 44100,
      numChannels: 1,
    );

    await _audioRecorder.start(config, path: filePath);

    _elapsed = Duration.zero;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed += const Duration(seconds: 1);
      });
    });

    setState(() {
      _isRecording = true;
      _lastRecordingPath = filePath;
      _statusMessage = 'Grabando...';
    });
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    _timer?.cancel();

    setState(() {
      _isRecording = false;
      _lastRecordingPath = path ?? _lastRecordingPath;
      _statusMessage = path != null
          ? 'Grabacion lista. Dale un nombre para guardarla.'
          : 'No se pudo guardar la grabacion';
    });
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _suggestedName() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Grabacion ${two(now.day)}-${two(now.month)} ${two(now.hour)}h${two(now.minute)}';
  }

  Future<void> _saveAndAnalyze() async {
    if (_lastRecordingPath == null) return;
    final tempFile = File(_lastRecordingPath!);
    if (!await tempFile.exists()) return;

    final nameController = TextEditingController(text: _suggestedName());
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Guardar grabacion'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre del archivo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(nameController.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (name == null) return;

    final savedFile = await RecordingStorage.saveRecording(tempFile, name);

    if (!mounted) return;
    final dir = await RecordingStorage.recordingsDir();
    if (!mounted) return;

    final goAnalyze = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Grabacion guardada'),
        content: Text(
          'Guardada como "${savedFile.path.split(Platform.pathSeparator).last}" '
          'en la biblioteca de la app:\n\n${dir.path}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver a la biblioteca'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Analizar ahora'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (goAnalyze == true) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AnalysisScreen(wavFilePath: savedFile.path),
        ),
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop(true); // avisa a la biblioteca que refresque
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = _lastRecordingPath != null && !_isRecording;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grabar'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isRecording ? Icons.graphic_eq : Icons.mic_none,
                size: 96,
                color: _isRecording
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                _formatDuration(_elapsed),
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                _statusMessage,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _toggleRecording,
                icon: Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record),
                label: Text(_isRecording ? 'Detener' : 'Grabar'),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      _isRecording ? Theme.of(context).colorScheme.error : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
              if (hasFile) ...[
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saveAndAnalyze,
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar grabacion'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
