import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

import 'fft_processor.dart';

/// Una banda de tercio de octava: su rango de frecuencias y el nivel
/// medio (en dB) de la magnitud del espectro dentro de ese rango.
class OctaveBand {
  final double lowFrequency;
  final double centerFrequency;
  final double highFrequency;
  final double averageDb;

  OctaveBand({
    required this.lowFrequency,
    required this.centerFrequency,
    required this.highFrequency,
    required this.averageDb,
  });
}

/// Puerto a Dart del calculo de bandas de tercios de octava de
/// `compute_fft.m`, usando la misma tabla `terze_ottava.txt`.
class OctaveBandsCalculator {
  /// Carga y parsea la tabla de tercios de octava desde el asset.
  /// Cada fila tiene 3 valores: frecuencia baja, central y alta.
  static Future<List<List<double>>> loadTable() async {
    final raw = await rootBundle.loadString('assets/terze_ottava.txt');
    final rows = <List<double>>[];
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final values = trimmed
          .split(RegExp(r'\s+'))
          .map((s) => double.parse(s))
          .toList();
      if (values.length == 3) {
        rows.add(values);
      }
    }
    return rows;
  }

  /// Calcula el nivel medio (dB) dentro de cada banda, usando el espectro
  /// COMPLETO (no recortado a 1190 Hz, ya que las bandas mas altas llegan
  /// hasta ~11220 Hz).
  ///
  /// Igual que en MATLAB: se omiten la primera y la ultima fila de la
  /// tabla (el bucle original va de `i=2` a `nb=22` sobre 23 filas),
  /// y se usa `10*log10(mag)` (no 20*log10) para el promedio en dB.
  static List<OctaveBand> compute(
    SpectrumResult fullSpectrum,
    List<List<double>> table,
  ) {
    final bands = <OctaveBand>[];

    for (int i = 1; i < table.length - 1; i++) {
      final low = table[i][0];
      final center = table[i][1];
      final high = table[i][2];

      double sumDb = 0.0;
      int count = 0;
      for (int k = 0; k < fullSpectrum.frequencies.length; k++) {
        final f = fullSpectrum.frequencies[k];
        if (f > low && f < high) {
          final mag = fullSpectrum.magnitudes[k];
          // Evitar log(0); en la practica con audio real esto no ocurre.
          final safeMag = mag > 0 ? mag : 1e-12;
          sumDb += 10 * (math.log(safeMag) / math.ln10);
          count++;
        }
      }

      bands.add(OctaveBand(
        lowFrequency: low,
        centerFrequency: center,
        highFrequency: high,
        averageDb: count > 0 ? sumDb / count : double.nan,
      ));
    }

    return bands;
  }
}

/// Un indice agregado: el promedio (en dB) de varias bandas de octava
/// dentro de un rango de frecuencias mas amplio, igual que la seccion
/// "Compute octaves parameters" de `compute_fft.m`.
class OctaveIndex {
  final String label;
  final double valueDb;

  OctaveIndex({required this.label, required this.valueDb});
}

/// Puerto a Dart de la seccion "Compute octaves parameters" de
/// `compute_fft.m`: promedia el nivel de varias bandas de tercios de
/// octava dentro de rangos de frecuencia predefinidos (ej. 80-1000 Hz,
/// 1250-3150 Hz, por octavas completas, etc.), y calcula tambien la
/// diferencia de nivel entre las bandas 80-1000 Hz y 1250-3150 Hz.
class OctaveIndexCalculator {
  // Pares [frecuencia central baja, frecuencia central alta] que
  // delimitan cada grupo de bandas a promediar. Igual que `fpara` en
  // MATLAB.
  static const List<List<double>> _fpara = [
    [80, 8000],
    [80, 1000],
    [1250, 3150],
    [4000, 8000],
    [80, 125],
    [160, 250],
    [250, 400],
    [315, 500],
    [630, 630],
    [800, 1250],
  ];

  static const List<String> _labels = [
    '80 - 8000 Hz (global)',
    '80 - 1000 Hz',
    '1250 - 3150 Hz',
    '4000 - 8000 Hz',
    '80 - 125 Hz',
    '160 - 250 Hz',
    '250 - 400 Hz',
    '315 - 500 Hz',
    '630 Hz',
    '800 - 1250 Hz',
  ];

  static List<OctaveIndex> compute(List<OctaveBand> bands) {
    final values = <double>[];

    for (final pair in _fpara) {
      final lowCenter = pair[0];
      final highCenter = pair[1];

      int i1 = -1;
      int i2 = -1;
      for (int i = 0; i < bands.length; i++) {
        if ((bands[i].centerFrequency - lowCenter).abs() < 0.5) i1 = i;
        if ((bands[i].centerFrequency - highCenter).abs() < 0.5) i2 = i;
      }

      if (i1 == -1 || i2 == -1) {
        values.add(double.nan);
        continue;
      }

      final lo = i1 < i2 ? i1 : i2;
      final hi = i1 < i2 ? i2 : i1;

      double sum = 0;
      int count = 0;
      for (int idx = lo; idx <= hi; idx++) {
        final v = bands[idx].averageDb;
        if (!v.isNaN) {
          sum += v;
          count++;
        }
      }
      values.add(count > 0 ? sum / count : double.nan);
    }

    final results = <OctaveIndex>[];
    for (int k = 0; k < values.length; k++) {
      results.add(OctaveIndex(label: _labels[k], valueDb: values[k]));
      if (k == 2) {
        // Diferencia de nivel entre 80-1000 Hz (indice 1) y 1250-3150 Hz
        // (indice 2), igual que en MATLAB.
        results.add(OctaveIndex(
          label: 'Diferencia 80-1000 vs 1250-3150 Hz',
          valueDb: values[1] - values[2],
        ));
      }
    }

    return results;
  }
}
