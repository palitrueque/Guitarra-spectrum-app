import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'fft_processor.dart';
import 'more_analysis_screen.dart';
import 'note_map.dart';
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
  WavData? _wav;
  final int _nfft = 65536;
  bool? _lastIsLandscape;
  int? _selectedIndex;
  Offset? _touchPosition;
  int? _sampleRate;
  int? _bitsPerSample;
  int? _audioFormat;
  int? _numChannelsRaw;
  double? _calculatedDuration;

  @override
  void dispose() {
    // Al salir de esta pantalla, restauramos la barra de sistema normal
    // por si nos vamos en modo inmersivo (horizontal).
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

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
        _wav = wav;
        _sampleRate = wav.sampleRate;
        _bitsPerSample = wav.bitsPerSample;
        _audioFormat = wav.audioFormat;
        _numChannelsRaw = wav.numChannelsRaw;
        _calculatedDuration = wav.samples.length / wav.sampleRate;
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

    // Modo inmersivo en horizontal: ocultamos la barra de estado
    // (bateria, senal, etc.) para aprovechar toda la pantalla. En
    // vertical, restauramos la barra normal.
    if (_lastIsLandscape != isLandscape) {
      _lastIsLandscape = isLandscape;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SystemChrome.setEnabledSystemUIMode(
          isLandscape ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
        );
      });
    }

    final infoCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
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
            // DIAGNOSTICO (oculto visualmente, mantener para uso futuro):
            // descomenta el bloque siguiente para ver sample rate, bits,
            // canales y duracion calculada del archivo WAV.
            // const SizedBox(height: 6),
            // Container(
            //   width: double.infinity,
            //   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            //   decoration: BoxDecoration(
            //     color: Colors.grey.shade100,
            //     borderRadius: BorderRadius.circular(4),
            //   ),
            //   child: Text(
            //     'Fs: ${_sampleRate ?? "?"} Hz  |  '
            //     'Bits: ${_bitsPerSample ?? "?"}  |  '
            //     'Canales: ${_numChannelsRaw ?? "?"}  |  '
            //     'Duracion calculada: ${_calculatedDuration?.toStringAsFixed(2) ?? "?"} s',
            //     style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            //   ),
            // ),
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

    final moreAnalysisButton = SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MoreAnalysisScreen(
                fullSpectrum: _fullSpectrum!,
                wav: _wav!,
              ),
            ),
          );
        },
        icon: const Icon(Icons.analytics_outlined),
        label: const Text('Mas analisis (octavas, Q-factor, waterfall...)'),
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
            moreAnalysisButton,
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
          moreAnalysisButton,
        ],
      ),
    );
  }

  /// Desde el indice tocado, "escala" hacia el pico local mas cercano
  /// (sube por la pendiente mas empinada hasta que ya no se puede subir
  /// mas), asi el punto seleccionado cae siempre justo en la cresta de
  /// un pico en vez de en cualquier punto intermedio de la curva.
  int _snapToNearestPeak(SpectrumResult spectrum, int fromIndex) {
    final mag = spectrum.magnitudes;
    int idx = fromIndex.clamp(0, mag.length - 1);

    while (true) {
      final hasLeft = idx > 0;
      final hasRight = idx < mag.length - 1;
      final leftHigher = hasLeft && mag[idx - 1] > mag[idx];
      final rightHigher = hasRight && mag[idx + 1] > mag[idx];

      if (!leftHigher && !rightHigher) {
        break; // ya estamos en un pico local (o en un extremo)
      }
      if (rightHigher && (!leftHigher || mag[idx + 1] >= mag[idx - 1])) {
        idx++;
      } else {
        idx--;
      }
    }
    return idx;
  }

  Widget _buildChart(SpectrumResult spectrum) {
    final maxMag = spectrum.magnitudes.isEmpty
        ? 1.0
        : spectrum.magnitudes.reduce((a, b) => a > b ? a : b);

    final selected = _selectedIndex != null &&
            _selectedIndex! >= 0 &&
            _selectedIndex! < spectrum.frequencies.length
        ? _selectedIndex!
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        // Colocamos el recuadro en el cuadrante OPUESTO a donde esta el
        // dedo, para que no tape la zona de la curva que estas mirando.
        final pos = _touchPosition;
        final touchedRight = pos != null && pos.dx > w / 2;
        final touchedBottom = pos != null && pos.dy > h / 2;

        return Stack(
          children: [
            LineChart(
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
                    showingIndicators: selected != null ? [selected] : [],
                  ),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: false,
                  // No usamos el tooltip nativo (desaparece al levantar el
                  // dedo); guardamos el punto tocado en el estado y lo
                  // mostramos con nuestro propio recuadro persistente.
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => Colors.transparent,
                    getTooltipItems: (touchedSpots) => touchedSpots
                        .map((_) => null)
                        .toList()
                        .cast<LineTooltipItem?>(),
                  ),
                  getTouchedSpotIndicator: (barData, spotIndexes) {
                    return spotIndexes.map((index) {
                      return TouchedSpotIndicatorData(
                        FlLine(color: Colors.red.withOpacity(0.5), strokeWidth: 1.5),
                        FlDotData(
                          getDotPainter: (spot, percent, bar, index) =>
                              FlDotCirclePainter(
                            radius: 5,
                            color: Colors.red,
                            strokeWidth: 1.5,
                            strokeColor: Colors.white,
                          ),
                        ),
                      );
                    }).toList();
                  },
                  touchCallback: (event, response) {
                    if (response == null ||
                        response.lineBarSpots == null ||
                        response.lineBarSpots!.isEmpty) {
                      return;
                    }
                    final rawIndex = response.lineBarSpots!.first.spotIndex;
                    final peakIndex = _snapToNearestPeak(spectrum, rawIndex);
                    final pos = event.localPosition;
                    if (peakIndex != _selectedIndex || pos != null) {
                      setState(() {
                        _selectedIndex = peakIndex;
                        if (pos != null) _touchPosition = pos;
                      });
                    }
                  },
                ),
              ),
            ),
            if (selected != null)
              Positioned(
                top: touchedBottom ? 8 : null,
                bottom: touchedBottom ? null : 8,
                right: touchedRight ? null : 8,
                left: touchedRight ? 8 : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Frecuencia: ${spectrum.frequencies[selected].toStringAsFixed(3)} Hz',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Amplitud: ${spectrum.magnitudes[selected].toStringAsFixed(3)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Nota mas cercana: ${NoteMap.nearestNoteName(spectrum.frequencies[selected])}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
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
