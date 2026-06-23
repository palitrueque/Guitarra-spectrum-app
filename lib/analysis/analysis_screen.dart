import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'fft_processor.dart';
import 'note_map.dart';
import 'octave_bands_screen.dart';
import 'q_factor_screen.dart';
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
  SpectrumResult? _fullSpectrum;
  final int _nfft = 65536;

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
      // Nos quedamos con el rango 0-1190 Hz, igual que la Figura 2 de MATLAB.
      final spectrum = fullSpectrum.sliceRange(0, 1190);

      setState(() {
        _spectrum = spectrum;
        _fullSpectrum = fullSpectrum;
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
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final infoCard = Card(
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

    final noteLabelsRow = SizedBox(
      height: 20,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          const fMax = 1190.0;
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
        },
      ),
    );

    final chart = _buildChart(spectrum);

    final freqCaption = Center(
      child: Text(
        'Frecuencia [Hz]',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );

    final octaveBandsButton = SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OctaveBandsScreen(
                fullSpectrum: _fullSpectrum!,
              ),
            ),
          );
        },
        icon: const Icon(Icons.bar_chart),
        label: const Text('Ver bandas de tercios de octava'),
      ),
    );

    final qFactorButton = SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => QFactorScreen(
                fullSpectrum: _fullSpectrum!,
              ),
            ),
          );
        },
        icon: const Icon(Icons.show_chart),
        label: const Text('Ver picos de resonancia (Q-factor)'),
      ),
    );

    // En horizontal hay mucha menos altura disponible (la tarjeta, las
    // etiquetas y los botones dejan muy poco sitio), asi que en ese caso
    // hacemos la pantalla desplazable y le damos al grafico una altura
    // fija razonable en vez de "Expanded" (que se quedaria sin espacio).
    if (isLandscape) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            infoCard,
            const SizedBox(height: 16),
            noteLabelsRow,
            const SizedBox(height: 4),
            SizedBox(height: 320, child: chart),
            const SizedBox(height: 8),
            freqCaption,
            const SizedBox(height: 12),
            octaveBandsButton,
            const SizedBox(height: 8),
            qFactorButton,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          infoCard,
          const SizedBox(height: 16),
          noteLabelsRow,
          const SizedBox(height: 4),
          Expanded(child: chart),
          const SizedBox(height: 8),
          freqCaption,
          const SizedBox(height: 12),
          octaveBandsButton,
          const SizedBox(height: 8),
          qFactorButton,
        ],
      ),
    );
  }

  Widget _buildChart(SpectrumResult spectrum) {
    final maxMag = spectrum.magnitudes.isEmpty
        ? 1.0
        : spectrum.magnitudes.reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 1190,
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
