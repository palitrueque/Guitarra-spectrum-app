import 'package:flutter/material.dart';

import 'wav_reader.dart';
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
              painter: _WaterfallPainter(result, _fMax, primaryColor),
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

class _WaterfallPainter extends CustomPainter {
  final WaterfallResult result;
  final double fMax;
  final Color primaryColor;

  _WaterfallPainter(this.result, this.fMax, this.primaryColor);

  @override
  void paint(Canvas canvas, Size size) {
    final freqs = result.frequencies;
    int maxFreqIndex = freqs.length - 1;
    for (int i = 0; i < freqs.length; i++) {
      if (freqs[i] > fMax) {
        maxFreqIndex = i;
        break;
      }
    }

    final maxMag = result.maxMagnitude;
    if (maxMag <= 0) return;

    final nTime = result.times.length;
    final denom = (nTime - 1) < 1 ? 1 : (nTime - 1);

    // El PRIMER instante (k=0, justo en el golpe, el mas alto) se dibuja
    // AL FONDO; los instantes posteriores (decayendo) se acercan hacia
    // delante. Asi el pico mas alto no tapa a los que se forman despues,
    // y se ve la caida de la resonancia hacia el frente.
    const verticalSpacing = 16.0;
    const horizontalShift = 1.1; // angulacion lateral mas marcada
    final plotHeight = size.height - nTime * verticalSpacing - 10;
    final baseY = size.height - 10;

    // Dibujamos de fondo (k=0, el mas alto) a frente (k=nTime-1, el mas
    // bajo) en ORDEN ASCENDENTE, para que las trazas mas cercanas
    // (mas bajas) se pinten encima al final, sin enmascarar el pico
    // alto del fondo (que sobresale por encima de todas).
    for (int k = 0; k < nTime; k++) {
      final row = result.magnitudes[k];
      // depthFactor: 1.0 = totalmente al fondo (k=0), 0.0 = al frente.
      final depthFactor = 1.0 - (k / denom);
      final depthIndex = nTime - 1 - k; // posicion visual: 0=frente
      final yOffset = depthIndex * verticalSpacing;
      final xOffset = depthIndex * horizontalShift;
      final widthScale = 1.0 - depthFactor * 0.12; // leve convergencia
      final shade = (0.3 + 0.7 * depthFactor).clamp(0.0, 1.0);
      final color = Color.lerp(Colors.blue.shade100, primaryColor, shade)!;

      final usableWidth = (size.width - xOffset) * widthScale;
      final xStart = xOffset + (size.width - xOffset - usableWidth) / 2;

      final path = Path();
      final fillPath = Path();
      bool first = true;

      for (int f = 0; f <= maxFreqIndex; f++) {
        final norm = (row[f] / maxMag).clamp(0.0, 1.0);
        final x = xStart + (f / maxFreqIndex) * usableWidth;
        final y = baseY - yOffset - norm * plotHeight;

        if (first) {
          path.moveTo(x, y);
          fillPath.moveTo(x, baseY - yOffset);
          fillPath.lineTo(x, y);
          first = false;
        } else {
          path.lineTo(x, y);
          fillPath.lineTo(x, y);
        }
      }
      fillPath.lineTo(xStart + usableWidth, baseY - yOffset);
      fillPath.close();

      // "Mascara" de fondo solido para ocultar SOLO la zona bajo esta
      // traza (oclusion local), sin tapar lo que sobresale por encima.
      canvas.drawPath(fillPath, Paint()..color = Colors.white);

      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaterfallPainter oldDelegate) => false;
}
