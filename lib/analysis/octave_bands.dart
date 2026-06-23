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
