import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import '../models/doctor.dart';
import '../models/product.dart';
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
  final _feedbackCtrl = TextEditingController();
  
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
  List<String> _selectedSamples = [];

  @override
  void initState() {
    super.initState();
    _doctorCtrl = TextEditingController(text: widget.initialDoctorName ?? '');
    _loadListings();
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

    // 2. Load products, samples, and gifts from cache, then sync live bundle
    try {
      final cachedP = await dbHelper.getCachedProducts();
      final cachedS = await dbHelper.getCachedSamples();
      final cachedG = await dbHelper.getCachedGifts();

      if ((cachedP.isNotEmpty || cachedS.isNotEmpty || cachedG.isNotEmpty) && mounted) {
        setState(() {
          _availableProducts = cachedP;
          _availableSamples = cachedS;
          _availableGifts = cachedG;
        });
      }

      final bundle = await apiService.getCatalogBundle();
      final liveProducts = bundle['products'] as List<Product>? ?? [];
      final liveSamples = bundle['samples'] as List<SampleBatch>? ?? [];
      final liveGifts = bundle['gifts'] as List<PromotionalGift>? ?? [];

      if (liveProducts.isNotEmpty || liveSamples.isNotEmpty || liveGifts.isNotEmpty) {
        await dbHelper.cacheCatalog(
          products: liveProducts,
          samples: liveSamples,
          gifts: liveGifts,
        );
        if (mounted) {
          setState(() {
            _availableProducts = liveProducts;
            _availableSamples = liveSamples;
            _availableGifts = liveGifts;
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
      setState(() {
        _doctorCtrl.text = picked.title;
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
    final sampleItems = _availableSamples.map((s) {
      return FilterableItem(
        id: '${s.brandName} (Lot ${s.prodId})',
        title: '${s.brandName} (Éch. Médical)',
        subtitle: 'Lot: ${s.prodId} · Exp: ${s.expiry} · Stock: ${s.quantity} ${s.unit}s',
        badge: 'Échantillon',
      );
    }).toList();

    final giftItems = _availableGifts.map((g) {
      return FilterableItem(
        id: '${g.name} (${g.giftId})',
        title: g.name,
        subtitle: 'Code: ${g.giftId} · En stock: ${g.quantity}',
        badge: 'Goodie',
      );
    }).toList();

    final combinedItems = [...sampleItems, ...giftItems];

    final pickedList = await showMultiFilterableListPicker(
      context: context,
      title: 'Échantillons & Goodies Remis',
      items: combinedItems,
      searchHint: 'Filtrer les lots et objets en stock...',
      selectedIds: _selectedSamples,
      allowCustom: true,
    );

    if (pickedList != null) {
      setState(() {
        _selectedSamples = pickedList.map((i) => i.id).toList();
        _samplesCtrl.text = _selectedSamples.join(', ');
      });
    }
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
      'doctor_id': null,
      'account_name': _doctorCtrl.text.trim(),
      'activity_type': _activityType,
      'rep_name': repName,
      'rep_id': repId,
      'purpose': _purpose,
      'products_discussed': _productsCtrl.text.trim(),
      'samples_distributed': _samplesCtrl.text.trim(),
      'gifts_distributed': '',
      'feedback_notes': _feedbackCtrl.text.trim(),
      'next_followup_date': '',
      'latitude': _latitude,
      'longitude': _longitude,
      'created_at': DateTime.now().toIso8601String(),
      'sync_status': 'pending',
    };

    bool syncedOnline = false;
    try {
      // Attempt immediate sync to Next.js API
      await apiService.logVisit(
        // Mapping to model
        // Will succeed if online
        // If timeout or no connection, catches below and enqueues to SQLite
        (await dbHelper.enqueueVisit(visitPayload)) as dynamic,
      );
      syncedOnline = true;
    } catch (e) {
      // Offline fallback: save to local SQLite
      await dbHelper.enqueueVisit(visitPayload);
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
                      color: const Color(0xFF0F766E).withOpacity(0.1),
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
              value: _activityType,
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
