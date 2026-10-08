class Product {
  final int id;
  final String name;
  final String? dosageForm;
  final String? strength;
  final String? unitPriceDa;
  final bool isSample;

  Product({
    required this.id,
    required this.name,
    this.dosageForm,
    this.strength,
    this.unitPriceDa,
    this.isSample = false,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      dosageForm: json['dosageForm'],
      strength: json['strength'],
      unitPriceDa: json['unitPriceDa']?.toString(),
      isSample: json['isGiftSample'] == true || json['isSample'] == true,
    );
  }
}
