import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';

class OfflineSyncScreen extends StatefulWidget {
  const OfflineSyncScreen({super.key});

  @override
  State<OfflineSyncScreen> createState() => _OfflineSyncScreenState();
}

class _OfflineSyncScreenState extends State<OfflineSyncScreen> {
  List<Map<String, dynamic>> _pendingVisits = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadPendingQueue();
  }

  Future<void> _loadPendingQueue() async {
    setState(() => _isLoading = true);
    final dbHelper = Provider.of<DatabaseHelper>(context, listen: false);
    final list = await dbHelper.getPendingVisits();
    setState(() {
      _pendingVisits = list;
      _isLoading = false;
    });
  }

  Future<void> _triggerCloudSync() async {
    if (_pendingVisits.isEmpty) return;
    setState(() => _isSyncing = true);

    final apiService = Provider.of<ApiService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final dbHelper = Provider.of<DatabaseHelper>(context, listen: false);

    final currentUserId = authService.currentUser?.id.isNotEmpty == true
        ? authService.currentUser!.id
        : 'REP_MOBILE';

    try {
      final res = await apiService.syncOfflineQueue(
        repId: currentUserId,
        queuedVisits: _pendingVisits,
      );

      // Mark local items as synced
      for (var visit in _pendingVisits) {
        final uuid = visit['client_uuid']?.toString();
        if (uuid != null) {
          await dbHelper.markVisitSynced(uuid);
        }
      }

      await _loadPendingQueue();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${res['processedCount'] ?? _pendingVisits.length} visites synchronisées avec succès !'),
          backgroundColor: const Color(0xFF0F766E),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Échec de synchronisation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('File de Synchronisation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)))
          : Column(
              children: [
                // Top status banner
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _pendingVisits.isEmpty
                              ? const Color(0xFF10B981).withValues(alpha: 0.1)
                              : const Color(0xFFD97706).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _pendingVisits.isEmpty ? LucideIcons.cloudCheck : LucideIcons.cloudUpload,
                          color: _pendingVisits.isEmpty ? const Color(0xFF10B981) : const Color(0xFFD97706),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _pendingVisits.isEmpty
                                  ? 'Tout est à jour !'
                                  : '${_pendingVisits.length} visites stockées hors-ligne',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const Text(
                              'Données sécurisées localement dans SQLite',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _pendingVisits.isEmpty || _isSyncing ? null : _triggerCloudSync,
                        icon: _isSyncing
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(LucideIcons.refreshCw, size: 16),
                        label: const Text('Sync QG'),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                Expanded(
                  child: _pendingVisits.isEmpty
                      ? const Center(
                          child: Text(
                            'Aucune visite en attente dans la file locale.',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _pendingVisits.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = _pendingVisits[index];
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(LucideIcons.userCheck, color: Color(0xFF0F766E), size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          item['account_name'] ?? 'Inconnu',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'En attente',
                                          style: TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Activité: ${item['activity_type']} • Échantillons: ${item['samples_distributed'] ?? 'Aucun'}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                  if (item['feedback_notes'] != null && (item['feedback_notes'] as String).isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Note: ${item['feedback_notes']}',
                                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF334155)),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
