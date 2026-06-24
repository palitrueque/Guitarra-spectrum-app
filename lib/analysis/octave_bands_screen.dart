import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'fft_processor.dart';
import 'octave_bands.dart';

class OctaveBandsScreen extends StatefulWidget {
  final SpectrumResult fullSpectrum;

  const OctaveBandsScreen({super.key, required this.fullSpectrum});

  @override
  State<OctaveBandsScreen> createState() => _OctaveBandsScreenState();
}

class _OctaveBandsScreenState extends State<OctaveBandsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<OctaveBand>? _bands;
  List<OctaveIndex>? _indices;

  // Offset fijo usado solo para dibujar las barras (igual que en MATLAB:
  // bar(bands+30,...)), asi la barra crece desde 0 hacia arriba en vez
  // de "colgar" hacia abajo por ser valores en dB negativos. Las
  // etiquetas de los ejes y los tooltips siempre muestran el valor
  // real en dB (sin el offset).
  static const double _dbOffset = 30.0;

  @override
  void initState() {
    super.initState();
    _loadBands();
  }

  Future<void> _loadBands() async {
    try {
      final table = await OctaveBandsCalculator.loadTable();
      final bands = OctaveBandsCalculator.compute(widget.fullSpectrum, table);
      final indices = OctaveIndexCalculator.compute(bands);
      setState(() {
        _bands = bands;
        _indices = indices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al calcular las bandas: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bandas de tercios de octava'),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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

    final bands = _bands!;
    final indices = _indices!;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nivel medio por banda (dB)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SizedBox(height: 320, child: _buildChart(bands)),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Frecuencia central [Hz]  (desliza para ver todas las bandas)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Indices agregados por rango de frecuencia',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildIndicesList(indices)),
        ],
      ),
    );
  }

  Widget _buildIndicesList(List<OctaveIndex> indices) {
    return ListView.separated(
      itemCount: indices.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final item = indices[i];
        final isDiff = item.label.startsWith('Diferencia');
        return ListTile(
          dense: true,
          tileColor: isDiff ? Colors.amber.shade50 : null,
          title: Text(
            item.label,
            style: TextStyle(
              fontWeight: isDiff ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
          trailing: Text(
            item.valueDb.isNaN
                ? 'sin datos'
                : '${item.valueDb.toStringAsFixed(3)} dB',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        );
      },
    );
  }

  Widget _buildChart(List<OctaveBand> bands) {
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

    const screenMin = 0.0;
    final screenMax =
        ((maxDb + _dbOffset) + 5).clamp(40.0, 200.0).ceilToDouble();
    final lowestScreenValue = minDb + _dbOffset;
    final effectiveMin =
        lowestScreenValue < 0 ? lowestScreenValue - 5 : screenMin;

    const barWidth = 28.0;
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
}
