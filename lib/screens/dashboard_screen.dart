import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import 'doctors_screen.dart';
import 'visit_logger_screen.dart';
import 'offline_sync_screen.dart';
import 'visits_history_screen.dart';
import 'geoalgeria_directory_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _pendingSyncCount = 0;
  bool _isLoading = true;
  int _todayVisitsCount = 0;
  int _targetVisitsCount = 0;
  int _samplesCount = 0;
  int _coveredWilayasCount = 0;
  String _wilayasSummaryText = 'Territoire assigné';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final dbHelper = Provider.of<DatabaseHelper>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);

    final pending = await dbHelper.getPendingVisits();
    try {
      final summaryRes = await apiService.getTerritorySummary();
      final territories = summaryRes['territories'] as List<dynamic>? ?? [];
      final summary = summaryRes['summary'] as Map<String, dynamic>?;

      final totalCompleted = summary?['totalCompleted'] is int
          ? summary!['totalCompleted'] as int
          : int.tryParse(summary?['totalCompleted']?.toString() ?? '0') ?? 0;
      final totalTarget = summary?['totalTarget'] is int
          ? summary!['totalTarget'] as int
          : int.tryParse(summary?['totalTarget']?.toString() ?? '0') ?? 0;

      final wilayaNames = territories
          .map((t) => t['wilayaName']?.toString())
          .where((w) => w != null && w.isNotEmpty)
          .take(3)
          .join(', ');

      // Also compute samples count from local cache
      final samplesList = await dbHelper.getCachedSamples();
      final totalSamplesInStock = samplesList.fold<int>(0, (sum, s) => sum + s.quantity);

      if (mounted) {
        setState(() {
          _pendingSyncCount = pending.length;
          _todayVisitsCount = totalCompleted + pending.length;
          _targetVisitsCount = totalTarget;
          _samplesCount = totalSamplesInStock;
          _coveredWilayasCount = territories.length;
          if (wilayaNames.isNotEmpty) {
            _wilayasSummaryText = wilayaNames;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      // Offline fallback
      if (mounted) {
        setState(() {
          _pendingSyncCount = pending.length;
          _todayVisitsCount = pending.length;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(LucideIcons.stethoscope, color: Color(0xFF0F766E), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentUser?.name ?? 'Pharma CRM DZ',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    currentUser?.email.isNotEmpty == true
                        ? currentUser!.email
                        : (currentUser?.role != null ? '${currentUser!.role!.toUpperCase()} • CRM Mobile' : 'Délégué Médical • Noura Pharma'),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(LucideIcons.refreshCw, size: 20),
                tooltip: 'Synchronisation',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OfflineSyncScreen()),
                  );
                  _loadDashboardData();
                },
              ),
              if (_pendingSyncCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_pendingSyncCount',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(LucideIcons.logOut, size: 19, color: Color(0xFF64748B)),
            tooltip: 'Déconnexion',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Déconnexion'),
                  content: const Text('Voulez-vous vraiment vous déconnecter de la session Better Auth ?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Annuler'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        authService.signOut();
                      },
                      child: const Text('Se déconnecter'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)))
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Offline Sync Warning Card if pending items
                  if (_pendingSyncCount > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.wifiOff, color: Color(0xFFD97706), size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$_pendingSyncCount Visite(s) en attente de sync',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                                ),
                                const Text(
                                  'Enregistrées hors-ligne. Appuyez pour synchroniser avec le QG.',
                                  style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD97706),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const OfflineSyncScreen()),
                            ),
                            child: const Text('Sync', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),

                  // Today KPI Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Visites Validées',
                          value: '$_todayVisitsCount / $_targetVisitsCount',
                          subtitle: _targetVisitsCount > 0
                              ? '${((_todayVisitsCount / _targetVisitsCount) * 100).round()}% objectif'
                              : 'Quota terrain',
                          icon: LucideIcons.checkCircle2,
                          color: const Color(0xFF0F766E),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const VisitsHistoryScreen()),
                            );
                            _loadDashboardData();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Stock Échantillons',
                          value: '$_samplesCount boîtes',
                          subtitle: 'Disponible inventaire',
                          icon: LucideIcons.package,
                          color: const Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12, height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Couverture Territoire',
                          value: '$_coveredWilayasCount Wilayas',
                          subtitle: _wilayasSummaryText,
                          icon: LucideIcons.mapPin,
                          color: const Color(0xFF8B5CF6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Mode Hors-Ligne',
                          value: 'Actif (SQLite)',
                          subtitle: 'Données protégées',
                          icon: LucideIcons.database,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'Actions Rapides sur le Terrain',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 12),

                  // Action Buttons Grid
                  _buildActionCard(
                    title: 'Enregistrer une Visite Médicale (Log Visit)',
                    subtitle: 'Tag GPS automatique, discussion produits & signature',
                    icon: LucideIcons.clipboardSignature,
                    color: const Color(0xFF0F766E),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const VisitLoggerScreen()),
                      );
                      _loadDashboardData();
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildActionCard(
                    title: 'Historique des Visites & Rapports',
                    subtitle: 'Filtrer par date, médecin et territoire / wilaya',
                    icon: LucideIcons.calendarClock,
                    color: const Color(0xFF0D9488),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const VisitsHistoryScreen()),
                      );
                      _loadDashboardData();
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildActionCard(
                    title: 'Répertoire Médecins & Cliniques (HCPs)',
                    subtitle: 'Rechercher par Wilaya, spécialité, appel direct & itinéraire',
                    icon: LucideIcons.users,
                    color: const Color(0xFF0284C7),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DoctorsScreen()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildActionCard(
                    title: 'Annuaire National GeoAlgeria',
                    subtitle: 'Rechercher hôpitaux, cliniques, pharmacies et industriels',
                    icon: LucideIcons.globe,
                    color: const Color(0xFF0F766E),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GeoAlgeriaDirectoryScreen()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildActionCard(
                    title: 'File de Synchronisation Hors-Ligne',
                    subtitle: "Visualiser les rapports stockés et forcer l'envoi cloud",
                    icon: LucideIcons.cloudUpload,
                    color: const Color(0xFF8B5CF6),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OfflineSyncScreen()),
                      );
                      _loadDashboardData();
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    final content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 22),
              if (onTap != null)
                const Icon(LucideIcons.chevronRight, size: 14, color: Color(0xFF94A3B8)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      );
    }
    return content;
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, color: Color(0xFF94A3B8), size: 18),
          ],
        ),
      ),
    );
  }
}
