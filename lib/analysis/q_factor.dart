import 'dart:math' as math;

import 'fft_processor.dart';

/// Un pico de resonancia detectado: su frecuencia, amplitud, y el
/// factor de calidad Q (null si no se pudo determinar, equivalente al
/// NaN de MATLAB cuando no se encuentra ningun cruce de -3dB).
class ResonancePeak {
  final double frequency;
  final double amplitude;
  final double? qFactor;

  ResonancePeak({
    required this.frequency,
    required this.amplitude,
    required this.qFactor,
  });
}

/// Puerto a Dart del calculo de Q-factor de `compute_fft.m`: para cada
/// uno de los `nq` picos mas altos del espectro (de mayor a menor
/// amplitud), busca los cruces de -3dB (amplitud/sqrt(2)) a ambos lados
/// para estimar el ancho de banda de resonancia, y de ahi el factor Q.
class QFactorCalculator {
  static List<ResonancePeak> computePeaks(
    SpectrumResult fullSpectrum, {
    int nq = 15,
  }) {
    final f = fullSpectrum.frequencies;
    final mag = fullSpectrum.magnitudes;
    final n = mag.length;

    // Copia de trabajo: cada vez que procesamos un pico, lo "borramos"
    // (lo ponemos a 0) para que el siguiente maximo encontrado sea un
    // pico distinto, igual que `stmp` en MATLAB.
    final stmp = List<double>.from(mag);

    final peaks = <ResonancePeak>[];

    for (int k = 0; k < nq; k++) {
      // Buscar el maximo actual.
      int imax = 0;
      double sqk = stmp[0];
      for (int i = 1; i < n; i++) {
        if (stmp[i] > sqk) {
          sqk = stmp[i];
          imax = i;
        }
      }

      if (sqk <= 0) {
        // Ya no quedan picos utiles.
        break;
      }

      final fq = f[imax];
      final threshold = sqk / math.sqrt2;

      // Lado derecho (frecuencias mayores): avanzar mientras la curva
      // siga bajando, buscando el primer cruce por debajo de -3dB.
      double fhi = 0;
      int i = 1;
      while (imax + i + 1 < n && mag[imax + i] > mag[imax + i + 1]) {
        if (fhi == 0 && mag[imax + i] < threshold) {
          fhi = f[imax + i];
        }
        i++;
      }
      final hiEnd = (imax + i).clamp(0, n - 1);
      for (int idx = imax; idx <= hiEnd; idx++) {
        stmp[idx] = 0;
      }

      // Lado izquierdo (frecuencias menores): mismo proceso hacia atras.
      double flo = 0;
      int j = 1;
      while (j < imax && imax - j - 1 >= 0 && mag[imax - j] > mag[imax - j - 1]) {
        if (flo == 0 && mag[imax - j] < threshold) {
          flo = f[imax - j];
        }
        j++;
      }
      final loStart = (imax - j).clamp(0, n - 1);
      for (int idx = loStart; idx <= imax; idx++) {
        stmp[idx] = 0;
      }

      double? qFactor;
      if (flo == 0 && fhi == 0) {
        qFactor = null;
      } else if (flo == 0) {
        qFactor = fq / (2 * (fhi - fq));
      } else if (fhi == 0) {
        qFactor = fq / (2 * (fq - flo));
      } else {
        qFactor = fq / (fhi - flo);
      }

      peaks.add(ResonancePeak(
        frequency: fq,
        amplitude: sqk,
        qFactor: qFactor,
      ));
    }

    // Ordenar por frecuencia ascendente, igual que en MATLAB.
    peaks.sort((a, b) => a.frequency.compareTo(b.frequency));

    return peaks;
  }
}
