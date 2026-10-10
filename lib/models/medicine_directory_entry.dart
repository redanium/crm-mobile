class MedicineDirectoryEntry {
  final String cis;
  final String name;
  final String dosageForm;
  final String holder;
  final String authorizationDate;
  final List<String> routes;
  final List<MedicineCompositionEntry> composition;
  final List<String> conditions;

  const MedicineDirectoryEntry({
    required this.cis,
    required this.name,
    this.dosageForm = '',
    this.holder = '',
    this.authorizationDate = '',
    this.routes = const [],
    this.composition = const [],
    this.conditions = const [],
  });

  factory MedicineDirectoryEntry.fromJson(Map<String, dynamic> json) {
    return MedicineDirectoryEntry(
      cis: json['cis']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      dosageForm: json['dosageForm']?.toString() ?? '',
      holder: json['holder']?.toString() ?? '',
      authorizationDate: json['authorizationDate']?.toString() ?? '',
      routes: (json['routes'] as List<dynamic>? ?? []).map((value) => value.toString()).toList(),
      composition: (json['composition'] as List<dynamic>? ?? [])
          .map((value) => MedicineCompositionEntry.fromJson(Map<String, dynamic>.from(value as Map)))
          .toList(),
      conditions: (json['conditions'] as List<dynamic>? ?? []).map((value) => value.toString()).toList(),
    );
  }
}

class MedicineCompositionEntry {
  final String substance;
  final String dosage;

  const MedicineCompositionEntry({required this.substance, required this.dosage});

  factory MedicineCompositionEntry.fromJson(Map<String, dynamic> json) {
    return MedicineCompositionEntry(
      substance: json['substance']?.toString() ?? '',
      dosage: json['dosage']?.toString() ?? '',
    );
  }
}
