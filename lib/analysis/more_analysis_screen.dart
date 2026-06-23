import 'package:flutter/material.dart';

import 'fft_processor.dart';
import 'octave_bands_screen.dart';
import 'pcolor_screen.dart';
import 'q_factor_screen.dart';
import 'waterfall_screen.dart';
import 'wav_reader.dart';

/// Menu de opciones de analisis adicionales: bandas de octava, Q-factor,
/// waterfall y mapa de calor. Separado de la pantalla principal del
/// espectro para no robarle espacio vertical al grafico principal.
class MoreAnalysisScreen extends StatelessWidget {
  final SpectrumResult fullSpectrum;
  final WavData wav;

  const MoreAnalysisScreen({
    super.key,
    required this.fullSpectrum,
    required this.wav,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mas analisis'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _OptionCard(
            icon: Icons.bar_chart,
            title: 'Bandas de tercios de octava',
            subtitle: 'Nivel medio (dB) en cada banda de frecuencia',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OctaveBandsScreen(fullSpectrum: fullSpectrum),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _OptionCard(
            icon: Icons.show_chart,
            title: 'Picos de resonancia (Q-factor)',
            subtitle: 'Tabla de frecuencias de resonancia y su factor Q',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => QFactorScreen(fullSpectrum: fullSpectrum),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _OptionCard(
            icon: Icons.waves,
            title: 'Waterfall',
            subtitle: 'Evolucion del espectro en el tiempo (vista 3D)',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WaterfallScreen(wav: wav),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _OptionCard(
            icon: Icons.grid_on,
            title: 'Mapa de calor tiempo-frecuencia',
            subtitle: 'Evolucion del espectro en el tiempo (vista 2D)',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PcolorScreen(wav: wav),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
