import 'dart:convert';

/// Ficha de un instrumento (guitarra en construccion): medidas fisicas
/// de la tapa y lista de grabaciones asociadas.
class InstrumentModel {
  final String id;
  String name;

  // Medidas fisicas (en cm, excepto espesor en mm y peso en g)
  double? upperBoutWidth;   // ancho lobo superior (cm)
  double? waistWidth;       // ancho cintura (cm)
  double? lowerBoutWidth;   // ancho lobo inferior (cm)
  double? totalLength;      // longitud total de la tapa (cm)
  double? thickness;        // espesor medio (mm)
  double? weight;           // peso (g)

  // Grabaciones asociadas (paths de archivos WAV)
  List<String> recordingPaths;

  InstrumentModel({
    required this.id,
    required this.name,
    this.upperBoutWidth,
    this.waistWidth,
    this.lowerBoutWidth,
    this.totalLength,
    this.thickness,
    this.weight,
    List<String>? recordingPaths,
  }) : recordingPaths = recordingPaths ?? [];

  /// Superficie de la tapa en cm², usando la formula de aproximacion
  /// por secciones (3 zonas: lobo superior 30%, cintura 20%, lobo
  /// inferior 50% de la longitud total).
  double? get surfaceCm2 {
    if (upperBoutWidth == null ||
        waistWidth == null ||
        lowerBoutWidth == null ||
        totalLength == null) return null;

    const pi = 3.141592653589793;
    final aUL = upperBoutWidth! / 2;
    final aC = waistWidth! / 2;
    final aLL = lowerBoutWidth! / 2;
    final L = totalLength!;

    // S = pi/4 * (0.30*L*aUL + 0.20*L*aC + 0.50*L*aLL)
    return (pi / 4) *
        (0.30 * L * aUL + 0.20 * L * aC + 0.50 * L * aLL);
  }

  /// Volumen de la tapa en cm³ (superficie × espesor).
  double? get volumeCm3 {
    final s = surfaceCm2;
    if (s == null || thickness == null) return null;
    return s * (thickness! / 10); // espesor de mm a cm
  }

  /// Densidad en g/cm³.
  double? get densityGcm3 {
    final v = volumeCm3;
    if (v == null || weight == null || v == 0) return null;
    return weight! / v;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'upperBoutWidth': upperBoutWidth,
        'waistWidth': waistWidth,
        'lowerBoutWidth': lowerBoutWidth,
        'totalLength': totalLength,
        'thickness': thickness,
        'weight': weight,
        'recordingPaths': recordingPaths,
      };

  factory InstrumentModel.fromJson(Map<String, dynamic> json) =>
      InstrumentModel(
        id: json['id'] as String,
        name: json['name'] as String,
        upperBoutWidth: (json['upperBoutWidth'] as num?)?.toDouble(),
        waistWidth: (json['waistWidth'] as num?)?.toDouble(),
        lowerBoutWidth: (json['lowerBoutWidth'] as num?)?.toDouble(),
        totalLength: (json['totalLength'] as num?)?.toDouble(),
        thickness: (json['thickness'] as num?)?.toDouble(),
        weight: (json['weight'] as num?)?.toDouble(),
        recordingPaths: (json['recordingPaths'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );

  static List<InstrumentModel> listFromJson(String jsonStr) {
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list
        .map((e) => InstrumentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<InstrumentModel> instruments) =>
      jsonEncode(instruments.map((e) => e.toJson()).toList());
}
