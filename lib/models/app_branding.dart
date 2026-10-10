import 'dart:convert';
import 'dart:typed_data';

class AppBranding {
  final String appName;
  final String appNameSub;
  final String? logoDataUrl;
  final String? isoLogoDataUrl;

  const AppBranding({
    this.appName = 'Noura Pharma',
    this.appNameSub = 'CRM & Field Ops',
    this.logoDataUrl,
    this.isoLogoDataUrl,
  });

  factory AppBranding.fromJson(Map<String, dynamic> json) => AppBranding(
        appName: _stringOrDefault(json['appName'], 'Noura Pharma'),
        appNameSub: _stringOrDefault(json['appNameSub'], 'Algerian CRM & Field Ops'),
        logoDataUrl: _optionalString(json['logoDataUrl']),
        isoLogoDataUrl: _optionalString(json['isoLogoDataUrl']),
      );

  static String _stringOrDefault(Object? value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String? _optionalString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  Uint8List? get logoBytes => _decodeDataUrl(logoDataUrl);
  Uint8List? get isoLogoBytes => _decodeDataUrl(isoLogoDataUrl);

  static Uint8List? _decodeDataUrl(String? dataUrl) {
    if (dataUrl == null) return null;
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(dataUrl.substring(comma + 1));
    } on FormatException {
      return null;
    }
  }
}
