import 'package:flutter/material.dart';

import 'wav_reader.dart';
import 'waterfall_processor.dart';

class PcolorScreen extends StatefulWidget {
  final WavData wav;

  const PcolorScreen({super.key, required this.wav});

  @override
  State<PcolorScreen> createState() => _PcolorScreenState();
}

class _PcolorScreenState extends State<PcolorScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  WaterfallResult? _result;

  // Mismos parametros que usa plot_pc.m en spectrum.m:
  // nshift_pc = 60, shift_pc = 0.005
  static const int _nfft = 65536;
  static const int _nshift = 60;
  static const double _tshift = 0.005;
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
        _errorMessage = 'Error al calcular el mapa de calor: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de calor tiempo-frecuencia'),
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
            Text('Calculando 60 ventanas de FFT...'),
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

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cada fila es un instante de tiempo; el color indica la '
            'amplitud en cada frecuencia.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Eje de tiempo (vertical)
                SizedBox(
                  width: 36,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final h = constraints.maxHeight;
                      final maxTime = result.times.last;
                      return Stack(
                        children: [
                          Positioned(
                            top: 0,
                            child: Text('0.0s', style: _axisStyle),
                          ),
                          Positioned(
                            top: h - 14,
                            child: Text(
                              '${maxTime.toStringAsFixed(2)}s',
                              style: _axisStyle,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: CustomPaint(
                          painter: _PcolorPainter(result, _fMax),
                          child: Container(),
                        ),
                      ),
                      SizedBox(
                        height: 20,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final w = constraints.maxWidth;
                            return Stack(
                              children: [
                                for (int hz = 0; hz <= _fMax; hz += 200)
                                  Positioned(
                                    left: (hz / _fMax) * w - 10,
                                    child: Text(
                                      '$hz',
                                      style: _axisStyle,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text('Frecuencia [Hz]', style: _axisStyle),
          ),
        ],
      ),
    );
  }

  static const _axisStyle = TextStyle(fontSize: 10, color: Colors.grey);
}

class _PcolorPainter extends CustomPainter {
  final WaterfallResult result;
  final double fMax;

  _PcolorPainter(this.result, this.fMax);

  // Colormap simple: azul oscuro (bajo) -> cian -> amarillo -> rojo (alto).
  Color _colorFor(double t) {
    t = t.clamp(0.0, 1.0);
    const stops = [
      Color(0xFF000033),
      Color(0xFF0033AA),
      Color(0xFF00AACC),
      Color(0xFFFFEE00),
      Color(0xFFFF2200),
    ];
    final scaled = t * (stops.length - 1);
    final idx = scaled.floor().clamp(0, stops.length - 2);
    final localT = scaled - idx;
    return Color.lerp(stops[idx], stops[idx + 1], localT)!;
  }

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
    final cellHeight = size.height / nTime;
    final cellWidth = size.width / maxFreqIndex;

    final paint = Paint()..style = PaintingStyle.fill;

    for (int t = 0; t < nTime; t++) {
      final row = result.magnitudes[t];
      for (int f = 0; f < maxFreqIndex; f++) {
        final norm = (row[f] / maxMag).clamp(0.0, 1.0);
        paint.color = _colorFor(norm);
        final rect = Rect.fromLTWH(
          f * cellWidth,
          t * cellHeight,
          cellWidth + 0.5,
          cellHeight + 0.5,
        );
        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PcolorPainter oldDelegate) => false;
}
