import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../models/doctor.dart';
import '../models/visit.dart';
import '../models/product.dart';
import '../models/medicine_directory_entry.dart';
import '../models/geo_facility.dart';
import 'auth_service.dart';

class ApiService {
  // Configured default URL pointing to your deployed Next.js backend
  // For local Android emulator, use: http://10.0.2.2:3000
  // For physical devices, use your deployment domain: https://your-crm.app
  String baseUrl = 'https://crmium.vercel.app';
  final AuthService? authService;

  late final Dio _dio;

  ApiService({String? customBaseUrl, this.authService}) {
    if (customBaseUrl != null && customBaseUrl.isNotEmpty) {
      baseUrl = customBaseUrl;
    }
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 12),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Client-Platform': 'Flutter-Mobile',
        },
      ),
    );

    // Better Auth: Inject Bearer token & session cookie
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = authService?.token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
            options.headers['Cookie'] = 'better-auth.session_token=$token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          if (error.response?.statusCode == 401) {
            authService?.handleSessionExpired();
          }
          return handler.next(error);
        },
      ),
    );

    _dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: true,
      ),
    );
  }

  void updateBaseUrl(String newUrl) {
    baseUrl = newUrl;
    _dio.options.baseUrl = newUrl;
  }

  /// Fetch the public app branding so mobile mirrors the web CRM configuration.
  Future<Map<String, dynamic>> getAppBranding() async {
    final response = await _dio.get('/api/mobile/branding');
    final payload = Map<String, dynamic>.from(response.data as Map);
    return Map<String, dynamic>.from(payload['branding'] as Map? ?? const {});
  }

  /// Fetch medical doctors / HCPs assigned to this representative
  Future<List<Doctor>> getDoctors({String? wilaya, String? search}) async {
    final response = await _dio.get(
      '/api/mobile/doctors',
      queryParameters: {
        if (wilaya != null) 'wilaya': wilaya,
        if (search != null) 'search': search,
      },
    );
    final data = response.data['doctors'] as List<dynamic>;
    return data.map((json) => Doctor.fromJson(json)).toList();
  }

  /// Fetch visits schedule and past visits with optional filters
  Future<List<Visit>> getVisits({
    String? repId,
    String? doctor,
    String? wilaya,
    String? date,
    String? search,
  }) async {
    final response = await _dio.get(
      '/api/mobile/visits',
      queryParameters: {
        if (repId != null) 'repId': repId,
        if (doctor != null) 'doctor': doctor,
        if (wilaya != null) 'wilaya': wilaya,
        if (date != null) 'date': date,
        if (search != null) 'search': search,
      },
    );
    final data = response.data['visits'] as List<dynamic>;
    return data.map((json) => Visit.fromJson(json)).toList();
  }

  /// Log a single visit immediately when online
  Future<Map<String, dynamic>> logVisit(Visit visit) async {
    final visitJson = visit.toJson()..remove('proofDocuments');
    final form = FormData.fromMap({'visit': jsonEncode(visitJson)});
    form.fields.add(MapEntry(
        'documentTypes',
        jsonEncode(visit.proofDocuments
            .map((doc) => doc['documentType'] ?? 'attachment')
            .toList())));
    for (final document in visit.proofDocuments) {
      final bytes = base64Decode(document['dataBase64']?.toString() ?? '');
      form.files.add(MapEntry(
          'documents',
          MultipartFile.fromBytes(
            bytes,
            filename: document['fileName']?.toString() ?? 'visit-document.jpg',
            contentType: MediaType.parse(
                document['mimeType']?.toString() ?? 'image/jpeg'),
          )));
    }
    final response = await _dio.post(
      '/api/mobile/visits',
      data: form,
      options: Options(contentType: Headers.multipartFormDataContentType),
    );
    return response.data;
  }

  /// Batch sync all queued offline visits created while traveling
  Future<Map<String, dynamic>> syncOfflineQueue({
    required String repId,
    required List<Map<String, dynamic>> queuedVisits,
  }) async {
    final syncedUuids = <String>[];
    final failures = <Map<String, String>>[];
    for (final visit in queuedVisits) {
      try {
        final visitModel = Visit.fromJson({...visit, 'rep_id': repId});
        final result = await logVisit(visitModel);
        final uuid = visit['client_uuid']?.toString();
        if (result['success'] == true && uuid != null)
          syncedUuids.add(uuid);
        else
          failures.add({
            'clientUuid': uuid ?? '',
            'error': result['error']?.toString() ?? 'Sync failed'
          });
      } on DioException catch (error) {
        failures.add({
          'clientUuid': visit['client_uuid']?.toString() ?? '',
          'error': error.response?.data?['error']?.toString() ??
              error.message ??
              'Sync failed'
        });
      } catch (error) {
        failures.add({
          'clientUuid': visit['client_uuid']?.toString() ?? '',
          'error': error.toString()
        });
      }
    }
    return {
      'success': failures.isEmpty,
      'processedCount': syncedUuids.length,
      'syncedUuids': syncedUuids,
      'failures': failures
    };
  }

  /// Fetch medicine catalog and available sample inventory
  Future<List<Product>> getProducts() async {
    final response = await _dio.get('/api/mobile/products');
    final data = response.data['products'] as List<dynamic>;
    return data.map((json) => Product.fromJson(json)).toList();
  }

  /// Search the CRM's French BDPM medicine directory (read-only on mobile).
  Future<List<MedicineDirectoryEntry>> searchMedicineDirectory(
      String query) async {
    final response = await _dio
        .get('/api/medicines-directory', queryParameters: {'q': query});
    final data = Map<String, dynamic>.from(response.data as Map);
    final items = data['items'] as List<dynamic>? ?? [];
    return items
        .map((item) => MedicineDirectoryEntry.fromJson(
            Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  /// Fetch full catalog bundle: products, samples batches, and gifts
  Future<Map<String, dynamic>> getCatalogBundle() async {
    final response = await _dio.get('/api/mobile/products');
    final productsData = (response.data['products'] as List<dynamic>? ?? [])
        .map((json) => Product.fromJson(json))
        .toList();
    final samplesData = (response.data['samples'] as List<dynamic>? ?? [])
        .map((json) => SampleBatch.fromJson(json))
        .toList();
    final giftsData = (response.data['gifts'] as List<dynamic>? ?? [])
        .map((json) => PromotionalGift.fromJson(json))
        .toList();
    final movements = (response.data['movements'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final pendingReceipts =
        (response.data['pendingReceipts'] as List<dynamic>? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();

    return {
      'products': productsData,
      'samples': samplesData,
      'gifts': giftsData,
      'movements': movements,
      'pendingReceipts': pendingReceipts,
    };
  }

  Future<Map<String, dynamic>> submitInventoryReceipt({
    required String itemType,
    required Map<String, String> fields,
    required bool confirmed,
    required List<Map<String, dynamic>> documents,
  }) async {
    final form = FormData.fromMap(
        {...fields, 'itemType': itemType, 'confirmed': confirmed.toString()});
    for (final document in documents) {
      final bytes = base64Decode(document['dataBase64']?.toString() ?? '');
      form.files.add(MapEntry(
          'documents',
          MultipartFile.fromBytes(
            bytes,
            filename: document['fileName']?.toString() ?? 'receipt-proof.jpg',
            contentType: MediaType.parse(
                document['mimeType']?.toString() ?? 'image/jpeg'),
          )));
    }
    final response = await _dio.post('/api/inventory/receipts',
        data: form,
        options: Options(contentType: Headers.multipartFormDataContentType));
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> confirmInventoryReceipt({
    required int movementId,
    required List<Map<String, dynamic>> documents,
  }) async {
    final form = FormData.fromMap({'movementId': movementId.toString()});
    for (final document in documents) {
      final bytes = base64Decode(document['dataBase64']?.toString() ?? '');
      form.files.add(MapEntry(
          'documents',
          MultipartFile.fromBytes(
            bytes,
            filename: document['fileName']?.toString() ?? 'receipt-proof.jpg',
            contentType: MediaType.parse(
                document['mimeType']?.toString() ?? 'image/jpeg'),
          )));
    }
    final response = await _dio.post('/api/inventory/receipts',
        data: form,
        options: Options(contentType: Headers.multipartFormDataContentType));
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> destroyExpiredSample(
      {required int sampleId, required int quantity}) async {
    final response = await _dio.post('/api/mobile/products', data: {
      'action': 'destroy-expired-sample',
      'sampleId': sampleId,
      'quantity': quantity,
    });
    return Map<String, dynamic>.from(response.data);
  }

  /// Fetch rep territory quotas & assigned wilayas
  Future<Map<String, dynamic>> getTerritorySummary({String? repId}) async {
    final response = await _dio.get(
      '/api/mobile/territories',
      queryParameters: {
        if (repId != null) 'repId': repId,
      },
    );
    return response.data;
  }

  Future<List<GeoWilaya>> getGeoWilayas() async {
    final response = await _dio
        .get('/api/geoalgeria', queryParameters: {'action': 'wilayas'});
    final items = response.data['wilayas'] as List<dynamic>? ?? [];
    return items
        .map((item) => GeoWilaya.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<GeoCommune>> getGeoCommunes(String wilayaCode) async {
    final response = await _dio.get(
      '/api/geoalgeria',
      queryParameters: {'action': 'communes', 'wilaya': wilayaCode},
    );
    final items = response.data['communes'] as List<dynamic>? ?? [];
    return items
        .map((item) => GeoCommune.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Map<String, dynamic>> searchGeoFacilities({
    String query = '',
    String wilayaCode = '',
    String commune = '',
    String category = 'all',
    int page = 1,
  }) async {
    final response = await _dio.get(
      '/api/geoalgeria/facilities',
      queryParameters: {
        'limit': 30,
        'page': page,
        if (query.trim().isNotEmpty) 'q': query.trim(),
        if (wilayaCode.isNotEmpty) 'wilaya': wilayaCode,
        if (commune.isNotEmpty) 'commune': commune,
        if (category != 'all') 'category': category,
      },
    );
    final data = Map<String, dynamic>.from(response.data);
    data['items'] = ((data['items'] as List<dynamic>?) ?? [])
        .map((item) => GeoFacility.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    return data;
  }

  Future<Map<String, dynamic>> importGeoFacility(GeoFacility facility) async {
    final response = await _dio.post(
      '/api/mobile/doctors',
      data: facility.toCrmContactBody(),
    );
    return Map<String, dynamic>.from(response.data);
  }
}
