import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import '../models/doctor.dart';
import '../models/product.dart';
import '../models/visit.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import '../widgets/filterable_list_picker.dart';

class VisitLoggerScreen extends StatefulWidget {
  final String? initialDoctorName;
  const VisitLoggerScreen({super.key, this.initialDoctorName});

  @override
  State<VisitLoggerScreen> createState() => _VisitLoggerScreenState();
}

class _VisitLoggerScreenState extends State<VisitLoggerScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _doctorCtrl;
  final _productsCtrl = TextEditingController();
  final _samplesCtrl = TextEditingController();
  final _giftsCtrl = TextEditingController();
  final _feedbackCtrl = TextEditingController();
  final Map<String, TextEditingController> _inventoryQuantityControllers = {};
  
  String _activityType = 'Product presentation';
  final String _purpose = 'Visite de routine & présentation produit';
  bool _isLocating = false;
  double? _latitude;
  double? _longitude;
  bool _isSaving = false;

  // Cached listings for filterable selection
  List<Doctor> _availableDoctors = [];
  List<Product> _availableProducts = [];
  List<SampleBatch> _availableSamples = [];
  List<PromotionalGift> _availableGifts = [];

  // Selected items lists
  List<String> _selectedProducts = [];
  final Map<String, int> _inventorySelections = {};

  Doctor? _selectedDoctor;

  @override
  void initState() {
    super.initState();
    _doctorCtrl = TextEditingController(text: widget.initialDoctorName ?? '');
    _loadListings();
  }

  @override
  void dispose() {
    _doctorCtrl.dispose();
    _productsCtrl.dispose();
    _samplesCtrl.dispose();
    _giftsCtrl.dispose();
    _feedbackCtrl.dispose();
    for (final controller in _inventoryQuantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadListings() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final dbHelper = Provider.of<DatabaseHelper>(context, listen: false);

    // 1. Load doctors from local cache first, then sync with API
    try {
      final cachedDocs = await dbHelper.getCachedDoctors();
      if (cachedDocs.isNotEmpty && mounted) {
        setState(() => _availableDoctors = cachedDocs);
      }
      final onlineDocs = await apiService.getDoctors();
      if (onlineDocs.isNotEmpty) {
        await dbHelper.cacheDoctors(onlineDocs);
        if (mounted) setState(() => _availableDoctors = onlineDocs);
      }
    } catch (_) {}

    // Match initial doctor if provided
    if (widget.initialDoctorName != null && widget.initialDoctorName!.isNotEmpty) {
      final match = _availableDoctors.where((d) => d.name == widget.initialDoctorName).firstOrNull;
      if (match != null) {
        _selectedDoctor = match;
      }
    }

    // 2. Load products, samples, and gifts from cache, then sync live bundle
    try {
      final cachedP = await dbHelper.getCachedProducts();
      final cachedS = await dbHelper.getCachedSamples();
      final cachedG = await dbHelper.getCachedGifts();

      if ((cachedP.isNotEmpty || cachedS.isNotEmpty || cachedG.isNotEmpty) && mounted) {
        setState(() {
          _availableProducts = cachedP;
          _availableSamples = cachedS.where((item) => item.isAllocated && item.quantity > 0).toList();
          _availableGifts = cachedG.where((item) => item.isAllocated && item.quantity > 0).toList();
        });
      }

      final bundle = await apiService.getCatalogBundle();
      final liveProducts = bundle['products'] as List<Product>? ?? [];
      final pending = await dbHelper.getPendingVisits();
      final reserved = <String, int>{};
      for (final visit in pending) {
        final raw = visit['inventory_distributions'];
        final lines = raw is String ? (jsonDecode(raw) as List<dynamic>? ?? []) : (raw as List<dynamic>? ?? []);
        for (final line in lines) {
          final item = Map<String, dynamic>.from(line as Map);
          final key = '${item['itemType']}:${item['itemId']}';
          reserved[key] = (reserved[key] ?? 0) + (int.tryParse(item['quantity'].toString()) ?? 0);
        }
      }
      final liveSamples = (bundle['samples'] as List<SampleBatch>? ?? []).map((sample) => SampleBatch(
        id: sample.id, prodId: sample.prodId, brandName: sample.brandName, expiry: sample.expiry,
        quantity: (sample.quantity - (reserved['sample:${sample.id}'] ?? 0)).clamp(0, sample.quantity).toInt(), unit: sample.unit, isAllocated: sample.isAllocated,
      )).toList();
      final liveGifts = (bundle['gifts'] as List<PromotionalGift>? ?? []).map((gift) => PromotionalGift(
        id: gift.id, giftId: gift.giftId, name: gift.name,
        quantity: (gift.quantity - (reserved['gift:${gift.id}'] ?? 0)).clamp(0, gift.quantity).toInt(), distributed: gift.distributed, isAllocated: gift.isAllocated,
      )).toList();

      if (liveProducts.isNotEmpty || liveSamples.isNotEmpty || liveGifts.isNotEmpty) {
        await dbHelper.cacheCatalog(
          products: liveProducts,
          samples: liveSamples,
          gifts: liveGifts,
        );
        if (mounted) {
          setState(() {
            _availableProducts = liveProducts;
            _availableSamples = liveSamples.where((item) => item.isAllocated && item.quantity > 0).toList();
            _availableGifts = liveGifts.where((item) => item.isAllocated && item.quantity > 0).toList();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _pickDoctor() async {
    final items = _availableDoctors.map((d) {
      return FilterableItem(
        id: d.id.toString(),
        title: d.name,
        subtitle: '${d.specialty} · ${d.organization} · ${d.wilaya}',
        badge: 'Tier ${d.tier}',
      );
    }).toList();

    final picked = await showFilterableListPicker(
      context: context,
      title: 'Sélectionner un Médecin / Client',
      items: items,
      searchHint: 'Rechercher médecin, hôpital, wilaya...',
      allowCustom: true,
    );

    if (picked != null) {
      final matchedDoc = _availableDoctors.where((d) => d.id.toString() == picked.id).firstOrNull;
      setState(() {
        _doctorCtrl.text = picked.title;
        _selectedDoctor = matchedDoc;
      });
    }
  }

  Future<void> _pickProducts() async {
    final items = _availableProducts.map((p) {
      final details = [
        if (p.genericName != null && p.genericName!.isNotEmpty) p.genericName,
        if (p.dosageForm != null && p.dosageForm!.isNotEmpty) p.dosageForm,
        if (p.strength != null && p.strength!.isNotEmpty) p.strength,
      ].join(' · ');

      return FilterableItem(
        id: p.name,
        title: p.name,
        subtitle: details.isNotEmpty ? details : null,
        badge: p.dnhStatus?.contains('Chifa') == true ? 'Chifa' : (p.code ?? 'Produit'),
      );
    }).toList();

    final pickedList = await showMultiFilterableListPicker(
      context: context,
      title: 'Médicaments Présentés (Catalogue)',
      items: items,
      searchHint: 'Rechercher par DCI, marque, dosage...',
      selectedIds: _selectedProducts,
      allowCustom: true,
    );

    if (pickedList != null) {
      setState(() {
        _selectedProducts = pickedList.map((i) => i.id).toList();
        _productsCtrl.text = _selectedProducts.join(', ');
      });
    }
  }

  Future<void> _pickSamples() async {
    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) {
        final quantities = Map<String, int>.from(_inventorySelections);
        return StatefulBuilder(builder: (context, refresh) => AlertDialog(
          title: const Text('Échantillons & Goodies remis'),
          content: SizedBox(width: 520, child: ListView(shrinkWrap: true, children: [
            for (final sample in _availableSamples)
              _inventoryQuantityRow(
                title: '${sample.brandName} · Lot ${sample.prodId}',
                subtitle: 'Disponible: ${sample.quantity} ${sample.unit}',
                max: sample.quantity,
                quantity: quantities['sample:${sample.id}'] ?? 0,
                onChanged: (value) => refresh(() => quantities['sample:${sample.id}'] = value),
              ),
            for (final gift in _availableGifts)
              _inventoryQuantityRow(
                title: gift.name, subtitle: '${gift.giftId} · Disponible: ${gift.quantity}',
                max: gift.quantity,
                quantity: quantities['gift:${gift.id}'] ?? 0,
                onChanged: (value) => refresh(() => quantities['gift:${gift.id}'] = value),
              ),
            if (_availableSamples.isEmpty && _availableGifts.isEmpty)
              const Padding(padding: EdgeInsets.all(16), child: Text('Aucun stock attribué à votre compte.')),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(context, quantities), child: const Text('Enregistrer')),
          ],
        ));
      },
    );
    if (result == null) return;
    final sampleSummary = <String>[];
    final giftSummary = <String>[];
    for (final entry in result.entries.where((entry) => entry.value > 0)) {
      final parts = entry.key.split(':');
      final isSample = parts.first == 'sample';
      if (isSample) {
        final item = _availableSamples.where((value) => value.id.toString() == parts.last).firstOrNull;
        if (item != null) sampleSummary.add('${item.brandName} × ${entry.value}');
      } else {
        final item = _availableGifts.where((value) => value.id.toString() == parts.last).firstOrNull;
        if (item != null) giftSummary.add('${item.name} × ${entry.value}');
      }
    }
    setState(() {
      _inventorySelections
        ..clear()
        ..addAll(result);
      for (final entry in result.entries) {
        _inventoryQuantityControllers.putIfAbsent(entry.key, () => TextEditingController()).text = entry.value.toString();
      }
      _samplesCtrl.text = sampleSummary.join(', ');
      _giftsCtrl.text = giftSummary.join(', ');
    });
  }

  void _updateVisitInventoryQuantity(String key, String value, int available) {
    final quantity = (int.tryParse(value) ?? 0).clamp(0, available).toInt();
    final sampleSummary = <String>[];
    final giftSummary = <String>[];
    for (final entry in _inventorySelections.entries) {
      final used = entry.key == key ? quantity : entry.value;
      if (used <= 0) continue;
      final parts = entry.key.split(':');
      if (parts.first == 'sample') {
        final item = _availableSamples.where((sample) => sample.id.toString() == parts.last).firstOrNull;
        if (item != null) sampleSummary.add('${item.brandName} × $used');
      } else {
        final item = _availableGifts.where((gift) => gift.id.toString() == parts.last).firstOrNull;
        if (item != null) giftSummary.add('${item.name} × $used');
      }
    }
    setState(() {
      _inventorySelections[key] = quantity;
      _samplesCtrl.text = sampleSummary.join(', ');
      _giftsCtrl.text = giftSummary.join(', ');
    });
  }

  Widget _visitInventoryQuantityField({required String key, required String title, required int quantity, required int available}) {
    final controller = _inventoryQuantityControllers.putIfAbsent(key, () => TextEditingController(text: quantity.toString()));
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        Expanded(child: Text('$title · Disponible: $available', style: const TextStyle(fontSize: 12))),
        SizedBox(width: 88, child: TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantité', isDense: true, border: OutlineInputBorder()),
          onChanged: (value) => _updateVisitInventoryQuantity(key, value, available),
        )),
      ]),
    );
  }

  Widget _inventoryQuantityRow({required String title, required String subtitle, required int max, required int quantity, required ValueChanged<int> onChanged}) {
    return ListTile(
      dense: true, contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(onPressed: quantity > 0 ? () => onChanged(quantity - 1) : null, icon: const Icon(Icons.remove_circle_outline)),
        SizedBox(width: 24, child: Text('$quantity', textAlign: TextAlign.center)),
        IconButton(onPressed: quantity < max ? () => onChanged(quantity + 1) : null, icon: const Icon(Icons.add_circle_outline)),
      ]),
    );
  }

  Future<void> _captureGps() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() => _isLocating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veuillez activer la localisation GPS sur votre appareil.'),
            backgroundColor: Color(0xFFD97706),
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() => _isLocating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission GPS refusée.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _isLocating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Position GPS capturée: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}'),
          backgroundColor: const Color(0xFF0F766E),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLocating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de récupérer le GPS: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveVisit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final apiService = Provider.of<ApiService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final dbHelper = Provider.of<DatabaseHelper>(context, listen: false);
    final clientUuid = const Uuid().v4();

    final user = authService.currentUser;
    final repName = user?.name.isNotEmpty == true ? user!.name : 'Délégué Médical';
    final repId = user?.id.isNotEmpty == true ? user!.id : 'REP_CURRENT';

    final visitPayload = {
      'client_uuid': clientUuid,
      'doctor_id': _selectedDoctor?.id,
      'account_name': _doctorCtrl.text.trim(),
      'activity_type': _activityType,
      'rep_name': repName,
      'rep_id': repId,
      'purpose': _purpose,
      'products_discussed': _productsCtrl.text.trim(),
      'samples_distributed': _samplesCtrl.text.trim(),
      'gifts_distributed': _giftsCtrl.text.trim(),
      'inventory_distributions': jsonEncode(_inventorySelections.entries.where((entry) => entry.value > 0).map((entry) {
        final parts = entry.key.split(':');
        return {'itemType': parts.first, 'itemId': int.parse(parts.last), 'quantity': entry.value};
      }).toList()),
      'feedback_notes': _feedbackCtrl.text.trim(),
      'next_followup_date': '',
      'latitude': _latitude ?? _selectedDoctor?.latitude,
      'longitude': _longitude ?? _selectedDoctor?.longitude,
      'wilaya': _selectedDoctor?.wilaya ?? '',
      'facility_name': _selectedDoctor?.organization ?? '',
      'created_at': DateTime.now().toIso8601String(),
      'sync_status': 'pending',
    };

    bool syncedOnline = false;
    try {
      // Save locally first
      await dbHelper.enqueueVisit(visitPayload);
      final reservedSamples = _availableSamples.map((sample) {
        final used = _inventorySelections['sample:${sample.id}'] ?? 0;
        return SampleBatch(id: sample.id, prodId: sample.prodId, brandName: sample.brandName, expiry: sample.expiry, quantity: (sample.quantity - used).clamp(0, sample.quantity).toInt(), unit: sample.unit, isAllocated: sample.isAllocated);
      }).toList();
      final reservedGifts = _availableGifts.map((gift) {
        final used = _inventorySelections['gift:${gift.id}'] ?? 0;
        return PromotionalGift(id: gift.id, giftId: gift.giftId, name: gift.name, quantity: (gift.quantity - used).clamp(0, gift.quantity).toInt(), distributed: gift.distributed, isAllocated: gift.isAllocated);
      }).toList();
      setState(() { _availableSamples = reservedSamples; _availableGifts = reservedGifts; });
      await dbHelper.cacheCatalog(products: _availableProducts, samples: reservedSamples, gifts: reservedGifts);

      // Attempt immediate sync to Next.js API
      final visitObj = Visit.fromJson(visitPayload);
      await apiService.logVisit(visitObj);
      await dbHelper.markVisitSynced(clientUuid);
      syncedOnline = true;
    } catch (e) {
      // Offline fallback: already enqueued to local SQLite
      syncedOnline = false;
    }

    setState(() => _isSaving = false);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              syncedOnline ? LucideIcons.checkCircle2 : LucideIcons.database,
              color: syncedOnline ? const Color(0xFF0F766E) : const Color(0xFFD97706),
            ),
            const SizedBox(width: 8),
            Text(syncedOnline ? 'Visite Synchronisée !' : 'Visite Enregistrée (Hors-ligne)'),
          ],
        ),
        content: Text(
          syncedOnline
              ? 'Le rapport a été transmis immédiatement au serveur CRM algérien.'
              : 'Aucune connexion internet détectée. Le rapport est stocké en local dans SQLite et sera envoyé dès votre retour au réseau.',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Enregistrer Visite Terrain', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // GPS Location Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.mapPin, color: Color(0xFF0F766E), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Horodatage & Géolocalisation GPS',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          _latitude != null
                              ? 'Coord: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)} (Vérifié)'
                              : 'Localisation non définie',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isLocating ? null : _captureGps,
                    icon: _isLocating
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(LucideIcons.locate, size: 16),
                    label: const Text('Repérer', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Form inputs with fast Search & Pick buttons
            TextFormField(
              controller: _doctorCtrl,
              readOnly: true,
              onTap: _pickDoctor,
              decoration: InputDecoration(
                labelText: 'Médecin / Clinique / Pharmacie *',
                prefixIcon: const Icon(LucideIcons.userCheck, size: 18),
                suffixIcon: IconButton(
                  icon: const Icon(LucideIcons.search, size: 18, color: Color(0xFF0F766E)),
                  onPressed: _pickDoctor,
                  tooltip: 'Choisir dans la liste',
                ),
                helperText: 'Touchez pour filtrer dans le répertoire des praticiens',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Veuillez choisir un praticien' : null,
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: _activityType,
              decoration: InputDecoration(
                labelText: 'Type d’activité',
                prefixIcon: const Icon(LucideIcons.activity, size: 18),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: 'Product presentation', child: Text('Présentation Produit')),
                DropdownMenuItem(value: 'Follow-up visit', child: Text('Visite de Suivi')),
                DropdownMenuItem(value: 'Sample delivery', child: Text('Remise d’Échantillons')),
                DropdownMenuItem(value: 'Clinical inquiry', child: Text('Enquête Clinique')),
              ],
              onChanged: (v) => setState(() => _activityType = v!),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _productsCtrl,
              readOnly: true,
              onTap: _pickProducts,
              decoration: InputDecoration(
                labelText: 'Produits présentés (Portefeuille)',
                prefixIcon: const Icon(LucideIcons.pill, size: 18),
                suffixIcon: IconButton(
                  icon: const Icon(LucideIcons.listPlus, size: 18, color: Color(0xFF0F766E)),
                  onPressed: _pickProducts,
                  tooltip: 'Sélectionner des médicaments',
                ),
                helperText: 'Touchez pour sélectionner des médicaments avec recherche',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _samplesCtrl,
              readOnly: true,
              onTap: _pickSamples,
              decoration: InputDecoration(
                labelText: 'Échantillons & Goodies distribués',
                prefixIcon: const Icon(LucideIcons.box, size: 18),
                suffixIcon: IconButton(
                  icon: const Icon(LucideIcons.gift, size: 18, color: Color(0xFF0F766E)),
                  onPressed: _pickSamples,
                  tooltip: 'Sélectionner lots & goodies',
                ),
                helperText: 'Touchez pour sélectionner les lots d’échantillons & cadeaux',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _giftsCtrl,
              readOnly: true,
              onTap: _pickSamples,
              decoration: InputDecoration(
                labelText: 'Goodies remis',
                prefixIcon: const Icon(LucideIcons.gift, size: 18),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            for (final sample in _availableSamples.where((item) => (_inventorySelections['sample:${item.id}'] ?? 0) > 0))
              _visitInventoryQuantityField(
                key: 'sample:${sample.id}', title: '${sample.brandName} · Lot ${sample.prodId}',
                quantity: _inventorySelections['sample:${sample.id}'] ?? 0, available: sample.quantity,
              ),
            for (final gift in _availableGifts.where((item) => (_inventorySelections['gift:${item.id}'] ?? 0) > 0))
              _visitInventoryQuantityField(
                key: 'gift:${gift.id}', title: gift.name,
                quantity: _inventorySelections['gift:${gift.id}'] ?? 0, available: gift.quantity,
              ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _feedbackCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Retour du Médecin & Commentaires cliniques',
                prefixIcon: const Icon(LucideIcons.messageSquare, size: 18),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isSaving ? null : _saveVisit,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(LucideIcons.checkCheck),
              label: Text(
                _isSaving ? 'Validation en cours...' : 'Valider & Enregistrer la Visite',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
