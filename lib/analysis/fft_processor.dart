import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

import 'wav_reader.dart';

/// Resultado del calculo de espectro: frecuencias (Hz) y su magnitud
/// correspondiente, ya recortado a la mitad util del espectro (0 a Fs/2).
class SpectrumResult {
  final List<double> frequencies;
  final List<double> magnitudes;
  final double frequencyResolution;
  final double peakFrequency;
  final double peakMagnitude;

  SpectrumResult({
    required this.frequencies,
    required this.magnitudes,
    required this.frequencyResolution,
    required this.peakFrequency,
    required this.peakMagnitude,
  });

  /// Recorta el espectro a un rango de frecuencias [fMin, fMax],
  /// util para mostrar solo 0-1190 Hz como en la Figura 2 de MATLAB.
  SpectrumResult sliceRange(double fMin, double fMax) {
    final freqs = <double>[];
    final mags = <double>[];
    for (int i = 0; i < frequencies.length; i++) {
      if (frequencies[i] >= fMin && frequencies[i] <= fMax) {
        freqs.add(frequencies[i]);
        mags.add(magnitudes[i]);
      }
    }
    double pf = 0, pm = -1;
    for (int i = 0; i < mags.length; i++) {
      if (mags[i] > pm) {
        pm = mags[i];
        pf = freqs[i];
      }
    }
    return SpectrumResult(
      frequencies: freqs,
      magnitudes: mags,
      frequencyResolution: frequencyResolution,
      peakFrequency: pf,
      peakMagnitude: pm,
    );
  }
}

/// Puerto a Dart de la logica de `compute_fft.m`:
/// ventana de Hann (100 ms) + zero-padding + FFT + magnitud,
/// con el mismo factor de escala sqrt(2*pi) usado en el script original
/// para mantener consistencia con las mediciones previas en MATLAB.
class FftProcessor {
  /// nfft: numero de muestras de la FFT (con zero-padding). 65536 (2^16)
  /// por defecto, igual que en el script de MATLAB.
  /// thannSeconds: duracion de la ventana de Hann aplicada al inicio
  /// de la grabacion (100 ms por defecto, igual que en MATLAB).
  static SpectrumResult computeSpectrum(
    WavData wav, {
    int nfft = 65536,
    double thannSeconds = 0.1,
  }) {
    final fs = wav.sampleRate.toDouble();
    final y = wav.samples;
    final n = y.length;

    // 1. Ventana de Hann aplicada solo durante los primeros `thannSeconds`,
    //    el resto de la senal queda a cero (igual que en MATLAB:
    //    hw = 0.5*(1-cos(2*pi*t/Thann)).*(t<Thann)).
    final yw = Float64List(n);
    for (int i = 0; i < n; i++) {
      final t = i / fs;
      if (t < thannSeconds) {
        final hw = 0.5 * (1 - math.cos(2 * math.pi * t / thannSeconds));
        yw[i] = y[i] * hw;
      } else {
        yw[i] = 0.0;
      }
    }

    // 2. Eliminar la componente DC (resta de la media), igual que en MATLAB.
    double mean = 0.0;
    for (final v in yw) {
      mean += v;
    }
    mean /= n;
    for (int i = 0; i < n; i++) {
      yw[i] -= mean;
    }

    // 3. Zero-padding hasta `nfft` muestras (o truncado si la grabacion
    //    fuese mas larga que nfft, caso poco probable aqui).
    final padded = Float64List(nfft);
    final copyLen = math.min(n, nfft);
    for (int i = 0; i < copyLen; i++) {
      padded[i] = yw[i];
    }

    // 4. FFT
    final fft = FFT(nfft);
    final freqDomain = fft.realFft(padded);

    // 5. Magnitud: 2*abs(Y) * sqrt(2*pi), igual que en MATLAB.
    //    discardConjugates() se queda solo con la mitad util del espectro
    //    (0 a Fs/2), equivalente a Y(1:nfft/2+1) en MATLAB.
    final half = freqDomain.discardConjugates();
    final rawMagnitudes = half.magnitudes();
    final scale = 2.0 * math.sqrt(2 * math.pi);

    final magnitudes = List<double>.filled(rawMagnitudes.length, 0.0);
    final frequencies = List<double>.filled(rawMagnitudes.length, 0.0);
    final freqResolution = fs / nfft;

    double peakMag = -1;
    double peakFreq = 0;
    for (int k = 0; k < rawMagnitudes.length; k++) {
      magnitudes[k] = rawMagnitudes[k] * scale;
      frequencies[k] = k * freqResolution;
      if (magnitudes[k] > peakMag) {
        peakMag = magnitudes[k];
        peakFreq = frequencies[k];
      }
    }

    return SpectrumResult(
      frequencies: frequencies,
      magnitudes: magnitudes,
      frequencyResolution: freqResolution,
      peakFrequency: peakFreq,
      peakMagnitude: peakMag,
    );
  }
}
