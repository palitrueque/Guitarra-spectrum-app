import 'package:flutter/material.dart';

import 'wav_reader.dart';
import 'waterfall_painter.dart';
import 'waterfall_processor.dart';

class WaterfallScreen extends StatefulWidget {
  final WavData wav;

  const WaterfallScreen({super.key, required this.wav});

  @override
  State<WaterfallScreen> createState() => _WaterfallScreenState();
}

class _WaterfallScreenState extends State<WaterfallScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  WaterfallResult? _result;

  // Probando con mas rango temporal para ver mejor la caida de la
  // resonancia: 30 ventanas x 25ms = 0.75s en total (en vez de los
  // 15 x 20ms = 280ms originales de plot_wf.m).
  static const int _nfft = 65536;
  static const int _nshift = 30;
  static const double _tshift = 0.025;
  static const double _fMax = 1190.0;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  Future<void> _compute() async {
    try {
      final result = await Future(() => WaterfallProcessor.compute(
            widget.wav,
            nfft: _nfft,
            nshift: _nshift,
            tshift: _tshift,
          ));
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al calcular el waterfall: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Waterfall (evolucion en el tiempo)'),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Calculando $_nshift ventanas de FFT...'),
          ],
        ),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final result = _result!;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cada linea es el espectro en un instante distinto: la del '
            'fondo (arriba) es el momento del golpe; hacia delante (abajo) '
            'la resonancia va decayendo con el tiempo.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: CustomPaint(
              painter: WaterfallPainter(result, _fMax, primaryColor),
              child: Container(),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Frecuencia [Hz]  (0 - ${_fMax.toInt()})',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
