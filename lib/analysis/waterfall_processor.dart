import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

import 'wav_reader.dart';

/// Resultado del calculo "tiempo-frecuencia": una matriz de magnitudes
/// indexada por [indice de tiempo][indice de frecuencia], mas los
/// vectores de tiempos y frecuencias correspondientes.
///
/// Puerto a Dart de la logica compartida de `plot_wf.m` y `plot_pc.m`:
/// ambos calculan exactamente lo mismo (un espectro por cada ventana de
/// Hann desplazada en el tiempo), solo cambia como se visualiza despues
/// (waterfall 3D vs mapa de calor 2D).
class WaterfallResult {
  final List<double> frequencies;
  final List<double> times;
  final List<List<double>> magnitudes; // [timeIndex][freqIndex]

  WaterfallResult({
    required this.frequencies,
    required this.times,
    required this.magnitudes,
  });

  double get maxMagnitude {
    double m = 0;
    for (final row in magnitudes) {
      for (final v in row) {
        if (v > m) m = v;
      }
    }
    return m;
  }
}

class WaterfallProcessor {
  static WaterfallResult compute(
    WavData wav, {
    int nfft = 65536,
    double thannSeconds = 0.1,
    double tshift = 0.02,
    int nshift = 15,
    double ythreshold = 0.01,
  }) {
    final fs = wav.sampleRate.toDouble();
    final allSamples = wav.samples;

    // Mismo recorte de silencio inicial que en FftProcessor / prepare_yt.m
    int startIndex = 0;
    bool found = false;
    for (int i = 0; i < allSamples.length; i++) {
      if (allSamples[i] > ythreshold) {
        startIndex = i;
        found = true;
        break;
      }
    }
    final y = found ? allSamples.sublist(startIndex) : allSamples;
    final n = y.length;

    final freqResolution = fs / nfft;
    final halfLen = nfft ~/ 2 + 1;
    final frequencies =
        List<double>.generate(halfLen, (k) => k * freqResolution);
    final times = List<double>.generate(nshift, (k) => k * tshift);

    final scale = 2.0 * math.sqrt(2 * math.pi);
    final fft = FFT(nfft);
    final magnitudes = <List<double>>[];

    for (int k = 0; k < nshift; k++) {
      final windowed = Float64List(nfft);
      final shiftSeconds = k * tshift;
      final limit = math.min(n, nfft);

      for (int i = 0; i < limit; i++) {
        final tt = i / fs - shiftSeconds;
        if (tt >= 0 && tt < thannSeconds) {
          final hw = 0.5 * (1 - math.cos(2 * math.pi * tt / thannSeconds));
          windowed[i] = y[i] * hw;
        }
      }

      // Eliminar componente DC (resta de la media), igual que en MATLAB.
      double mean = 0.0;
      for (final v in windowed) {
        mean += v;
      }
      mean /= nfft;
      for (int i = 0; i < nfft; i++) {
        windowed[i] -= mean;
      }

      final freqDomain = fft.realFft(windowed);
      final half = freqDomain.discardConjugates();
      final rawMagnitudes = half.magnitudes();

      final row = List<double>.filled(halfLen, 0.0);
      for (int f = 0; f < halfLen; f++) {
        row[f] = rawMagnitudes[f] * scale;
      }
      magnitudes.add(row);
    }

    return WaterfallResult(
      frequencies: frequencies,
      times: times,
      magnitudes: magnitudes,
    );
  }
}
