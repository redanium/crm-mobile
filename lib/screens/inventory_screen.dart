import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<SampleBatch> _samples = [];
  List<PromotionalGift> _gifts = [];
  List<Product> _products = [];
  List<Map<String, dynamic>> _movements = [];
  List<Map<String, dynamic>> _pendingReceipts = [];
  bool _isLoading = true;
  bool _isOffline = false;
  bool _isGpm = false;
  bool _savingReceipt = false;
  static const _uriReader = MethodChannel('crm_visit_proof/uri_reader');

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    final database = Provider.of<DatabaseHelper>(context, listen: false);
    final api = Provider.of<ApiService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    _isGpm = auth.currentUser?.role == 'group_product_manager';

    try {
      final cachedSamples = await database.getCachedSamples();
      final cachedGifts = await database.getCachedGifts();
      final cachedMovements = await database.getCachedStockMovements();
      if (mounted) {
        setState(() {
          _samples = cachedSamples
              .where((item) => item.isAllocated && item.quantity > 0)
              .toList();
          _gifts = cachedGifts
              .where((item) => item.isAllocated && item.quantity > 0)
              .toList();
          _movements = cachedMovements;
          _isLoading = false;
        });
      }
    } catch (_) {}

    try {
      final bundle = await api.getCatalogBundle();
      final products = bundle['products'] as List<Product>? ?? [];
      final rawMovements = bundle['movements'] as List<dynamic>? ?? [];
      final movements = rawMovements
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      final pendingReceipts =
          (bundle['pendingReceipts'] as List<dynamic>? ?? [])
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
      final pending = await database.getPendingVisits();
      final reserved = <String, int>{};
      for (final visit in pending) {
        final raw = visit['inventory_distributions'];
        final lines = raw is String
            ? (jsonDecode(raw) as List<dynamic>? ?? [])
            : (raw as List<dynamic>? ?? []);
        for (final line in lines) {
          final item = Map<String, dynamic>.from(line as Map);
          final key = '${item['itemType']}:${item['itemId']}';
          reserved[key] = (reserved[key] ?? 0) +
              (int.tryParse(item['quantity'].toString()) ?? 0);
        }
      }
      final samples = (bundle['samples'] as List<SampleBatch>? ?? [])
          .map((item) => SampleBatch(
                id: item.id,
                prodId: item.prodId,
                brandName: item.brandName,
                expiry: item.expiry,
                quantity: (item.quantity - (reserved['sample:${item.id}'] ?? 0))
                    .clamp(0, item.quantity)
                    .toInt(),
                initialQuantity: item.initialQuantity,
                unit: item.unit,
                isAllocated: item.isAllocated,
              ))
          .toList();
      final gifts = (bundle['gifts'] as List<PromotionalGift>? ?? [])
          .map((item) => PromotionalGift(
                id: item.id,
                giftId: item.giftId,
                name: item.name,
                quantity: (item.quantity - (reserved['gift:${item.id}'] ?? 0))
                    .clamp(0, item.quantity)
                    .toInt(),
                initialQuantity: item.initialQuantity,
                distributed: item.distributed,
                isAllocated: item.isAllocated,
              ))
          .toList();
      await database.cacheCatalog(
          products: products, samples: samples, gifts: gifts);
      await database.cacheStockMovements(movements);
      if (!mounted) return;
      setState(() {
        _products = products;
        _samples = samples
            .where((item) => item.isAllocated && item.quantity > 0)
            .toList();
        _gifts = gifts
            .where((item) => item.isAllocated && item.quantity > 0)
            .toList();
        _movements = movements;
        _pendingReceipts = pendingReceipts;
        _isOffline = false;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _isOffline = true;
          _isLoading = false;
        });
    }
  }

  Future<List<int>> _readScannedFile(String fileUri) async {
    if (fileUri.startsWith('content://')) {
      final bytes =
          await _uriReader.invokeMethod<Uint8List>('readUri', {'uri': fileUri});
      if (bytes == null)
        throw Exception('Impossible de lire le document scanné.');
      return bytes;
    }
    final uri = Uri.tryParse(fileUri);
    final file = uri?.scheme == 'file' ? File.fromUri(uri!) : File(fileUri);
    return file.readAsBytes();
  }

  Future<List<Map<String, dynamic>>> _pickReceiptProofs(
      {required bool scan}) async {
    try {
      if (scan) {
        final result = await FlutterDocScanner().getScannedDocumentAsImages(
            page: 4, imageFormat: ImageFormat.jpeg, quality: 0.72);
        if (result == null || result.images.isEmpty) return [];
        final documents = <Map<String, dynamic>>[];
        for (var index = 0; index < result.images.length; index++) {
          documents.add({
            'fileName':
                'stock-receipt-${DateTime.now().millisecondsSinceEpoch}-${index + 1}.jpg',
            'mimeType': 'image/jpeg',
            'dataBase64':
                base64Encode(await _readScannedFile(result.images[index])),
          });
        }
        return documents;
      }
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
        withData: true,
      );
      if (result == null) return [];
      return result.files
          .where((file) => file.bytes != null && file.bytes!.isNotEmpty)
          .map((file) {
        final extension = file.extension?.toLowerCase();
        final mimeType = extension == 'pdf'
            ? 'application/pdf'
            : extension == 'png'
                ? 'image/png'
                : 'image/jpeg';
        return {
          'fileName': file.name,
          'mimeType': mimeType,
          'dataBase64': base64Encode(file.bytes!)
        };
      }).toList();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ajout de preuve impossible : $error')));
      return [];
    }
  }

  bool _receiptProofLimitOk(List<Map<String, dynamic>> documents) {
    final bytes = documents.fold<int>(
        0,
        (sum, document) =>
            sum + base64Decode(document['dataBase64'] as String).length);
    if (documents.length <= 10 && bytes <= 4 * 1024 * 1024) return true;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 10 fichiers et 4 Mo au total.')));
    return false;
  }

  Future<void> _showReceiveDialog(String itemType) async {
    final api = Provider.of<ApiService>(context, listen: false);
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final expiryController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final productOptions = _products;
    int? selectedProductId =
        productOptions.isNotEmpty ? productOptions.first.id : null;
    String unit = 'boîte';
    bool confirmed = false;
    List<Map<String, dynamic>> documents = [];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, refresh) => AlertDialog(
                title: Text(itemType == 'sample'
                    ? 'Réception d’échantillons'
                    : 'Réception de cadeaux'),
                content: SizedBox(
                    width: 520,
                    child: SingleChildScrollView(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          if (itemType == 'sample') ...[
                            DropdownButtonFormField<int>(
                              value: selectedProductId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                  labelText: 'Produit du portefeuille',
                                  border: OutlineInputBorder()),
                              items: productOptions
                                  .map((product) => DropdownMenuItem(
                                      value: product.id,
                                      child: Text(
                                          '${product.name} · ${product.code ?? product.strength ?? ''}',
                                          overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              onChanged: (value) =>
                                  refresh(() => selectedProductId = value),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                                controller: codeController,
                                decoration: const InputDecoration(
                                    labelText: 'Code du lot',
                                    border: OutlineInputBorder())),
                            const SizedBox(height: 10),
                            TextField(
                                controller: expiryController,
                                decoration: const InputDecoration(
                                    labelText: 'Expiration (MM/YYYY)',
                                    border: OutlineInputBorder())),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              value: unit,
                              decoration: const InputDecoration(
                                  labelText: 'Unité',
                                  border: OutlineInputBorder()),
                              items: const [
                                'boîte',
                                'plaquette',
                                'flacon',
                                'ampoule'
                              ]
                                  .map((value) => DropdownMenuItem(
                                      value: value, child: Text(value)))
                                  .toList(),
                              onChanged: (value) =>
                                  refresh(() => unit = value ?? 'boîte'),
                            ),
                          ] else ...[
                            TextField(
                                controller: nameController,
                                decoration: const InputDecoration(
                                    labelText: 'Nom du cadeau',
                                    border: OutlineInputBorder())),
                            const SizedBox(height: 10),
                            TextField(
                                controller: codeController,
                                decoration: const InputDecoration(
                                    labelText: 'Code stock (optionnel)',
                                    border: OutlineInputBorder())),
                          ],
                          const SizedBox(height: 10),
                          TextField(
                              controller: quantityController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Quantité reçue',
                                  border: OutlineInputBorder())),
                          const SizedBox(height: 6),
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                  'Confirmer la réception physique',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              subtitle: const Text(
                                  'Le stock devient disponible après confirmation avec une preuve.',
                                  style: TextStyle(fontSize: 11)),
                              value: confirmed,
                              onChanged: (value) =>
                                  refresh(() => confirmed = value)),
                          Wrap(spacing: 8, children: [
                            OutlinedButton.icon(
                                onPressed: () async {
                                  final picked =
                                      await _pickReceiptProofs(scan: true);
                                  if (picked.isNotEmpty &&
                                      _receiptProofLimitOk(
                                          [...documents, ...picked]))
                                    refresh(() =>
                                        documents = [...documents, ...picked]);
                                },
                                icon:
                                    const Icon(LucideIcons.scanLine, size: 16),
                                label: const Text('Scanner')),
                            OutlinedButton.icon(
                                onPressed: () async {
                                  final picked =
                                      await _pickReceiptProofs(scan: false);
                                  if (picked.isNotEmpty &&
                                      _receiptProofLimitOk(
                                          [...documents, ...picked]))
                                    refresh(() =>
                                        documents = [...documents, ...picked]);
                                },
                                icon: const Icon(LucideIcons.fileUp, size: 16),
                                label: const Text('PDF / fichier')),
                          ]),
                          if (documents.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('${documents.length} preuve(s) ajoutée(s)',
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF0F766E))),
                          ],
                        ]))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Annuler')),
                  FilledButton(
                      onPressed: _savingReceipt
                          ? null
                          : () async {
                              final quantity =
                                  int.tryParse(quantityController.text.trim());
                              if (quantity == null ||
                                  quantity <= 0 ||
                                  (itemType == 'sample' &&
                                      (selectedProductId == null ||
                                          codeController.text.trim().isEmpty ||
                                          expiryController.text
                                              .trim()
                                              .isEmpty)) ||
                                  (itemType == 'gift' &&
                                      nameController.text.trim().isEmpty)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Complétez les informations de réception.')));
                                return;
                              }
                              if (confirmed && documents.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Ajoutez un scan ou un PDF avant de confirmer.')));
                                return;
                              }
                              refresh(() => _savingReceipt = true);
                              var dialogClosed = false;
                              try {
                                final result = await api.submitInventoryReceipt(
                                  itemType: itemType,
                                  fields: itemType == 'sample'
                                      ? {
                                          'productId':
                                              selectedProductId.toString(),
                                          'prodId': codeController.text.trim(),
                                          'expiry':
                                              expiryController.text.trim(),
                                          'quantity': quantity.toString(),
                                          'unit': unit
                                        }
                                      : {
                                          'name': nameController.text.trim(),
                                          'giftId': codeController.text.trim(),
                                          'quantity': quantity.toString()
                                        },
                                  confirmed: confirmed,
                                  documents: documents,
                                );
                                if (!mounted) return;
                                if (result['success'] == true) {
                                  refresh(() => _savingReceipt = false);
                                  dialogClosed = true;
                                  Navigator.pop(dialogContext);
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                      content: Text(confirmed
                                          ? 'Réception confirmée; stock disponible.'
                                          : 'Réception enregistrée en attente de confirmation.')));
                                  await _loadInventory();
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              result['error']?.toString() ??
                                                  'Réception impossible.')));
                                }
                              } catch (error) {
                                if (mounted)
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Réception impossible : $error')));
                              } finally {
                                if (mounted && !dialogClosed)
                                  refresh(() => _savingReceipt = false);
                              }
                            },
                      child: Text(_savingReceipt
                          ? 'Enregistrement…'
                          : confirmed
                              ? 'Confirmer'
                              : 'Enregistrer')),
                ],
              )),
    );
    nameController.dispose();
    codeController.dispose();
    expiryController.dispose();
    quantityController.dispose();
  }

  Future<void> _confirmPendingReceipt(Map<String, dynamic> receipt) async {
    final api = Provider.of<ApiService>(context, listen: false);
    List<Map<String, dynamic>> documents = [];
    final existingDocuments = (receipt['documents'] as List<dynamic>? ?? []);
    final movementId = int.tryParse(receipt['id']?.toString() ?? '');
    if (movementId == null) return;
    final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, refresh) => AlertDialog(
                  title: const Text('Confirmer la réception'),
                  content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${receipt['itemName'] ?? 'Stock'} · ${receipt['quantity']} unités'),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, children: [
                          OutlinedButton.icon(
                              onPressed: () async {
                                final picked =
                                    await _pickReceiptProofs(scan: true);
                                if (picked.isNotEmpty &&
                                    _receiptProofLimitOk(
                                        [...documents, ...picked]))
                                  refresh(() =>
                                      documents = [...documents, ...picked]);
                              },
                              icon: const Icon(LucideIcons.scanLine, size: 16),
                              label: const Text('Scanner')),
                          OutlinedButton.icon(
                              onPressed: () async {
                                final picked =
                                    await _pickReceiptProofs(scan: false);
                                if (picked.isNotEmpty &&
                                    _receiptProofLimitOk(
                                        [...documents, ...picked]))
                                  refresh(() =>
                                      documents = [...documents, ...picked]);
                              },
                              icon: const Icon(LucideIcons.fileUp, size: 16),
                              label: const Text('PDF / fichier')),
                        ]),
                        if (documents.isNotEmpty)
                          Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                  '${documents.length} preuve(s) ajoutée(s)',
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFF0F766E)))),
                      ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Annuler')),
                    FilledButton(
                        onPressed:
                            documents.isEmpty && existingDocuments.isEmpty
                                ? null
                                : () => Navigator.pop(dialogContext, true),
                        child: const Text('Confirmer')),
                  ],
                )));
    if (confirm != true) return;
    try {
      final result = await api.confirmInventoryReceipt(
          movementId: movementId, documents: documents);
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Réception confirmée; stock disponible.')));
        await _loadInventory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                result['error']?.toString() ?? 'Confirmation impossible.')));
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Confirmation impossible : $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = _samples.length + _gifts.length;
    final totalQuantity =
        _samples.fold<int>(0, (sum, item) => sum + item.quantity) +
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
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F766E)))
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
                        Icon(LucideIcons.wifiOff,
                            size: 17, color: Color(0xFFB45309)),
                        SizedBox(width: 8),
                        Expanded(
                            child: Text(
                                'Mode hors ligne · dernières quantités synchronisées',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF92400E)))),
                      ]),
                    ),
                  if (_isGpm) ...[
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF99F6E4))),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Réception initiale du stock',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A))),
                            const SizedBox(height: 4),
                            const Text(
                                'Scannez un justificatif ou joignez un PDF. Le stock reste indisponible tant que la réception n’est pas confirmée.',
                                style: TextStyle(
                                    fontSize: 11, color: Color(0xFF64748B))),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(
                                  child: OutlinedButton.icon(
                                      onPressed: _isOffline
                                          ? null
                                          : () => _showReceiveDialog('sample'),
                                      icon: const Icon(LucideIcons.packagePlus,
                                          size: 16),
                                      label: const Text('Recevoir échantillons',
                                          style: TextStyle(fontSize: 11)))),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: OutlinedButton.icon(
                                      onPressed: _isOffline
                                          ? null
                                          : () => _showReceiveDialog('gift'),
                                      icon: const Icon(LucideIcons.gift,
                                          size: 16),
                                      label: const Text('Recevoir cadeaux',
                                          style: TextStyle(fontSize: 11)))),
                            ]),
                          ]),
                    ),
                    if (_pendingReceipts.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _sectionTitle(
                          'Réceptions à confirmer',
                          LucideIcons.clipboardCheck,
                          const Color(0xFFD97706),
                          _pendingReceipts.length),
                      const SizedBox(height: 8),
                      ..._pendingReceipts.map((receipt) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(LucideIcons.clock3,
                                  color: Color(0xFFD97706)),
                              title: Text(
                                  receipt['itemName']?.toString() ??
                                      'Stock à confirmer',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                  '${receipt['itemType'] == 'sample' ? 'Échantillon' : 'Cadeau'} · ${receipt['quantity']} unités · ${((receipt['documents'] as List?) ?? []).length} preuve(s)',
                                  style: const TextStyle(fontSize: 10)),
                              trailing: TextButton(
                                  onPressed: _isOffline
                                      ? null
                                      : () => _confirmPendingReceipt(receipt),
                                  child: const Text('Confirmer',
                                      style: TextStyle(fontSize: 11))),
                            ),
                          )),
                    ],
                    const SizedBox(height: 18),
                  ],
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                          colors: [Color(0xFF0F766E), Color(0xFF115E59)]),
                    ),
                    child: Row(children: [
                      const Icon(LucideIcons.package,
                          color: Colors.white, size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('Mon stock attribué',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            const SizedBox(height: 3),
                            Text(
                                '$totalItems références · $totalQuantity unités disponibles',
                                style: const TextStyle(
                                    color: Color(0xFFD1FAE5), fontSize: 12)),
                          ])),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('Échantillons médicaux', LucideIcons.package,
                      const Color(0xFF0F766E), _samples.length),
                  const SizedBox(height: 9),
                  if (_samples.isEmpty)
                    _emptyCard('Aucun échantillon attribué',
                        'Les lots transmis dans votre hiérarchie apparaîtront ici.')
                  else
                    ..._samples.map(_sampleCard),
                  const SizedBox(height: 20),
                  _sectionTitle('Cadeaux & objets promotionnels',
                      LucideIcons.gift, const Color(0xFF7C3AED), _gifts.length),
                  const SizedBox(height: 9),
                  if (_gifts.isEmpty)
                    _emptyCard('Aucun cadeau attribué',
                        'Les cadeaux transmis dans votre hiérarchie apparaîtront ici.')
                  else
                    ..._gifts.map(_giftCard),
                  const SizedBox(height: 20),
                  _sectionTitle('Mouvements récents', LucideIcons.activity,
                      const Color(0xFF2563EB), _movements.length),
                  const SizedBox(height: 9),
                  if (_movements.isEmpty)
                    _emptyCard('Aucun mouvement',
                        'Les allocations et distributions récentes apparaîtront ici.')
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
      Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A)))),
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20)),
          child: Text('$count',
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.bold))),
    ]);
  }

  Widget _sampleCard(SampleBatch sample) => _stockCard(
        title: sample.brandName,
        code: 'Lot ${sample.prodId}',
        detail: sample.isExpired
            ? 'EXPIRÉ · À détruire · Expiration : ${sample.expiry}'
            : 'Expiration : ${sample.expiry}',
        quantity: sample.quantity,
        initialQuantity: sample.initialQuantity,
        unit: sample.unit,
        color: sample.isExpired
            ? const Color(0xFFDC2626)
            : const Color(0xFF0F766E),
        icon: LucideIcons.package,
        isExpired: sample.isExpired,
        onDestroy: sample.isExpired && sample.quantity > 0
            ? () => _destroyExpiredSample(sample)
            : null,
      );

  Future<void> _destroyExpiredSample(SampleBatch sample) async {
    final controller = TextEditingController(text: sample.quantity.toString());
    final quantity = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Détruire le lot expiré'),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${sample.brandName} · Lot ${sample.prodId}\nStock restant : ${sample.quantity} ${sample.unit}'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Quantité à détruire',
                    border: OutlineInputBorder()),
              ),
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value != null && value > 0 && value <= sample.quantity)
                Navigator.pop(dialogContext, value);
            },
            child: const Text('Confirmer la destruction'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (quantity == null || !mounted) return;
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final result = await api.destroyExpiredSample(
          sampleId: sample.id, quantity: quantity);
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Stock expiré détruit et mouvement enregistré.')));
        await _loadInventory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                result['error']?.toString() ?? 'Destruction impossible.')));
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Destruction impossible : $error')));
    }
  }

  Widget _giftCard(PromotionalGift gift) => _stockCard(
        title: gift.name,
        code: gift.giftId,
        detail: 'Objet promotionnel',
        quantity: gift.quantity,
        initialQuantity: gift.initialQuantity,
        unit: 'unité(s)',
        color: const Color(0xFF7C3AED),
        icon: LucideIcons.gift,
      );

  Widget _movementCard(Map<String, dynamic> movement) {
    final type = movement['movement_type']?.toString() ??
        movement['movementType']?.toString() ??
        '';
    final itemType = movement['item_type']?.toString() ??
        movement['itemType']?.toString() ??
        '';
    final name = movement['item_name']?.toString() ??
        movement['itemName']?.toString() ??
        'Article de stock';
    final rawDate = movement['created_at']?.toString() ??
        movement['createdAt']?.toString() ??
        '';
    final date = DateTime.tryParse(rawDate)?.toLocal();
    final quantity = int.tryParse(movement['quantity']?.toString() ?? '0') ?? 0;
    final note = movement['notes']?.toString() ?? '';
    final sourceName = movement['sourceName']?.toString() ??
        movement['source_name']?.toString() ??
        '';
    final isDestruction =
        type == 'adjustment' && note.toLowerCase().contains('destroy');
    final isRemoval = type == 'visit_use' || isDestruction;
    final label = switch (type) {
      'allocation' => sourceName.isNotEmpty
          ? 'Transféré par $sourceName'
          : 'Transfert hiérarchique',
      'visit_use' => 'Distribué pendant une visite',
      'return' => 'Retour au stock',
      'adjustment' =>
        isDestruction ? 'Lot expiré détruit' : 'Ajustement du stock',
      'receipt' => 'Réception de stock',
      _ => type.replaceAll('_', ' '),
    };
    final color = isRemoval ? const Color(0xFFDC2626) : const Color(0xFF0F766E);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(children: [
        Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(
                isRemoval
                    ? LucideIcons.arrowUpRight
                    : LucideIcons.arrowDownLeft,
                color: color,
                size: 17)),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 3),
          Text('${itemType == 'sample' ? 'Échantillon' : 'Cadeau'} · $label',
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
          if (note.isNotEmpty && !isDestruction) ...[
            const SizedBox(height: 2),
            Text(note,
                style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
          if (date != null) ...[
            const SizedBox(height: 2),
            Text(
                '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
          ],
        ])),
        Text('${isRemoval ? '−' : '+'}$quantity',
            style: TextStyle(
                color: color, fontSize: 15, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _stockCard(
      {required String title,
      required String code,
      required String detail,
      required int quantity,
      int? initialQuantity,
      required String unit,
      required Color color,
      required IconData icon,
      bool isExpired = false,
      VoidCallback? onDestroy}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: isExpired ? const Color(0xFFFEF2F2) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
              color:
                  isExpired ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
              width: isExpired ? 1.5 : 1)),
      child: Row(children: [
        Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 19)),
        const SizedBox(width: 11),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 3),
          Text('$code · $detail',
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          if (initialQuantity != null) ...[
            const SizedBox(height: 3),
            Text('Initial : $initialQuantity · Restant : $quantity',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569))),
          ],
          if (onDestroy != null) ...[
            const SizedBox(height: 6),
            TextButton.icon(
                onPressed: onDestroy,
                icon: const Icon(LucideIcons.trash2, size: 13),
                label: const Text('Détruire le stock expiré',
                    style: TextStyle(fontSize: 10)),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFB91C1C),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 26),
                    alignment: Alignment.centerLeft)),
          ],
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$quantity',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 19, color: color)),
          Text(unit,
              style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
        ]),
      ]),
    );
  }

  Widget _emptyCard(String title, String detail) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Row(children: [
          const Icon(LucideIcons.package, color: Color(0xFF94A3B8), size: 21),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155))),
                const SizedBox(height: 3),
                Text(detail,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF64748B))),
              ])),
        ]),
      );
}
