import 'package:flutter/foundation.dart';
import '../models/app_branding.dart';
import 'api_service.dart';

class AppBrandingService extends ChangeNotifier {
  final ApiService _apiService;
  AppBranding _branding = const AppBranding();

  AppBrandingService(this._apiService);

  AppBranding get branding => _branding;

  Future<void> load() async {
    try {
      _branding = AppBranding.fromJson(await _apiService.getAppBranding());
      notifyListeners();
    } catch (_) {
      // Keep the built-in brand when offline or when an older server lacks this endpoint.
    }
  }
}
