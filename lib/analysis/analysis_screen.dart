import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'fft_processor.dart';
import 'note_map.dart';
import 'octave_bands.dart';
import 'wav_reader.dart';

class AnalysisScreen extends StatefulWidget {
  final String wavFilePath;

  const AnalysisScreen({super.key, required this.wavFilePath});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  SpectrumResult? _spectrum;
  List<OctaveBand>? _octaveBands;
  final int _nfft = 65536;

  // Offset fijo usado solo para dibujar las barras (igual que en MATLAB:
  // bar(bands+30,...)), asi la barra crece desde 0 hacia arriba en vez
  // de "colgar" hacia abajo por ser valores en dB negativos. Las
  // etiquetas de los ejes y los tooltips siempre muestran el valor
  // real en dB (sin el offset).
  static const double _dbOffset = 30.0;

  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final wav = await WavReader.readFile(widget.wavFilePath);
      final fullSpectrum = FftProcessor.computeSpectrum(wav, nfft: _nfft);

      final octaveTable = await OctaveBandsCalculator.loadTable();
      final octaveBands = OctaveBandsCalculator.compute(
        fullSpectrum,
        octaveTable,
      );

      // Ampliamos el rango hasta 8000 Hz (en vez de 1190), igual de
      // amplio que el rango principal de las bandas de octava.
      final spectrum = fullSpectrum.sliceRange(0, 8000);

      setState(() {
        _spectrum = spectrum;
        _octaveBands = octaveBands;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al analizar el audio: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Espectro de frecuencias'),
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
            Text('Calculando FFT...'),
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

    final spectrum = _spectrum!;
    final octaveBands = _octaveBands!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(spectrum),
          const SizedBox(height: 16),
          // Grafico del espectro con scroll horizontal: mas espacio por
          // Hz para distinguir mejor los picos, en vez de mas altura.
          _buildScrollableSpectrumSection(spectrum),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Bandas de tercios de octava',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 380,
            child: _buildOctaveBandsChart(octaveBands),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Frecuencia central [Hz]',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildScrollableSpectrumSection(SpectrumResult spectrum) {
    const fMax = 8000.0;
    const pixelsPerHz = 0.6; // mas espacio horizontal por Hz
    final chartWidth = fMax * pixelsPerHz;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = chartWidth < constraints.maxWidth
            ? constraints.maxWidth
            : chartWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: Column(
                  children: [
                    SizedBox(
                      height: 20,
                      child: _buildNoteLabelsRow(width, fMax),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 380,
                      width: width,
                      child: _buildSpectrumChart(spectrum, fMax),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Frecuencia [Hz]  (desliza para ver mas)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoCard(SpectrumResult spectrum) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _infoColumn(
              'Frecuencia de pico',
              '${spectrum.peakFrequency.toStringAsFixed(2)} Hz',
            ),
            _infoColumn(
              'Amplitud',
              spectrum.peakMagnitude.toStringAsFixed(2),
            ),
            _infoColumn(
              'Resolucion',
              '${spectrum.frequencyResolution.toStringAsFixed(3)} Hz',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteLabelsRow(double width, double fMax) {
    return Stack(
      children: [
        for (final marker in NoteMap.buildMarkers())
          if (marker.isOctaveMarker)
            Positioned(
              left: (marker.frequency / fMax) * width - 12,
              child: Text(
                marker.label ?? '',
                style: TextStyle(
                  color: Colors.red.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildSpectrumChart(SpectrumResult spectrum, double fMax) {
    final maxMag = spectrum.magnitudes.isEmpty
        ? 1.0
        : spectrum.magnitudes.reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: fMax,
        minY: 0,
        maxY: maxMag * 1.1,
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 200,
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
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (int i = 0; i < spectrum.frequencies.length; i++)
                FlSpot(spectrum.frequencies[i], spectrum.magnitudes[i]),
            ],
            isCurved: false,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 1.2,
            dotData: const FlDotData(show: false),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          getTouchedSpotIndicator: (barData, spotIndexes) {
            return spotIndexes.map((index) {
              return TouchedSpotIndicatorData(
                FlLine(color: Colors.black54, strokeWidth: 1.5),
                FlDotData(
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                    radius: 4,
                    color: Colors.black87,
                    strokeWidth: 0,
                  ),
                ),
              );
            }).toList();
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => Colors.black87,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final note = NoteMap.nearestNoteName(spot.x);
                return LineTooltipItem(
                  'Frecuencia: ${spot.x.toStringAsFixed(3)} Hz\n'
                  'Amplitud: ${spot.y.toStringAsFixed(3)}\n'
                  'Nota mas cercana: $note',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOctaveBandsChart(List<OctaveBand> bands) {
    final validValues = bands
        .map((b) => b.averageDb)
        .where((v) => !v.isNaN)
        .toList();
    final minDb = validValues.isEmpty
        ? -30.0
        : validValues.reduce((a, b) => a < b ? a : b);
    final maxDb = validValues.isEmpty
        ? 10.0
        : validValues.reduce((a, b) => a > b ? a : b);

    final screenMin = 0.0;
    final screenMax =
        ((maxDb + _dbOffset) + 5).clamp(40.0, 200.0).ceilToDouble();
    final lowestScreenValue = minDb + _dbOffset;
    final effectiveMin = lowestScreenValue < 0
        ? lowestScreenValue - 5
        : screenMin;

    final barWidth = 28.0;
    final chartWidth = bands.length * (barWidth + 12) + 20;

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
                    if (i < 0 || i >= bands.length) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        bands[i].centerFrequency.toStringAsFixed(0),
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
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (group) => Colors.black87,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final band = bands[group.x.toInt()];
                  return BarTooltipItem(
                    '${band.lowFrequency.toStringAsFixed(0)}-'
                    '${band.highFrequency.toStringAsFixed(0)} Hz\n'
                    '${band.averageDb.isNaN ? "sin datos" : "${band.averageDb.toStringAsFixed(3)} dB"}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            barGroups: [
              for (int i = 0; i < bands.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: bands[i].averageDb.isNaN
                          ? 0
                          : bands[i].averageDb + _dbOffset,
                      width: barWidth,
                      color: Theme.of(context).colorScheme.primary,
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

  Widget _infoColumn(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
