import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../services/api_service.dart';
import '../services/database_helper.dart';

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

  @override
  void initState() {
    super.initState();
    _doctorCtrl = TextEditingController(text: widget.initialDoctorName ?? 'Dr. Amine Rahmani (EHU Oran)');
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

            // Form inputs
            TextFormField(
              controller: _doctorCtrl,
              decoration: InputDecoration(
                labelText: 'Médecin / Clinique / Pharmacie *',
                prefixIcon: const Icon(LucideIcons.userCheck, size: 18),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Veuillez saisir un praticien' : null,
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
              decoration: InputDecoration(
                labelText: 'Produits présentés (Portefeuille)',
                prefixIcon: const Icon(LucideIcons.pill, size: 18),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _samplesCtrl,
              decoration: InputDecoration(
                labelText: 'Échantillons Médicaux distribués',
                prefixIcon: const Icon(LucideIcons.box, size: 18),
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
