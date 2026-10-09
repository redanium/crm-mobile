class GeoWilaya {
  final String code;
  final String name;

  const GeoWilaya({required this.code, required this.name});

  factory GeoWilaya.fromJson(Map<String, dynamic> json) => GeoWilaya(
        code: json['code']?.toString() ?? '',
        name: json['nameFr']?.toString() ?? '',
      );
}

class GeoCommune {
  final String code;
  final String name;

  const GeoCommune({required this.code, required this.name});

  factory GeoCommune.fromJson(Map<String, dynamic> json) => GeoCommune(
        code: json['code']?.toString() ?? '',
        name: json['nameFr']?.toString() ?? '',
      );
}

class GeoFacility {
  final String id;
  final String nameFr;
  final String? nameAr;
  final String wilayaCode;
  final String wilayaName;
  final String communeName;
  final String category;
  final String categoryLabelFr;
  final String subType;
  final String sector;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? phone;

  const GeoFacility({
    required this.id,
    required this.nameFr,
    this.nameAr,
    required this.wilayaCode,
    required this.wilayaName,
    required this.communeName,
    required this.category,
    required this.categoryLabelFr,
    required this.subType,
    required this.sector,
    this.latitude,
    this.longitude,
    this.address,
    this.phone,
  });

  factory GeoFacility.fromJson(Map<String, dynamic> json) => GeoFacility(
        id: json['id']?.toString() ?? '',
        nameFr: json['nameFr']?.toString() ?? json['name']?.toString() ?? '',
        nameAr: json['nameAr']?.toString(),
        wilayaCode: json['wilayaCode']?.toString() ?? '',
        wilayaName: json['wilayaName']?.toString() ?? '',
        communeName: json['communeName']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        categoryLabelFr: json['categoryLabelFr']?.toString() ?? '',
        subType: json['subType']?.toString() ?? '',
        sector: json['sector']?.toString() ?? '',
        latitude: _asDouble(json['latitude']),
        longitude: _asDouble(json['longitude']),
        address: json['address']?.toString(),
        phone: json['phone']?.toString(),
      );

  Map<String, dynamic> toCrmContactBody() {
    final isPharmacy = category == 'pharmacy';
    final isManufacturer = category == 'manufacturer';
    final isHospital = category == 'hospital';
    return {
      'name': nameFr,
      'organization': nameFr,
      'role': isPharmacy
          ? 'Pharmacien Titulaire'
          : isManufacturer
              ? 'Directeur de Site Industriel'
              : isHospital
                  ? 'Médecin Chef / Directeur CHU'
                  : 'Médecin Coordinateur',
      'phone': phone ?? '',
      'wilaya': '$wilayaName · $wilayaCode',
      'facilityType': isHospital
          ? 'Hospital'
          : category == 'clinic'
              ? 'Clinic'
              : isPharmacy
                  ? 'Pharmacy'
                  : 'Hospital',
      'sector': sector == 'private' ? 'Private' : 'Public',
      'commune': communeName,
      'specialty': isPharmacy
          ? 'Officine de Ville'
          : isManufacturer
              ? 'Production Pharmaceutique'
              : categoryLabelFr,
      'latitude': latitude,
      'longitude': longitude,
      'notes': '[GeoAlgeria Validé] $categoryLabelFr - Commune: $communeName${nameAr == null ? '' : ' ($nameAr)'} · ID: $id',
      'status': 'Active',
    };
  }
}

double? _asDouble(dynamic value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
