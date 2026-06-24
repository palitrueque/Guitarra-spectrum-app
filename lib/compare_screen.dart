import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'analysis/fft_processor.dart';
import 'analysis/octave_bands.dart';
import 'analysis/wav_reader.dart';

/// Paleta fija de colores para diferenciar cada grabacion comparada.
const List<Color> kCompareColors = [
  Colors.red,
  Colors.blue,
  Colors.green,
  Colors.orange,
  Colors.purple,
];

class CompareScreen extends StatefulWidget {
  final List<String> wavPaths;
  final List<String> names;

  const CompareScreen({
    super.key,
    required this.wavPaths,
    required this.names,
  });

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<SpectrumResult> _spectra = [];
  List<List<OctaveBand>> _bandsList = [];

  static const int _nfft = 65536;
  static const double _fMax = 1190.0;
  static const double _dbOffset = 30.0;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  Future<void> _compute() async {
    try {
      final table = await OctaveBandsCalculator.loadTable();
      final spectra = <SpectrumResult>[];
      final bandsList = <List<OctaveBand>>[];

      for (final path in widget.wavPaths) {
        final wav = await WavReader.readFile(path);
        final fullSpectrum = FftProcessor.computeSpectrum(wav, nfft: _nfft);
        final sliced = fullSpectrum.sliceRange(0, _fMax);
        final bands = OctaveBandsCalculator.compute(fullSpectrum, table);
        spectra.add(sliced);
        bandsList.add(bands);
      }

      setState(() {
        _spectra = spectra;
        _bandsList = bandsList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al comparar las grabaciones: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparar grabaciones'),
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
            Text('Calculando espectros...'),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLegend(),
          const SizedBox(height: 20),
          Text(
            'Espectro de frecuencias',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SizedBox(height: 380, child: _buildSpectrumChart()),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Frecuencia [Hz]',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Nivel medio por bandas de octava (dB)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SizedBox(height: 380, child: _buildOctaveBandsChart()),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Frecuencia central [Hz]  (desliza para ver todas las bandas)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        for (int i = 0; i < widget.names.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: kCompareColors[i % kCompareColors.length],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(widget.names[i], style: const TextStyle(fontSize: 13)),
            ],
          ),
      ],
    );
  }

  Widget _buildSpectrumChart() {
    double maxMag = 1.0;
    for (final s in _spectra) {
      for (final m in s.magnitudes) {
        if (m > maxMag) maxMag = m;
      }
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: _fMax,
        minY: 0,
        maxY: maxMag * 1.1,
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 100,
              reservedSize: 28,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          for (int i = 0; i < _spectra.length; i++)
            LineChartBarData(
              spots: [
                for (int k = 0; k < _spectra[i].frequencies.length; k++)
                  FlSpot(_spectra[i].frequencies[k], _spectra[i].magnitudes[k]),
              ],
              isCurved: false,
              color: kCompareColors[i % kCompareColors.length],
              barWidth: 1.3,
              dotData: const FlDotData(show: false),
            ),
        ],
      ),
    );
  }

  Widget _buildOctaveBandsChart() {
    if (_bandsList.isEmpty) return const SizedBox();
    final numBands = _bandsList.first.length;

    double minDb = 0;
    double maxDb = 0;
    for (final bands in _bandsList) {
      for (final b in bands) {
        if (b.averageDb.isNaN) continue;
        if (b.averageDb < minDb) minDb = b.averageDb;
        if (b.averageDb > maxDb) maxDb = b.averageDb;
      }
    }
    final screenMax = ((maxDb + _dbOffset) + 5).clamp(40.0, 200.0).ceilToDouble();
    final lowestScreenValue = minDb + _dbOffset;
    final effectiveMin = lowestScreenValue < 0 ? lowestScreenValue - 5 : 0.0;

    const groupWidth = 14.0;
    final barsPerGroup = _bandsList.length;
    final chartWidth = numBands * (groupWidth * barsPerGroup + 14) + 20;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: chartWidth,
        child: BarChart(
          BarChartData(
            minY: effectiveMin,
            maxY: screenMax,
            gridData: const FlGridData(show: true),
            borderData: FlBorderData(show: true),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= numBands) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _bandsList.first[i].centerFrequency.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 9),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  interval: 10,
                  getTitlesWidget: (value, meta) {
                    final realDb = value - _dbOffset;
                    return Text(
                      realDb.toStringAsFixed(0),
                      style: const TextStyle(fontSize: 10),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            barGroups: [
              for (int bandIdx = 0; bandIdx < numBands; bandIdx++)
                BarChartGroupData(
                  x: bandIdx,
                  barsSpace: 2,
                  barRods: [
                    for (int r = 0; r < _bandsList.length; r++)
                      BarChartRodData(
                        toY: _bandsList[r][bandIdx].averageDb.isNaN
                            ? 0
                            : _bandsList[r][bandIdx].averageDb + _dbOffset,
                        width: groupWidth,
                        color: kCompareColors[r % kCompareColors.length],
                        borderRadius: BorderRadius.zero,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
