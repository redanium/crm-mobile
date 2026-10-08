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
  final String? feedbackNotes;
  final String? nextFollowupDate;
  final double? latitude;
  final double? longitude;
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
    this.feedbackNotes,
    this.nextFollowupDate,
    this.latitude,
    this.longitude,
    this.status = 'Confirmed',
    DateTime? scheduledAt,
  }) : scheduledAt = scheduledAt ?? DateTime.now();

  factory Visit.fromJson(Map<String, dynamic> json) {
    return Visit(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      clientUuid: json['clientUuid'],
      accountName: json['accountName'] ?? '',
      activityType: json['activityType'] ?? 'Visite Médicale',
      repName: json['repName'] ?? 'Délégué Médical',
      repId: json['repId'] ?? 'REP_001',
      purpose: json['purpose'],
      productsDiscussed: json['productsDiscussed'],
      samplesDistributed: json['samplesDistributed'],
      giftsDistributed: json['giftsDistributed'],
      feedbackNotes: json['feedbackNotes'] ?? json['notes'],
      nextFollowupDate: json['nextFollowupDate'],
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      status: json['status'] ?? 'Confirmed',
      scheduledAt: json['scheduledAt'] != null
          ? DateTime.tryParse(json['scheduledAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
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
      'feedbackNotes': feedbackNotes,
      'nextFollowupDate': nextFollowupDate,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'scheduledAt': scheduledAt.toIso8601String(),
    };
  }
}
