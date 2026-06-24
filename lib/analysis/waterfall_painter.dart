import 'package:flutter/material.dart';

import 'waterfall_processor.dart';

/// Dibuja el waterfall (vista 2D con profundidad simulada) de un
/// [WaterfallResult]. Reutilizable tanto a pantalla completa como en
/// miniaturas pequenas (ej. para comparar varias grabaciones).
class WaterfallPainter extends CustomPainter {
  final WaterfallResult result;
  final double fMax;
  final Color primaryColor;

  WaterfallPainter(this.result, this.fMax, this.primaryColor);

  @override
  void paint(Canvas canvas, Size size) {
    final freqs = result.frequencies;
    int maxFreqIndex = freqs.length - 1;
    for (int i = 0; i < freqs.length; i++) {
      if (freqs[i] > fMax) {
        maxFreqIndex = i;
        break;
      }
    }

    final maxMag = result.maxMagnitude;
    if (maxMag <= 0) return;

    final nTime = result.times.length;
    final denom = (nTime - 1) < 1 ? 1 : (nTime - 1);

    // El PRIMER instante (k=0, justo en el golpe, el mas alto) se dibuja
    // AL FONDO; los instantes posteriores (decayendo) se acercan hacia
    // delante. Asi el pico mas alto no tapa a los que se forman despues,
    // y se ve la caida de la resonancia hacia el frente.
    // El espaciado se reparte entre el numero de ventanas (nTime), no es
    // un porcentaje fijo del tamano: asi cabe bien tanto con 15 ventanas
    // (miniaturas) como con 30+ (pantalla completa), sin salirse nunca
    // del contenedor.
    final verticalSpacing = (size.height * 0.4) / nTime;
    final horizontalShift = (size.width * 0.12) / nTime;
    final plotHeight = size.height * 0.6 - 6;
    final baseY = size.height - 6;

    // Dibujamos de fondo (k=0, el mas alto) a frente (k=nTime-1, el mas
    // bajo) en ORDEN ASCENDENTE, para que las trazas mas cercanas
    // (mas bajas) se pinten encima al final, sin enmascarar el pico
    // alto del fondo (que sobresale por encima de todas).
    for (int k = 0; k < nTime; k++) {
      final row = result.magnitudes[k];
      final depthFactor = 1.0 - (k / denom);
      final depthIndex = nTime - 1 - k; // posicion visual: 0=frente
      final yOffset = depthIndex * verticalSpacing;
      final xOffset = depthIndex * horizontalShift;
      final widthScale = 1.0 - depthFactor * 0.12;
      final shade = (0.3 + 0.7 * depthFactor).clamp(0.0, 1.0);
      final color = Color.lerp(Colors.blue.shade100, primaryColor, shade)!;

      final usableWidth = (size.width - xOffset) * widthScale;
      final xStart = xOffset + (size.width - xOffset - usableWidth) / 2;

      final path = Path();
      final fillPath = Path();
      bool first = true;

      for (int f = 0; f <= maxFreqIndex; f++) {
        final norm = (row[f] / maxMag).clamp(0.0, 1.0);
        final x = xStart + (f / maxFreqIndex) * usableWidth;
        final y = baseY - yOffset - norm * plotHeight;

        if (first) {
          path.moveTo(x, y);
          fillPath.moveTo(x, baseY - yOffset);
          fillPath.lineTo(x, y);
          first = false;
        } else {
          path.lineTo(x, y);
          fillPath.lineTo(x, y);
        }
      }
      fillPath.lineTo(xStart + usableWidth, baseY - yOffset);
      fillPath.close();

      canvas.drawPath(fillPath, Paint()..color = Colors.white);

      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaterfallPainter oldDelegate) => false;
}
