import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/database_helper.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<SampleBatch> _samples = [];
  List<PromotionalGift> _gifts = [];
  List<Map<String, dynamic>> _movements = [];
  bool _isLoading = true;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    final database = Provider.of<DatabaseHelper>(context, listen: false);
    final api = Provider.of<ApiService>(context, listen: false);

    try {
      final cachedSamples = await database.getCachedSamples();
      final cachedGifts = await database.getCachedGifts();
      final cachedMovements = await database.getCachedStockMovements();
      if (mounted) {
        setState(() {
          _samples = cachedSamples.where((item) => item.isAllocated).toList();
          _gifts = cachedGifts.where((item) => item.isAllocated).toList();
          _movements = cachedMovements;
          _isLoading = false;
        });
      }
    } catch (_) {}

    try {
      final bundle = await api.getCatalogBundle();
      final products = bundle['products'] as List<Product>? ?? [];
      final rawMovements = bundle['movements'] as List<dynamic>? ?? [];
      final movements = rawMovements.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      final pending = await database.getPendingVisits();
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
      final samples = (bundle['samples'] as List<SampleBatch>? ?? []).map((item) => SampleBatch(
        id: item.id, prodId: item.prodId, brandName: item.brandName, expiry: item.expiry,
        quantity: (item.quantity - (reserved['sample:${item.id}'] ?? 0)).clamp(0, item.quantity).toInt(),
        unit: item.unit, isAllocated: item.isAllocated,
      )).toList();
      final gifts = (bundle['gifts'] as List<PromotionalGift>? ?? []).map((item) => PromotionalGift(
        id: item.id, giftId: item.giftId, name: item.name,
        quantity: (item.quantity - (reserved['gift:${item.id}'] ?? 0)).clamp(0, item.quantity).toInt(),
        distributed: item.distributed, isAllocated: item.isAllocated,
      )).toList();
      await database.cacheCatalog(products: products, samples: samples, gifts: gifts);
      await database.cacheStockMovements(movements);
      if (!mounted) return;
      setState(() {
        _samples = samples.where((item) => item.isAllocated).toList();
        _gifts = gifts.where((item) => item.isAllocated).toList();
        _movements = movements;
        _isOffline = false;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _isOffline = true; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = _samples.length + _gifts.length;
    final totalQuantity = _samples.fold<int>(0, (sum, item) => sum + item.quantity) +
        _gifts.fold<int>(0, (sum, item) => sum + item.quantity);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Échantillons & cadeaux'),
        actions: [
          IconButton(
            tooltip: 'Actualiser le stock',
            onPressed: _loadInventory,
            icon: const Icon(LucideIcons.refreshCw, size: 19),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)))
          : RefreshIndicator(
              onRefresh: _loadInventory,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_isOffline)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Row(children: [
                        Icon(LucideIcons.wifiOff, size: 17, color: Color(0xFFB45309)),
                        SizedBox(width: 8),
                        Expanded(child: Text('Mode hors ligne · dernières quantités synchronisées', style: TextStyle(fontSize: 12, color: Color(0xFF92400E)))),
                      ]),
                    ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF115E59)]),
                    ),
                    child: Row(children: [
                      const Icon(LucideIcons.package, color: Colors.white, size: 26),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Mon stock attribué', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 3),
                        Text('$totalItems références · $totalQuantity unités disponibles', style: const TextStyle(color: Color(0xFFD1FAE5), fontSize: 12)),
                      ])),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('Échantillons médicaux', LucideIcons.package, const Color(0xFF0F766E), _samples.length),
                  const SizedBox(height: 9),
                  if (_samples.isEmpty)
                    _emptyCard('Aucun échantillon attribué', 'Votre superviseur n’a pas encore ajouté de lot à votre stock.')
                  else
                    ..._samples.map(_sampleCard),
                  const SizedBox(height: 20),
                  _sectionTitle('Cadeaux & objets promotionnels', LucideIcons.gift, const Color(0xFF7C3AED), _gifts.length),
                  const SizedBox(height: 9),
                  if (_gifts.isEmpty)
                    _emptyCard('Aucun cadeau attribué', 'Les cadeaux remis par votre superviseur apparaîtront ici.')
                  else
                    ..._gifts.map(_giftCard),
                  const SizedBox(height: 20),
                  _sectionTitle('Mouvements récents', LucideIcons.activity, const Color(0xFF2563EB), _movements.length),
                  const SizedBox(height: 9),
                  if (_movements.isEmpty)
                    _emptyCard('Aucun mouvement', 'Les allocations et distributions récentes apparaîtront ici.')
                  else
                    ..._movements.map(_movementCard),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String title, IconData icon, Color color, int count) {
    return Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 7),
      Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
      Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)), child: Text('$count', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold))),
    ]);
  }

  Widget _sampleCard(SampleBatch sample) => _stockCard(
        title: sample.brandName,
        code: 'Lot ${sample.prodId}',
        detail: 'Expiration : ${sample.expiry}',
        quantity: sample.quantity,
        unit: sample.unit,
        color: const Color(0xFF0F766E),
        icon: LucideIcons.package,
      );

  Widget _giftCard(PromotionalGift gift) => _stockCard(
        title: gift.name,
        code: gift.giftId,
        detail: 'Objet promotionnel',
        quantity: gift.quantity,
        unit: 'unité(s)',
        color: const Color(0xFF7C3AED),
        icon: LucideIcons.gift,
      );

  Widget _movementCard(Map<String, dynamic> movement) {
    final type = movement['movement_type']?.toString() ?? movement['movementType']?.toString() ?? '';
    final itemType = movement['item_type']?.toString() ?? movement['itemType']?.toString() ?? '';
    final name = movement['item_name']?.toString() ?? movement['itemName']?.toString() ?? 'Article de stock';
    final rawDate = movement['created_at']?.toString() ?? movement['createdAt']?.toString() ?? '';
    final date = DateTime.tryParse(rawDate)?.toLocal();
    final quantity = int.tryParse(movement['quantity']?.toString() ?? '0') ?? 0;
    final isUse = type == 'visit_use';
    final label = switch (type) {
      'allocation' => 'Attribué par le superviseur',
      'visit_use' => 'Distribué pendant une visite',
      'return' => 'Retour au stock',
      'adjustment' => 'Ajustement du stock',
      'receipt' => 'Réception de stock',
      _ => type.replaceAll('_', ' '),
    };
    final color = isUse ? const Color(0xFFDC2626) : const Color(0xFF0F766E);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(isUse ? LucideIcons.arrowUpRight : LucideIcons.arrowDownLeft, color: color, size: 17)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
          const SizedBox(height: 3),
          Text('${itemType == 'sample' ? 'Échantillon' : 'Cadeau'} · $label', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
          if (date != null) ...[
            const SizedBox(height: 2),
            Text('${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
          ],
        ])),
        Text('${isUse ? '−' : '+'}$quantity', style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _stockCard({required String title, required String code, required String detail, required int quantity, required String unit, required Color color, required IconData icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 19)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
          const SizedBox(height: 3),
          Text('$code · $detail', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)), maxLines: 2, overflow: TextOverflow.ellipsis),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$quantity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: color)),
          Text(unit, style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
        ]),
      ]),
    );
  }

  Widget _emptyCard(String title, String detail) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Row(children: [
          const Icon(LucideIcons.package, color: Color(0xFF94A3B8), size: 21),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
            const SizedBox(height: 3),
            Text(detail, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ])),
        ]),
      );
}
