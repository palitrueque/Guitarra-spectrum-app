import 'package:flutter/material.dart';

import 'fft_processor.dart';
import 'note_map.dart';
import 'q_factor.dart';

class QFactorScreen extends StatefulWidget {
  final SpectrumResult fullSpectrum;

  const QFactorScreen({super.key, required this.fullSpectrum});

  @override
  State<QFactorScreen> createState() => _QFactorScreenState();
}

class _QFactorScreenState extends State<QFactorScreen> {
  int _nq = 15;
  late List<ResonancePeak> _peaks;

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  void _recompute() {
    _peaks = QFactorCalculator.computePeaks(widget.fullSpectrum, nq: _nq);
  }

  @override
  Widget build(BuildContext context) {
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
                  onPressed: _nq > 1
                      ? () => setState(() {
                            _nq--;
                            _recompute();
                          })
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                IconButton(
                  onPressed: _nq < 30
                      ? () => setState(() {
                            _nq++;
                            _recompute();
                          })
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Table(
                  border: TableBorder.all(color: Colors.grey.shade300),
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(2),
                    3: FlexColumnWidth(2),
                  },
                  children: [
                    TableRow(
                      decoration:
                          BoxDecoration(color: Colors.grey.shade200),
                      children: const [
                        _HeaderCell('Frecuencia'),
                        _HeaderCell('Nota'),
                        _HeaderCell('Amplitud'),
                        _HeaderCell('Q-factor'),
                      ],
                    ),
                    for (final peak in _peaks)
                      TableRow(
                        children: [
                          _Cell('${peak.frequency.toStringAsFixed(1)} Hz'),
                          _Cell(NoteMap.nearestNoteName(peak.frequency)),
                          _Cell(peak.amplitude.toStringAsFixed(2)),
                          _Cell(
                            peak.qFactor == null
                                ? '-'
                                : peak.qFactor!.toStringAsFixed(3),
                          ),
                        ],
                      ),
                  ],
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
  const _Cell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Text(text, style: const TextStyle(fontSize: 13)),
    );
  }
}
