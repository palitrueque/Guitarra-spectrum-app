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

  // Mismos parametros que usa plot_wf.m en spectrum.m:
  // nshift_wf = 15, shift_wf = 0.02
  static const int _nfft = 65536;
  static const int _nshift = 15;
  static const double _tshift = 0.02;
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
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Calculando 15 ventanas de FFT...'),
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
            'Cada linea es el espectro en un instante distinto: la mas '
            'cercana (abajo) es el momento del golpe; las de atras (arriba) '
            'son instantes posteriores.',
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

    // Perspectiva simple: cada traza mas "lejana" (k mayor = mas tarde
    // en el tiempo) se dibuja mas arriba y un poco mas a la derecha,
    // y con menos contraste de color, imitando profundidad.
    const verticalSpacing = 18.0;
    const horizontalShift = 0.5;
    final plotHeight = size.height - nTime * verticalSpacing - 10;
    final baseY = size.height - 10;

    // Dibujamos de la mas lejana (k alto) a la mas cercana (k=0), para
    // que las cercanas se superpongan sobre las lejanas, igual que en
    // un waterfall real (efecto de oclusion).
    for (int k = nTime - 1; k >= 0; k--) {
      final row = result.magnitudes[k];
      final depthFactor = k / denom;
      final yOffset = k * verticalSpacing;
      final xOffset = k * horizontalShift;
      final shade = (0.3 + 0.7 * (1 - depthFactor)).clamp(0.0, 1.0);
      final color = Color.lerp(Colors.blue.shade100, primaryColor, shade)!;

      final path = Path();
      final fillPath = Path();
      bool first = true;

      for (int f = 0; f <= maxFreqIndex; f++) {
        final norm = (row[f] / maxMag).clamp(0.0, 1.0);
        final x = (f / maxFreqIndex) * (size.width - xOffset) + xOffset;
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
      fillPath.lineTo(size.width, baseY - yOffset);
      fillPath.close();

      // "Mascara" de fondo solido para ocultar las trazas mas lejanas
      // detras (efecto de oclusion, como en un waterfall real).
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
