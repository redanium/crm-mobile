import 'dart:async';

import 'package:flutter/material.dart';
import '../models/geo_facility.dart';
import '../services/api_service.dart';
import 'package:provider/provider.dart';

class GeoAlgeriaDirectoryScreen extends StatefulWidget {
  const GeoAlgeriaDirectoryScreen({super.key});

  @override
  State<GeoAlgeriaDirectoryScreen> createState() => _GeoAlgeriaDirectoryScreenState();
}

class _GeoAlgeriaDirectoryScreenState extends State<GeoAlgeriaDirectoryScreen> {
  static const _categories = <(String, String)>[
    ('all', 'Tous'),
    ('hospital', 'Hôpitaux'),
    ('clinic', 'Cliniques'),
    ('pharmacy', 'Pharmacies'),
    ('manufacturer', 'Industrie'),
  ];

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  List<GeoWilaya> _wilayas = [];
  List<GeoCommune> _communes = [];
  List<GeoFacility> _facilities = [];
  Set<String> _crmNames = {};
  String _category = 'all';
  String? _wilayaCode;
  String? _communeName;
  String? _error;
  int _total = 0;
  int _page = 1;
  int _totalPages = 1;
  int _requestId = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _importingId;

  @override
  void initState() {
    super.initState();
    _loadDirectory();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDirectory() async {
    final api = context.read<ApiService>();
    try {
      final wilayas = await api.getGeoWilayas();
      if (!mounted) return;
      setState(() => _wilayas = wilayas);
    } catch (_) {
      // Facility searches still work when the wilaya dropdown cannot load.
    }
    try {
      final doctors = await api.getDoctors();
      if (!mounted) return;
      setState(() {
        _crmNames = doctors
            .expand((doctor) => [doctor.name, doctor.organization])
            .map((name) => name.trim().toLowerCase())
            .where((name) => name.isNotEmpty)
            .toSet();
      });
    } catch (_) {
      // Imports remain available if the CRM directory cannot be checked.
    }
    await _fetchFacilities();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _fetchFacilities);
  }

