import 'package:flutter/material.dart';

import 'decay_calculator.dart';
import 'fft_processor.dart';
import 'note_map.dart';
import 'q_factor.dart';
import 'wav_reader.dart';
import 'waterfall_processor.dart';

class QFactorScreen extends StatefulWidget {
  final SpectrumResult fullSpectrum;
  final WavData wav;

  const QFactorScreen({
    super.key,
    required this.fullSpectrum,
    required this.wav,
  });

  @override
  State<QFactorScreen> createState() => _QFactorScreenState();
}

class _QFactorScreenState extends State<QFactorScreen> {
  int _nq = 15;
  late List<ResonancePeak> _peaks;
  List<DecayResult>? _decays;
  bool _isLoadingDecay = true;

  // Parametros para el calculo de decaimiento: necesitamos cubrir mas
  // tiempo que el waterfall original para poder ver caidas de -20dB
  // con margen (1 segundo: 40 ventanas x 25ms).
  static const int _nfft = 65536;
  static const int _decayNshift = 40;
  static const double _decayTshift = 0.025;

  @override
  void initState() {
    super.initState();
    _recompute();
    _computeDecay();
  }

  void _recompute() {
    _peaks = QFactorCalculator.computePeaks(widget.fullSpectrum, nq: _nq);
  }

  Future<void> _computeDecay() async {
    setState(() => _isLoadingDecay = true);
    final waterfall = await Future(() => WaterfallProcessor.compute(
          widget.wav,
          nfft: _nfft,
          nshift: _decayNshift,
          tshift: _decayTshift,
        ));
    final decays = DecayCalculator.compute(waterfall, _peaks);
    setState(() {
      _decays = decays;
      _isLoadingDecay = false;
    });
  }

  void _onNqChanged(int newNq) {
    setState(() {
      _nq = newNq;
      _recompute();
    });
    _computeDecay();
  }

  /// Indice del pico de menor frecuencia: candidato a resonancia de
  /// Helmholtz (la resonancia de aire del cuerpo), que suele ser la
  /// mas baja detectada en un instrumento de cuerda.
  int? get _helmholtzIndex {
    if (_peaks.isEmpty) return null;
    int idx = 0;
    for (int i = 1; i < _peaks.length; i++) {
      if (_peaks[i].frequency < _peaks[idx].frequency) idx = i;
    }
    return idx;
  }

  @override
  Widget build(BuildContext context) {
    final helmholtzIdx = _helmholtzIndex;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Picos de resonancia (Q-factor)'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Numero de picos: $_nq',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  onPressed: _nq > 1 ? () => _onNqChanged(_nq - 1) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                IconButton(
                  onPressed: _nq < 30 ? () => _onNqChanged(_nq + 1) : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            if (helmholtzIdx != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Fila resaltada: candidato a resonancia de Helmholtz '
                  '(aire del cuerpo) — suele ser la mas baja detectada.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            if (_isLoadingDecay)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Calculando tiempos de decaimiento...',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Expanded(
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Table(
                    border: TableBorder.all(color: Colors.grey.shade300),
                    columnWidths: const {
                      0: FixedColumnWidth(90),
                      1: FixedColumnWidth(60),
                      2: FixedColumnWidth(80),
                      3: FixedColumnWidth(70),
                      4: FixedColumnWidth(90),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: Colors.grey.shade200),
                        children: const [
                          _HeaderCell('Frecuencia'),
                          _HeaderCell('Nota'),
                          _HeaderCell('Amplitud'),
                          _HeaderCell('Q-factor'),
                          _HeaderCell('T20 (ms)'),
                        ],
                      ),
                      for (int i = 0; i < _peaks.length; i++)
                        TableRow(
                          decoration: BoxDecoration(
                            color: i == helmholtzIdx
                                ? Colors.blue.shade50
                                : null,
                          ),
                          children: [
                            _Cell(
                              '${_peaks[i].frequency.toStringAsFixed(1)} Hz',
                              bold: i == helmholtzIdx,
                            ),
                            _Cell(NoteMap.nearestNoteName(_peaks[i].frequency)),
                            _Cell(_peaks[i].amplitude.toStringAsFixed(2)),
                            _Cell(
                              _peaks[i].qFactor == null
                                  ? '-'
                                  : _peaks[i].qFactor!.toStringAsFixed(3),
                            ),
                            _Cell(
                              _decays == null
                                  ? '...'
                                  : (_decays![i].t20Seconds == null
                                      ? '> rango'
                                      : (_decays![i].t20Seconds! * 1000)
                                          .toStringAsFixed(0)),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final bool bold;
  const _Cell(this.text, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
