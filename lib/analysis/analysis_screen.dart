import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'fft_processor.dart';
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
  int _nfft = 65536;
  double _rawPeak = 0.0;
  int _sampleRate = 0;
  int _numSamples = 0;

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

      // DIAGNOSTICO: pico de la senal en bruto, antes de cualquier FFT.
      // Si esto ya sale muy bajo (cercano a 0), el problema esta en la
      // grabacion (o en la lectura del WAV), no en el calculo del espectro.
      double rawPeak = 0.0;
      for (final s in wav.samples) {
        final a = s.abs();
        if (a > rawPeak) rawPeak = a;
      }

      final fullSpectrum = FftProcessor.computeSpectrum(wav, nfft: _nfft);
      // Nos quedamos con el rango 0-1190 Hz, igual que la Figura 2 de MATLAB.
      final spectrum = fullSpectrum.sliceRange(0, 1190);

      setState(() {
        _spectrum = spectrum;
        _rawPeak = rawPeak;
        _sampleRate = wav.sampleRate;
        _numSamples = wav.samples.length;
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
    final maxMag = spectrum.magnitudes.isEmpty
        ? 1.0
        : spectrum.magnitudes.reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.yellow.shade100,
            child: Text(
              'DIAGNOSTICO: pico senal cruda = ${_rawPeak.toStringAsFixed(5)}  '
              '|  Fs = $_sampleRate Hz  |  muestras = $_numSamples',
              style: const TextStyle(fontSize: 11),
            ),
          ),
          const SizedBox(height: 8),
          Card(
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
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
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
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Frecuencia [Hz]',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
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
