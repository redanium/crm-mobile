class Product {
  final int id;
  final String name;
  final String? code;
  final String? genericName;
  final String? dosageForm;
  final String? strength;
  final String? boxSize;
  final String? unitPriceDa;
  final String? dnhStatus;
  final bool isSample;

  Product({
    required this.id,
    required this.name,
    this.code,
    this.genericName,
    this.dosageForm,
    this.strength,
    this.boxSize,
    this.unitPriceDa,
    this.dnhStatus,
    this.isSample = false,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      code: json['code'],
      genericName: json['genericName'],
      dosageForm: json['dosageForm'],
      strength: json['strength'],
      boxSize: json['boxSize'],
      unitPriceDa: json['unitPriceDa']?.toString(),
      dnhStatus: json['dnhStatus'],
      isSample: json['isGiftSample'] == true || json['isSample'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'generic_name': genericName,
      'dosage_form': dosageForm,
      'strength': strength,
      'box_size': boxSize,
      'unit_price_da': unitPriceDa,
      'dnh_status': dnhStatus,
      'is_sample': isSample ? 1 : 0,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()) ?? 0,
      name: map['name'] ?? '',
      code: map['code'],
      genericName: map['generic_name'],
      dosageForm: map['dosage_form'],
      strength: map['strength'],
      boxSize: map['box_size'],
      unitPriceDa: map['unit_price_da']?.toString(),
      dnhStatus: map['dnh_status'],
      isSample: map['is_sample'] == 1 || map['is_sample'] == true,
    );
  }
}

class SampleBatch {
  final int id;
  final String prodId;
  final String brandName;
  final String expiry;
  final int quantity;
  final int initialQuantity;
  final String unit;
  final bool isAllocated;

  bool get isExpired {
    final parsed = DateTime.tryParse(expiry);
    if (parsed == null) return false;
    final expiresAt = DateTime(parsed.year, parsed.month, parsed.day, 23, 59, 59, 999);
    return expiresAt.isBefore(DateTime.now());
  }

  SampleBatch({
    required this.id,
    required this.prodId,
    required this.brandName,
    required this.expiry,
    required this.quantity,
    int? initialQuantity,
    this.unit = 'boîte',
    this.isAllocated = false,
  }) : initialQuantity = initialQuantity ?? quantity;

  factory SampleBatch.fromJson(Map<String, dynamic> json) {
    return SampleBatch(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      prodId: json['prodId'] ?? json['prod_id'] ?? '',
      brandName: json['brandName'] ?? json['brand_name'] ?? '',
      expiry: json['expiry'] ?? '',
      quantity: json['quantity'] is int ? json['quantity'] : int.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
      initialQuantity: json['initialQuantity'] is int ? json['initialQuantity'] : int.tryParse(json['initialQuantity']?.toString() ?? '') ?? int.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
      unit: json['unit'] ?? 'boîte',
      isAllocated: json['allocated'] == true || json['isAllocated'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'prod_id': prodId,
      'brand_name': brandName,
      'expiry': expiry,
      'quantity': quantity,
      'initial_quantity': initialQuantity,
      'unit': unit,
      'is_allocated': isAllocated ? 1 : 0,
    };
  }

  factory SampleBatch.fromMap(Map<String, dynamic> map) {
    return SampleBatch(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()) ?? 0,
      prodId: map['prod_id'] ?? '',
      brandName: map['brand_name'] ?? '',
      expiry: map['expiry'] ?? '',
      quantity: map['quantity'] is int ? map['quantity'] : int.tryParse(map['quantity']?.toString() ?? '0') ?? 0,
      initialQuantity: map['initial_quantity'] is int ? map['initial_quantity'] : int.tryParse(map['initial_quantity']?.toString() ?? '') ?? int.tryParse(map['quantity']?.toString() ?? '0') ?? 0,
      unit: map['unit'] ?? 'boîte',
      isAllocated: map['is_allocated'] == 1 || map['is_allocated'] == true,
    );
  }
}

class PromotionalGift {
  final int id;
  final String giftId;
  final String name;
  final int quantity;
  final int initialQuantity;
  final int distributed;
  final bool isAllocated;

  PromotionalGift({
    required this.id,
    required this.giftId,
    required this.name,
    required this.quantity,
    int? initialQuantity,
    this.distributed = 0,
    this.isAllocated = false,
  }) : initialQuantity = initialQuantity ?? quantity;

  factory PromotionalGift.fromJson(Map<String, dynamic> json) {
    return PromotionalGift(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      giftId: json['giftId'] ?? json['gift_id'] ?? '',
      name: json['name'] ?? '',
      quantity: json['quantity'] is int ? json['quantity'] : int.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
      initialQuantity: json['initialQuantity'] is int ? json['initialQuantity'] : int.tryParse(json['initialQuantity']?.toString() ?? '') ?? int.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
      distributed: json['distributed'] is int ? json['distributed'] : int.tryParse(json['distributed']?.toString() ?? '0') ?? 0,
      isAllocated: json['allocated'] == true || json['isAllocated'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gift_id': giftId,
      'name': name,
      'quantity': quantity,
      'initial_quantity': initialQuantity,
      'distributed': distributed,
      'is_allocated': isAllocated ? 1 : 0,
    };
  }

  factory PromotionalGift.fromMap(Map<String, dynamic> map) {
    return PromotionalGift(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()) ?? 0,
      giftId: map['gift_id'] ?? '',
      name: map['name'] ?? '',
      quantity: map['quantity'] is int ? map['quantity'] : int.tryParse(map['quantity']?.toString() ?? '0') ?? 0,
      initialQuantity: map['initial_quantity'] is int ? map['initial_quantity'] : int.tryParse(map['initial_quantity']?.toString() ?? '') ?? int.tryParse(map['quantity']?.toString() ?? '0') ?? 0,
      distributed: map['distributed'] is int ? map['distributed'] : int.tryParse(map['distributed']?.toString() ?? '0') ?? 0,
      isAllocated: map['is_allocated'] == 1 || map['is_allocated'] == true,
    );
  }
}
