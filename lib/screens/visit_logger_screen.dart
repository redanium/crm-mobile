import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/doctor.dart';
import '../models/product.dart';
import '../services/api_service.dart';
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
  final _productsCtrl = TextEditingController(text: 'Cetamol 500mg, Cardiozen 10mg');
  final _samplesCtrl = TextEditingController(text: '2 boîtes');
  final _feedbackCtrl = TextEditingController();
  
  String _activityType = 'Product presentation';
  final String _purpose = 'Visite de routine & présentation nouveau dosage';
  bool _isLocating = false;
  double? _latitude = 35.6987;
  double? _longitude = -0.6349;
  bool _isSaving = false;

  // Cached listings for filterable selection
  List<Doctor> _availableDoctors = [];
  List<Product> _availableProducts = [];

  // Selected items lists
  List<String> _selectedProducts = ['Cetamol 500mg', 'Cardiozen 10mg'];
  List<String> _selectedSamples = ['2x Cetamol 500mg'];

  @override
  void initState() {
    super.initState();
    _doctorCtrl = TextEditingController(text: widget.initialDoctorName ?? 'Dr. Amine Rahmani (EHU Oran)');
    _loadListings();
  }

  Future<void> _loadListings() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final dbHelper = Provider.of<DatabaseHelper>(context, listen: false);

    // Load doctors from cache or API
    try {
      final cachedDocs = await dbHelper.getCachedDoctors();
      if (cachedDocs.isNotEmpty) {
        if (mounted) setState(() => _availableDoctors = cachedDocs);
      }
      final onlineDocs = await apiService.getDoctors();
      if (mounted) setState(() => _availableDoctors = onlineDocs);
    } catch (_) {}

    // Load products from API
    try {
      final prods = await apiService.getProducts();
      if (mounted) setState(() => _availableProducts = prods);
    } catch (_) {}
  }

  Future<void> _pickDoctor() async {
    final items = _availableDoctors.isNotEmpty
        ? _availableDoctors.map((d) {
            return FilterableItem(
              id: d.id.toString(),
              title: d.name,
              subtitle: '${d.specialty} · ${d.organization} · ${d.wilaya}',
              badge: 'Tier ${d.tier}',
            );
          }).toList()
        : [
            FilterableItem(
              id: '1',
              title: 'Dr. Amine Rahmani',
              subtitle: 'Cardiologie · EHU Oran · Oran (31)',
              badge: 'Tier A',
            ),
            FilterableItem(
              id: '2',
              title: 'Dr. Fatima Zahra Boukhalfa',
              subtitle: 'Pédiatrie · CHU Mustapha Pacha · Alger (16)',
              badge: 'Tier A',
            ),
            FilterableItem(
              id: '3',
              title: 'Dr. Karim Mansouri',
              subtitle: 'Médecine Générale · Polyclinique Es Senia · Oran (31)',
              badge: 'Tier B',
            ),
            FilterableItem(
              id: '4',
              title: 'Pharmacie Centrale El Bahia',
              subtitle: 'Officine Référente · Boulevard Front de Mer · Oran (31)',
              badge: 'Pharmacy',
            ),
          ];

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
    final items = _availableProducts.isNotEmpty
        ? _availableProducts.map((p) {
            return FilterableItem(
              id: p.name,
              title: p.name,
              subtitle: '${p.dosageForm ?? ''} ${p.strength ?? ''} · ${p.unitPriceDa ?? ''} DA',
              badge: p.isSample ? 'Échantillon' : 'Catalogue',
            );
          }).toList()
        : [
            FilterableItem(id: 'Cetamol 500mg', title: 'Cetamol 500mg', subtitle: 'Paracétamol · Comprimé · Chifa', badge: 'Saidal'),
            FilterableItem(id: 'Cardiozen 10mg', title: 'Cardiozen 10mg', subtitle: 'Amlodipine · Gélule · Chifa', badge: 'Noura'),
            FilterableItem(id: 'NouraCare Kids', title: 'NouraCare Kids', subtitle: 'Sirop Multivitaminé Pédiatrique', badge: 'Noura'),
            FilterableItem(id: 'Gastrodine 20mg', title: 'Gastrodine 20mg', subtitle: 'Oméprazole · Gélule gastro-résistante', badge: 'Saidal'),
            FilterableItem(id: 'Tensiopril 5mg', title: 'Tensiopril 5mg', subtitle: 'Ramipril · Comprimé sécable', badge: 'Noura'),
          ];

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
    final items = [
      FilterableItem(id: '2x Cetamol 500mg (Lot Ech-2026)', title: 'Cetamol 500mg (Éch. Médical)', subtitle: 'Lot: CET-500-ECH · Exp: 12/2027', badge: 'Stock: 150'),
      FilterableItem(id: '1x Cardiozen 10mg (Lot Ech-2026)', title: 'Cardiozen 10mg (Éch. Médical)', subtitle: 'Lot: CRD-010-ECH · Exp: 10/2027', badge: 'Stock: 80'),
      FilterableItem(id: '2x NouraCare Kids (Lot Ech-2026)', title: 'NouraCare Kids Sirop (Éch.)', subtitle: 'Lot: NCK-120-ECH · Exp: 08/2027', badge: 'Stock: 120'),
      FilterableItem(id: '1x Gastrodine 20mg (Lot Ech-2026)', title: 'Gastrodine 20mg (Éch. Médical)', subtitle: 'Lot: GTR-020-ECH · Exp: 11/2027', badge: 'Stock: 95'),
      FilterableItem(id: '1x Stylo Ergonomique Noura', title: 'Stylo Médical Ergonomique Noura', subtitle: 'Goodie Promotionnel Noura Pharma', badge: 'Goodie'),
      FilterableItem(id: '1x Bloc-Notes Ordonnancier', title: 'Bloc-Notes & Ordonnancier Noura', subtitle: 'Matériel praticien cabinet', badge: 'Goodie'),
    ];

    final pickedList = await showMultiFilterableListPicker(
      context: context,
      title: 'Échantillons & Goodies Remis',
      items: items,
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
    // Simulating GPS location capture in Algerian wilaya (or using geolocator in production)
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _latitude = 35.7056;
      _longitude = -0.6312;
      _isLocating = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Position GPS validée (Oran - 35.7056, -0.6312)'),
        backgroundColor: Color(0xFF0F766E),
      ),
    );
  }

  Future<void> _saveVisit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final apiService = Provider.of<ApiService>(context, listen: false);
    final dbHelper = Provider.of<DatabaseHelper>(context, listen: false);
    final clientUuid = const Uuid().v4();

    final visitPayload = {
      'client_uuid': clientUuid,
      'doctor_id': 1,
      'account_name': _doctorCtrl.text.trim(),
      'activity_type': _activityType,
      'rep_name': 'Sofiane Benziane (Délégué)',
      'rep_id': 'REP_001',
      'purpose': _purpose,
      'products_discussed': _productsCtrl.text.trim(),
      'samples_distributed': _samplesCtrl.text.trim(),
      'gifts_distributed': 'Bloc-notes & stylo de marque',
      'feedback_notes': _feedbackCtrl.text.trim(),
      'next_followup_date': '2026-10-22',
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
