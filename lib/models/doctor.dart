class Doctor {
  final int id;
  final String name;
  final String organization;
  final String specialty;
  final String phone;
  final String wilaya;
  final String tier;
  final String status;
  final double? latitude;
  final double? longitude;
  final String? assignedRepName;

  Doctor({
    required this.id,
    required this.name,
    required this.organization,
    required this.specialty,
    required this.phone,
    required this.wilaya,
    required this.tier,
    required this.status,
    this.latitude,
    this.longitude,
    this.assignedRepName,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      organization: json['organization'] ?? '',
      specialty: json['specialty'] ?? 'Médecine Générale',
      phone: json['phone'] ?? '',
      wilaya: json['wilaya'] ?? 'Oran · 31',
      tier: json['tier'] ?? 'A',
      status: json['status'] ?? 'Active',
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      assignedRepName: json['assignedRepName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'organization': organization,
      'specialty': specialty,
      'phone': phone,
      'wilaya': wilaya,
      'tier': tier,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'assignedRepName': assignedRepName,
    };
  }
}
