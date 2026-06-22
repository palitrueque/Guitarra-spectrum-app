import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

void main() {
  runApp(const GuitarraSpectrumApp());
}

class GuitarraSpectrumApp extends StatelessWidget {
  const GuitarraSpectrumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guitarra Spectrum',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const RecorderScreen(),
    );
  }
}

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

  Future<String> _newRecordingFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/recording_$timestamp.wav';
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

    final filePath = await _newRecordingFilePath();

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
          ? 'Grabacion guardada'
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

  @override
  Widget build(BuildContext context) {
    final hasFile = _lastRecordingPath != null && !_isRecording;
    final fileSize = hasFile && File(_lastRecordingPath!).existsSync()
        ? File(_lastRecordingPath!).lengthSync()
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guitarra Spectrum'),
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
                  backgroundColor: _isRecording
                      ? Theme.of(context).colorScheme.error
                      : null,
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
                Text(
                  'Ultima grabacion:',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  _lastRecordingPath!.split(Platform.pathSeparator).last,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                if (fileSize != null)
                  Text(
                    '${(fileSize / 1024).toStringAsFixed(1)} KB',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    // El analisis FFT se conectara aqui en el siguiente paso.
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'El analisis del espectro se anadira en el proximo paso',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.bar_chart),
                  label: const Text('Analizar espectro'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