  Future<void> _fetchFacilities({int page = 1, bool append = false}) async {
    final requestId = ++_requestId;
    if (mounted) {
      setState(() {
        if (append) {
          _isLoadingMore = true;
        } else {
          _isLoading = true;
          _isLoadingMore = false;
          _error = null;
          _page = 1;
        }
      });
    }

    try {
      final result = await context.read<ApiService>().searchGeoFacilities(
            query: _searchController.text,
            wilayaCode: _wilayaCode ?? '',
            commune: _communeName ?? '',
            category: _category,
            page: page,
          );
      if (!mounted || requestId != _requestId) return;
      final items = (result['items'] as List<dynamic>? ?? []).cast<GeoFacility>();
      setState(() {
        _facilities = append ? [..._facilities, ...items] : items;
        _total = result['total'] as int? ?? 0;
        _page = result['page'] as int? ?? page;
        final totalPages = result['totalPages'] as int? ?? 1;
        _totalPages = totalPages > 0 ? totalPages : 1;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = 'Impossible de charger l’annuaire. Vérifiez la connexion au CRM.';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _handleScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 250 &&
        !_isLoading &&
        !_isLoadingMore &&
        _page < _totalPages) {
      _fetchFacilities(page: _page + 1, append: true);
    }
  }

  Future<void> _selectWilaya(String? code) async {
    setState(() {
      _wilayaCode = code;
      _communeName = null;
      _communes = [];
    });
    if (code != null) {
      try {
        final communes = await context.read<ApiService>().getGeoCommunes(code);
        if (mounted && _wilayaCode == code) setState(() => _communes = communes);
      } catch (_) {
        // Wilaya-level search remains available if commune names cannot be loaded.
      }
    }
    _fetchFacilities();
  }

  Future<void> _importFacility(GeoFacility facility) async {
    setState(() => _importingId = facility.id);
    try {
      final result = await context.read<ApiService>().importGeoFacility(facility);
      if (!mounted) return;
      final name = facility.nameFr.trim().toLowerCase();
      setState(() {
        _crmNames = {..._crmNames, name};
        _importingId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['isDraft'] == true ? 'Établissement soumis pour validation.' : 'Établissement ajouté au CRM.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _importingId = null);
      final message = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import impossible : $message')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Annuaire GeoAlgeria', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => _scheduleSearch(),
                  decoration: InputDecoration(
                    hintText: 'Nom, commune ou wilaya...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _categories
                        .map((entry) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(entry.$2),
                                selected: _category == entry.$1,
                                onSelected: (_) {
                                  setState(() => _category = entry.$1);
                                  _fetchFacilities();
                                },
                              ),
                            ))
                        .toList(),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _wilayaCode,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Wilaya', isDense: true),
                        hint: const Text('Toutes les wilayas'),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('Toutes les wilayas')),
                          ..._wilayas.map((wilaya) => DropdownMenuItem<String>(
                                value: wilaya.code,
                                child: Text('${wilaya.code} · ${wilaya.name}', overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: _selectWilaya,
                      ),
                    ),
                    if (_wilayaCode != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _communeName,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Commune', isDense: true),
                          hint: const Text('Toutes les communes'),
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text('Toutes les communes')),
                            ..._communes.map((commune) => DropdownMenuItem<String>(
                                  value: commune.name,
                                  child: Text(commune.name, overflow: TextOverflow.ellipsis),
                                )),
                          ],
                          onChanged: (value) {
                            setState(() => _communeName = value);
                            _fetchFacilities();
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.public, size: 17, color: Color(0xFF0F766E)),
                const SizedBox(width: 7),
                Expanded(child: Text('$_total établissements trouvés', style: const TextStyle(fontWeight: FontWeight.w600))),
                Text('Page $_page / $_totalPages', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)))
                : _error != null
                    ? _message(_error!, onRetry: _fetchFacilities)
                    : _facilities.isEmpty
                        ? _message('Aucun établissement ne correspond à votre recherche.')
                        : ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 2, 16, 20),
                            itemCount: _facilities.length + (_isLoadingMore ? 1 : 0),
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              if (index == _facilities.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              return _facilityCard(_facilities[index]);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _facilityCard(GeoFacility facility) {
    final isImported = _crmNames.contains(facility.nameFr.trim().toLowerCase());
    final isImporting = _importingId == facility.id;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.1),
                child: Icon(_categoryIcon(facility.category), color: const Color(0xFF0F766E), size: 19),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(facility.nameFr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    if ((facility.nameAr ?? '').isNotEmpty)
                      Text(facility.nameAr!, textDirection: TextDirection.rtl, style: const TextStyle(color: Color(0xFF64748B))),
                    Text(facility.categoryLabelFr, style: const TextStyle(color: Color(0xFF0F766E), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 5,
            children: [
              _meta(Icons.location_on_outlined, '${facility.wilayaName} · ${facility.wilayaCode}'),
              if (facility.communeName.isNotEmpty) _meta(Icons.place_outlined, facility.communeName),
              if ((facility.phone ?? '').isNotEmpty) _meta(Icons.phone_outlined, facility.phone!),
              if ((facility.address ?? '').isNotEmpty) _meta(Icons.signpost_outlined, facility.address!),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isImported || isImporting ? null : () => _importFacility(facility),
              icon: isImporting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(isImported ? Icons.check_circle_outline : Icons.person_add_alt_1, size: 18),
              label: Text(isImported ? 'Déjà dans le CRM' : isImporting ? 'Import...' : 'Ajouter au CRM'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Flexible(child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
        ],
      );

  Widget _message(String message, {Future<void> Function()? onRetry}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B))),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
              ],
            ],
          ),
        ),
      );

  IconData _categoryIcon(String category) => switch (category) {
        'hospital' => Icons.local_hospital_outlined,
        'clinic' => Icons.medical_services_outlined,
        'pharmacy' => Icons.local_pharmacy_outlined,
        'manufacturer' => Icons.factory_outlined,
        _ => Icons.place_outlined,
      };
}
