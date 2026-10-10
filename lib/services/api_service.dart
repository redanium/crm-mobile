import 'package:dio/dio.dart';
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
        requestBody: true,
        responseBody: true,
      ),
    );
  }

  void updateBaseUrl(String newUrl) {
    baseUrl = newUrl;
    _dio.options.baseUrl = newUrl;
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
    final response = await _dio.post(
      '/api/mobile/visits',
      data: visit.toJson(),
    );
    return response.data;
  }

  /// Batch sync all queued offline visits created while traveling
  Future<Map<String, dynamic>> syncOfflineQueue({
    required String repId,
    required List<Map<String, dynamic>> queuedVisits,
  }) async {
    final response = await _dio.post(
      '/api/mobile/sync',
      data: {
        'repId': repId,
        'visits': queuedVisits,
        'clientTimestamp': DateTime.now().toIso8601String(),
      },
    );
    return response.data;
  }

  /// Fetch medicine catalog and available sample inventory
  Future<List<Product>> getProducts() async {
    final response = await _dio.get('/api/mobile/products');
    final data = response.data['products'] as List<dynamic>;
    return data.map((json) => Product.fromJson(json)).toList();
  }

  /// Search the CRM's French BDPM medicine directory (read-only on mobile).
  Future<List<MedicineDirectoryEntry>> searchMedicineDirectory(String query) async {
    final response = await _dio.get('/api/medicines-directory', queryParameters: {'q': query});
    final data = Map<String, dynamic>.from(response.data as Map);
    final items = data['items'] as List<dynamic>? ?? [];
    return items
        .map((item) => MedicineDirectoryEntry.fromJson(Map<String, dynamic>.from(item as Map)))
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

    return {
      'products': productsData,
      'samples': samplesData,
      'gifts': giftsData,
      'movements': movements,
    };
  }

  Future<Map<String, dynamic>> destroyExpiredSample({required int sampleId, required int quantity}) async {
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
    final response = await _dio.get('/api/geoalgeria', queryParameters: {'action': 'wilayas'});
    final items = response.data['wilayas'] as List<dynamic>? ?? [];
    return items.map((item) => GeoWilaya.fromJson(Map<String, dynamic>.from(item))).toList();
  }

  Future<List<GeoCommune>> getGeoCommunes(String wilayaCode) async {
    final response = await _dio.get(
      '/api/geoalgeria',
      queryParameters: {'action': 'communes', 'wilaya': wilayaCode},
    );
    final items = response.data['communes'] as List<dynamic>? ?? [];
    return items.map((item) => GeoCommune.fromJson(Map<String, dynamic>.from(item))).toList();
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
