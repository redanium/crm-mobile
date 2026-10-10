import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/medicine_directory_entry.dart';
import '../services/api_service.dart';

class MedicineDirectoryScreen extends StatefulWidget {
  const MedicineDirectoryScreen({super.key});

  @override
  State<MedicineDirectoryScreen> createState() => _MedicineDirectoryScreenState();
}

class _MedicineDirectoryScreenState extends State<MedicineDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<MedicineDirectoryEntry> _items = [];
  bool _isLoading = false;
  String? _error;
  String _searchedTerm = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.length < 3) {
      setState(() {
        _error = 'Saisissez au moins 3 caractères pour rechercher.';
        _items = [];
        _searchedTerm = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _items = [];
      _searchedTerm = query;
    });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final results = await api.searchMedicineDirectory(query);
      if (!mounted) return;
      setState(() => _items = results);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Annuaire indisponible. Réessayez dans un instant.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Annuaire médicaments')),
      body: Column(children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFC7D2FE)),
          ),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.menu_book_rounded, color: Color(0xFF4338CA), size: 19),
            SizedBox(width: 9),
            Expanded(child: Text(
              'Référentiel français BDPM · fiches informatives. Les résultats ne représentent pas un registre algérien.',
              style: TextStyle(fontSize: 11, height: 1.4, color: Color(0xFF3730A3)),
            )),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Nom, substance ou dosage…',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
            )),
            const SizedBox(width: 8),
            SizedBox(height: 50, child: FilledButton.icon(
              onPressed: _isLoading ? null : _search,
              icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.search_rounded, size: 18),
              label: const Text('Rechercher'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),
            )),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildResults()),
      ]),
    );
  }

  Widget _buildResults() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)));
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13))));
    }
    if (_items.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.medication_outlined, size: 38, color: Colors.blueGrey.shade300),
          const SizedBox(height: 10),
          Text(_searchedTerm.isEmpty ? 'Recherchez un médicament dans le référentiel.' : 'Aucun résultat trouvé.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        ]),
      ));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _medicineCard(_items[index]),
    );
  }

  Widget _medicineCard(MedicineDirectoryEntry medicine) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: ExpansionTile(
        leading: const CircleAvatar(backgroundColor: Color(0xFFCCFBF1), child: Icon(Icons.medication_outlined, color: Color(0xFF0F766E), size: 20)),
        title: Text(medicine.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('CIS ${medicine.cis}${medicine.dosageForm.isNotEmpty ? ' · ${medicine.dosageForm}' : ''}', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (medicine.holder.isNotEmpty || medicine.authorizationDate.isNotEmpty) ...[
            const Divider(height: 18),
            if (medicine.holder.isNotEmpty) _detailRow('Titulaire', medicine.holder),
            if (medicine.authorizationDate.isNotEmpty) _detailRow('Date AMM', medicine.authorizationDate),
          ],
          if (medicine.routes.isNotEmpty) ...[
            const SizedBox(height: 10),
            _detailLabel('Voies d’administration'),
            const SizedBox(height: 5),
            Wrap(spacing: 5, runSpacing: 5, children: medicine.routes.map((route) => Chip(
              label: Text(route, style: const TextStyle(fontSize: 10)),
              visualDensity: VisualDensity.compact,
              backgroundColor: const Color(0xFFF0FDFA),
              side: const BorderSide(color: Color(0xFFCCFBF1)),
              padding: EdgeInsets.zero,
            )).toList()),
          ],
          if (medicine.composition.isNotEmpty) ...[
            const SizedBox(height: 10),
            _detailLabel('Composition'),
            const SizedBox(height: 4),
            ...medicine.composition.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(padding: EdgeInsets.only(top: 5), child: Icon(Icons.circle, size: 5, color: Color(0xFF0F766E))),
                const SizedBox(width: 7),
                Expanded(child: Text(entry.substance, style: const TextStyle(fontSize: 11, color: Color(0xFF334155)))),
                if (entry.dosage.isNotEmpty) Text(entry.dosage, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
              ]),
            )),
          ],
          if (medicine.conditions.isNotEmpty) ...[
            const SizedBox(height: 10),
            _detailLabel('Conditions de prescription'),
            const SizedBox(height: 4),
            ...medicine.conditions.map((condition) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('• $condition', style: const TextStyle(fontSize: 11, height: 1.4, color: Color(0xFF475569))),
            )),
          ],
          const SizedBox(height: 12),
          const Text('Source : Base de Données Publique des Médicaments (France).', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _detailLabel(String label) => Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)));

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 105, child: Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)))),
    ]),
  );
}
