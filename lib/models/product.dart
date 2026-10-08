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
  final String unit;

  SampleBatch({
    required this.id,
    required this.prodId,
    required this.brandName,
    required this.expiry,
    required this.quantity,
    this.unit = 'boîte',
  });

  factory SampleBatch.fromJson(Map<String, dynamic> json) {
    return SampleBatch(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      prodId: json['prodId'] ?? json['prod_id'] ?? '',
      brandName: json['brandName'] ?? json['brand_name'] ?? '',
      expiry: json['expiry'] ?? '',
      quantity: json['quantity'] is int ? json['quantity'] : int.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
      unit: json['unit'] ?? 'boîte',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'prod_id': prodId,
      'brand_name': brandName,
      'expiry': expiry,
      'quantity': quantity,
      'unit': unit,
    };
  }

  factory SampleBatch.fromMap(Map<String, dynamic> map) {
    return SampleBatch(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()) ?? 0,
      prodId: map['prod_id'] ?? '',
      brandName: map['brand_name'] ?? '',
      expiry: map['expiry'] ?? '',
      quantity: map['quantity'] is int ? map['quantity'] : int.tryParse(map['quantity']?.toString() ?? '0') ?? 0,
      unit: map['unit'] ?? 'boîte',
    );
  }
}

class PromotionalGift {
  final int id;
  final String giftId;
  final String name;
  final int quantity;
  final int distributed;

  PromotionalGift({
    required this.id,
    required this.giftId,
    required this.name,
    required this.quantity,
    this.distributed = 0,
  });

  factory PromotionalGift.fromJson(Map<String, dynamic> json) {
    return PromotionalGift(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      giftId: json['giftId'] ?? json['gift_id'] ?? '',
      name: json['name'] ?? '',
      quantity: json['quantity'] is int ? json['quantity'] : int.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
      distributed: json['distributed'] is int ? json['distributed'] : int.tryParse(json['distributed']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gift_id': giftId,
      'name': name,
      'quantity': quantity,
      'distributed': distributed,
    };
  }

  factory PromotionalGift.fromMap(Map<String, dynamic> map) {
    return PromotionalGift(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()) ?? 0,
      giftId: map['gift_id'] ?? '',
      name: map['name'] ?? '',
      quantity: map['quantity'] is int ? map['quantity'] : int.tryParse(map['quantity']?.toString() ?? '0') ?? 0,
      distributed: map['distributed'] is int ? map['distributed'] : int.tryParse(map['distributed']?.toString() ?? '0') ?? 0,
    );
  }
}
