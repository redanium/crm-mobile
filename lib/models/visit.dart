import 'dart:convert';

class Visit {
  final int? id;
  final String? clientUuid;
  final String accountName;
  final String activityType;
  final String repName;
  final String repId;
  final String? purpose;
  final String? productsDiscussed;
  final String? samplesDistributed;
  final String? giftsDistributed;
  final List<Map<String, dynamic>> inventoryDistributions;
  final String? feedbackNotes;
  final String? nextFollowupDate;
  final double? latitude;
  final double? longitude;
  final String? wilaya;
  final String? facilityName;
  final String status;
  final DateTime scheduledAt;

  Visit({
    this.id,
    this.clientUuid,
    required this.accountName,
    required this.activityType,
    required this.repName,
    required this.repId,
    this.purpose,
    this.productsDiscussed,
    this.samplesDistributed,
    this.giftsDistributed,
    this.inventoryDistributions = const [],
    this.feedbackNotes,
    this.nextFollowupDate,
    this.latitude,
    this.longitude,
    this.wilaya,
    this.facilityName,
    this.status = 'Confirmed',
    DateTime? scheduledAt,
  }) : scheduledAt = scheduledAt ?? DateTime.now();

  factory Visit.fromJson(Map<String, dynamic> json) {
    final rawInventory = json['inventoryDistributions'] ?? json['inventory_distributions'];
    final inventory = rawInventory is String
        ? (jsonDecode(rawInventory) as List<dynamic>? ?? [])
        : (rawInventory as List<dynamic>? ?? []);
    return Visit(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      clientUuid: json['clientUuid'] ?? json['client_uuid'],
      accountName: json['accountName'] ?? json['account_name'] ?? '',
      activityType: json['activityType'] ?? json['activity_type'] ?? 'Visite Médicale',
      repName: json['repName'] ?? json['rep_name'] ?? 'Délégué Médical',
      repId: json['repId'] ?? json['rep_id'] ?? '',
      purpose: json['purpose'],
      productsDiscussed: json['productsDiscussed'] ?? json['products_discussed'],
      samplesDistributed: json['samplesDistributed'] ?? json['samples_distributed'],
      giftsDistributed: json['giftsDistributed'] ?? json['gifts_distributed'],
      inventoryDistributions: inventory.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      feedbackNotes: json['feedbackNotes'] ?? json['feedback_notes'] ?? json['notes'],
      nextFollowupDate: json['nextFollowupDate'] ?? json['next_followup_date'],
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      wilaya: json['wilaya'],
      facilityName: json['facilityName'] ?? json['facility_name'] ?? json['organization'],
      status: json['status'] ?? json['sync_status'] ?? 'Confirmed',
      scheduledAt: json['scheduledAt'] != null
          ? DateTime.tryParse(json['scheduledAt'].toString()) ?? DateTime.now()
          : (json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (clientUuid != null) 'clientUuid': clientUuid,
      'accountName': accountName,
      'activityType': activityType,
      'repName': repName,
      'repId': repId,
      'purpose': purpose,
      'productsDiscussed': productsDiscussed,
      'samplesDistributed': samplesDistributed,
      'giftsDistributed': giftsDistributed,
      'inventoryDistributions': inventoryDistributions,
      'feedbackNotes': feedbackNotes,
      'nextFollowupDate': nextFollowupDate,
      'latitude': latitude,
      'longitude': longitude,
      'wilaya': wilaya,
      'facilityName': facilityName,
      'status': status,
      'scheduledAt': scheduledAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'client_uuid': clientUuid,
      'account_name': accountName,
      'activity_type': activityType,
      'rep_name': repName,
      'rep_id': repId,
      'purpose': purpose,
      'products_discussed': productsDiscussed,
      'samples_distributed': samplesDistributed,
      'gifts_distributed': giftsDistributed,
      'inventory_distributions': jsonEncode(inventoryDistributions),
      'feedback_notes': feedbackNotes,
      'next_followup_date': nextFollowupDate,
      'latitude': latitude,
      'longitude': longitude,
      'wilaya': wilaya,
      'facility_name': facilityName,
      'sync_status': status,
      'created_at': scheduledAt.toIso8601String(),
    };
  }
}
