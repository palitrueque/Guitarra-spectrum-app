import 'dart:io';
import 'dart:typed_data';

/// Resultado de leer un archivo WAV: las muestras de audio (normalizadas
/// entre -1.0 y 1.0) y el sample rate original del archivo.
class WavData {
  final List<double> samples;
  final int sampleRate;
  final int numChannels;
  final int bitsPerSample;
  final int audioFormat; // 1=PCM, 3=float

  WavData({
    required this.samples,
    required this.sampleRate,
    required this.numChannels,
    required this.bitsPerSample,
    required this.audioFormat,
  });
}

/// Lee un archivo WAV PCM (8/16/24/32-bit) y devuelve sus muestras
/// como doubles normalizados, junto con el sample rate.
///
/// Equivalente a cargar `y` y `Fs` en el script de MATLAB.
class WavReader {
  static Future<WavData> readFile(String path) async {
    final bytes = await File(path).readAsBytes();
    return parseBytes(bytes);
  }

  static WavData parseBytes(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);

    // Cabecera RIFF: 'RIFF' + size + 'WAVE'
    final riff = String.fromCharCodes(bytes, 0, 4);
    final wave = String.fromCharCodes(bytes, 8, 12);
    if (riff != 'RIFF' || wave != 'WAVE') {
      throw const FormatException('No es un archivo WAV valido (falta cabecera RIFF/WAVE)');
    }

    int offset = 12;
    int sampleRate = 44100;
    int bitsPerSample = 16;
    int numChannels = 1;
    int audioFormat = 1; // 1 = PCM
    int dataOffset = -1;
    int dataSize = 0;

    // Recorremos los "chunks" del WAV buscando 'fmt ' y 'data'
    while (offset + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes, offset, offset + 4);
      final chunkSize = data.getUint32(offset + 4, Endian.little);
      final chunkDataStart = offset + 8;

      if (chunkId == 'fmt ') {
        audioFormat = data.getUint16(chunkDataStart, Endian.little);
        numChannels = data.getUint16(chunkDataStart + 2, Endian.little);
        sampleRate = data.getUint32(chunkDataStart + 4, Endian.little);
        bitsPerSample = data.getUint16(chunkDataStart + 14, Endian.little);
      } else if (chunkId == 'data') {
        dataOffset = chunkDataStart;
        dataSize = chunkSize;
      }

      // Los chunks van alineados a 2 bytes
      offset = chunkDataStart + chunkSize + (chunkSize % 2);
    }

    if (dataOffset == -1) {
      throw const FormatException('No se encontro el chunk "data" en el WAV');
    }

    if (audioFormat != 1 && audioFormat != 3) {
      throw FormatException('Formato de audio WAV no soportado: $audioFormat (solo PCM)');
    }

    final bytesPerSample = bitsPerSample ~/ 8;
    final totalSamples = dataSize ~/ bytesPerSample;
    final samplesPerChannel = totalSamples ~/ numChannels;

    final samples = List<double>.filled(samplesPerChannel, 0.0);

    // Si hay varios canales, promediamos a mono (suficiente para el analisis
    // de espectro; igual que tener un solo canal `y` en MATLAB).
    for (int i = 0; i < samplesPerChannel; i++) {
      double sum = 0.0;
      for (int ch = 0; ch < numChannels; ch++) {
        final sampleIndex = i * numChannels + ch;
        final byteIndex = dataOffset + sampleIndex * bytesPerSample;
        double value;

        switch (bitsPerSample) {
          case 16:
            value = data.getInt16(byteIndex, Endian.little) / 32768.0;
            break;
          case 8:
            value = (bytes[byteIndex] - 128) / 128.0;
            break;
          case 24:
            final b0 = bytes[byteIndex];
            final b1 = bytes[byteIndex + 1];
            final b2 = bytes[byteIndex + 2];
            int v = b0 | (b1 << 8) | (b2 << 16);
            if (v & 0x800000 != 0) v -= 0x1000000;
            value = v / 8388608.0;
            break;
          case 32:
            if (audioFormat == 3) {
              value = data.getFloat32(byteIndex, Endian.little).toDouble();
            } else {
              value = data.getInt32(byteIndex, Endian.little) / 2147483648.0;
            }
            break;
          default:
            throw FormatException('Bits por muestra no soportados: $bitsPerSample');
        }
        sum += value;
      }
      samples[i] = sum / numChannels;
    }

    return WavData(
      samples: samples,
      sampleRate: sampleRate,
      numChannels: 1, // ya hemos mezclado a mono
      bitsPerSample: bitsPerSample,
      audioFormat: audioFormat,
    );
  }
}
