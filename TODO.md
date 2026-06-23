# TODO - Guitarra Spectrum App

Lista de ideas y mejoras pendientes, para no perderlas entre sesiones.

## Pendientes funcionales

- [ ] **Deteccion de multiples golpes en una sola grabacion**: actualmente
  el analisis solo usa el primer golpe detectado (ventana de Hann de 100ms
  desde el primer instante que supera el umbral). Seria util poder grabar
  varios golpes en distintas zonas de la tapa en una sola toma, detectarlos
  automaticamente por umbral de energia, y analizar cada uno por separado,
  permitiendo etiquetar la zona de cada golpe (ej. "borde superior", "centro").

- [ ] Bandas de tercios de octava (Figura 4 de MATLAB) - en progreso
- [ ] Tabla de Q-factor (picos de resonancia)
- [ ] Vista waterfall (evolucion del espectro en el tiempo, plot_wf.m)
- [ ] Vista pcolor (mapa de calor tiempo-frecuencia, plot_pc.m)
- [ ] Vista en escala logaritmica / dB (Figura 1 de MATLAB)

## Notas tecnicas

- El analisis FFT replica `compute_fft.m`: ventana de Hann de 100ms,
  zero-padding a 65536 muestras, factor de escala sqrt(2*pi).
- `prepare_yt.m` recorta la senal al primer instante que supera un umbral
  (ythreshold = 0.01 en el script original) antes de aplicar la ventana.
