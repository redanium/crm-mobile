import 'package:dio/dio.dart';
import '../models/doctor.dart';
import '../models/visit.dart';
import '../models/product.dart';

class ApiService {
  // Configured default URL pointing to your deployed Next.js backend
  // For local Android emulator, use: http://10.0.2.2:3000
  // For physical devices, use your deployment domain: https://your-crm.app
  String baseUrl = 'https://new-chat-ms8iyb8qq-redaniums-projects.vercel.app';

  late final Dio _dio;

  ApiService({String? customBaseUrl}) {
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

  /// Fetch visits schedule and past visits
  Future<List<Visit>> getVisits({String? repId}) async {
    final response = await _dio.get(
      '/api/mobile/visits',
      queryParameters: {
        if (repId != null) 'repId': repId,
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
}
