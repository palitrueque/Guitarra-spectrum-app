import 'dart:math' as math;

/// Marcador de una nota musical en el grafico: su frecuencia en Hz,
/// y si es una nota "de octava" (E2, E3, E4, E5, D6 -> linea gruesa con
/// etiqueta) o una nota intermedia (linea fina sin etiqueta).
class NoteMarker {
  final double frequency;
  final String? label;
  final bool isOctaveMarker;

  const NoteMarker({
    required this.frequency,
    this.label,
    this.isOctaveMarker = false,
  });
}

/// Puerto a Dart del "mapa de acordes" de `compute_fft.m`: genera las
/// frecuencias de las notas musicales desde E2 hasta D6, usando la misma
/// formula de temperamento igual (440*2^((n-49)/12)) que el script original.
class NoteMap {
  static double _frequencyOf(int n) =>
      440 * math.pow(2, (n - 49) / 12).toDouble();

  static List<NoteMarker> buildMarkers() {
    const e2 = 20;
    final noctave = List.generate(4, (i) => e2 + i * 12); // E2, E3, E4, E5
    const octaveNames = ['E2', 'E3', 'E4', 'E5'];
    // Notas dentro de cada octava (offsets desde la nota base E),
    // igual que `notes = [0 1 3 5 7 8 10]` en MATLAB.
    const notesOffsets = [0, 1, 3, 5, 7, 8, 10];

    final markers = <NoteMarker>[];

    // Lineas finas: todas las notas de cada octava (sin etiqueta).
    for (final base in noctave) {
      for (final off in notesOffsets) {
        markers.add(NoteMarker(frequency: _frequencyOf(base + off)));
      }
    }

    // Lineas gruesas con etiqueta: E2, E3, E4, E5 y D6 (la ultima nota
    // de la ultima octava), igual que `xtick', [freqno freqnn(end)]`.
    for (int i = 0; i < noctave.length; i++) {
      markers.add(NoteMarker(
        frequency: _frequencyOf(noctave[i]),
        label: octaveNames[i],
        isOctaveMarker: true,
      ));
    }
    markers.add(NoteMarker(
      frequency: _frequencyOf(noctave.last + 10),
      label: 'D6',
      isOctaveMarker: true,
    ));

    return markers;
  }
}
