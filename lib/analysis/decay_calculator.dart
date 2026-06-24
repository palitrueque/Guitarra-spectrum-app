import 'dart:math' as math;

import 'q_factor.dart';
import 'waterfall_processor.dart';

/// Tiempo de decaimiento de un pico de resonancia: cuanto tarda su
/// amplitud en caer un numero de dB determinado (por defecto -20dB,
/// el "T20") desde su valor maximo.
class DecayResult {
  final double frequency;
  final double? t20Seconds; // null si no llega a caer ese nivel a tiempo

  DecayResult({required this.frequency, required this.t20Seconds});
}

/// Calcula el tiempo de decaimiento de cada pico de resonancia usando
/// los datos de evolucion temporal ya calculados para el waterfall:
/// para cada pico, sigue la amplitud de esa frecuencia a lo largo de
/// las ventanas de tiempo y mide cuanto tarda en caer -20dB desde su
/// valor maximo.
class DecayCalculator {
  static List<DecayResult> compute(
    WaterfallResult waterfall,
    List<ResonancePeak> peaks, {
    double dropDb = 20,
  }) {
    final freqs = waterfall.frequencies;
    final freqResolution = freqs.length > 1 ? freqs[1] - freqs[0] : 1.0;
    final tshift =
        waterfall.times.length > 1 ? waterfall.times[1] - waterfall.times[0] : 0.0;

    final results = <DecayResult>[];

    for (final peak in peaks) {
      final freqIndex =
          (peak.frequency / freqResolution).round().clamp(0, freqs.length - 1);

      final series = [
        for (final row in waterfall.magnitudes) row[freqIndex],
      ];

      // Usamos el maximo de la serie como referencia (puede no ser
      // exactamente el primer instante, por la forma de la ventana).
      int refIndex = 0;
      double refValue = series.isNotEmpty ? series[0] : 0;
      for (int i = 1; i < series.length; i++) {
        if (series[i] > refValue) {
          refValue = series[i];
          refIndex = i;
        }
      }

      double? t20;
      if (refValue > 0) {
        for (int i = refIndex; i < series.length; i++) {
          if (series[i] <= 0) continue;
          final db = 20 * (math.log(series[i] / refValue) / math.ln10);
          if (db <= -dropDb) {
            t20 = (i - refIndex) * tshift;
            break;
          }
        }
      }

      results.add(DecayResult(frequency: peak.frequency, t20Seconds: t20));
    }

    return results;
  }
}
