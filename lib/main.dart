import 'package:flutter/material.dart';

import 'library_screen.dart';

void main() {
  runApp(const GuitarraSpectrumApp());
}

class GuitarraSpectrumApp extends StatelessWidget {
  const GuitarraSpectrumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guitarra Spectrum',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const LibraryScreen(),
    );
  }
}
