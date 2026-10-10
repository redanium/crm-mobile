import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/doctor.dart';
import '../models/visit.dart';
import '../services/api_service.dart';
import '../services/database_helper.dart';
import '../widgets/filterable_list_picker.dart';
import 'visit_logger_screen.dart';

class VisitsHistoryScreen extends StatefulWidget {
  final String? initialDoctorFilter;
  final String? initialWilayaFilter;

  const VisitsHistoryScreen({
    super.key,
    this.initialDoctorFilter,
    this.initialWilayaFilter,
  });

  @override
  State<VisitsHistoryScreen> createState() => _VisitsHistoryScreenState();
}

class _VisitsHistoryScreenState extends State<VisitsHistoryScreen> {
  List<Visit> _allVisits = [];
  List<Visit> _filteredVisits = [];
  List<Doctor> _cachedDoctors = [];
  bool _isLoading = true;

  // Filter States
  String _searchQuery = '';
  String? _selectedDoctorName;
  String? _selectedWilaya;
  DateTime? _selectedDate;
  String _datePreset = 'all'; // 'all', 'today', 'this_week', 'this_month', 'custom'

  final TextEditingController _searchCtrl = TextEditingController();

  // Catalog of standard Algerian Wilayas for picker
  final List<String> _wilayasList = [
    '01 · Adrar',
    '02 · Chlef',
    '03 · Laghouat',
    '04 · Oum El Bouaghi',
    '05 · Batna',
    '06 · Béjaïa',
    '07 · Biskra',
    '08 · Béchar',
    '09 · Blida',
    '10 · Bouira',
    '13 · Tlemcen',
    '15 · Tizi Ouzou',
    '16 · Alger',
    '19 · Sétif',
    '22 · Sidi Bel Abbès',
    '23 · Annaba',
    '25 · Constantine',
    '27 · Mostaganem',
    '29 · Mascara',
    '30 · Ouargla',
    '31 · Oran',
    '35 · Boumerdès',
    '42 · Tipaza',
    '44 · Aïn Defla',
    '48 · Relizane',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDoctorName = widget.initialDoctorFilter;
    _selectedWilaya = widget.initialWilayaFilter;
    _loadVisits();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVisits() async {
    setState(() => _isLoading = true);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final dbHelper = Provider.of<DatabaseHelper>(context, listen: false);

    // 1. Fetch cached doctors to help map wilayas
    try {
      _cachedDoctors = await dbHelper.getCachedDoctors();
    } catch (_) {}

    // 2. Fetch offline visits from local SQLite
    List<Visit> localVisits = [];
    try {
      localVisits = await dbHelper.getAllVisits();
    } catch (_) {}

    // 3. Attempt online sync/fetch
    try {
      final onlineVisits = await apiService.getVisits();
      if (onlineVisits.isNotEmpty) {
        await dbHelper.cacheVisits(onlineVisits);
      }

      // Merge local and online, avoiding duplicates by clientUuid or ID
      final Map<String, Visit> merged = {};

      // Add local visits first
      for (var v in localVisits) {
        final key = v.clientUuid ?? 'loc-${v.id ?? v.scheduledAt.toIso8601String()}';
        merged[key] = v;
      }

      // Add/overwrite with online visits
      for (var v in onlineVisits) {
        final key = v.clientUuid ?? 'srv-${v.id ?? v.scheduledAt.toIso8601String()}';
        merged[key] = v;
      }

      _allVisits = merged.values.toList()
        ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    } catch (_) {
      // Offline fallback: use local SQLite visits
      _allVisits = localVisits
        ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    }

    _enrichVisitsWithDoctorMetadata();
    _applyFilters();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Ensure every visit has a Wilaya and Facility if available in doctor catalog
  void _enrichVisitsWithDoctorMetadata() {
    for (int i = 0; i < _allVisits.length; i++) {
      final v = _allVisits[i];
      if (v.wilaya == null || v.wilaya!.isEmpty) {
        final doc = _cachedDoctors.where((d) => d.name.toLowerCase() == v.accountName.toLowerCase()).firstOrNull;
        if (doc != null) {
          _allVisits[i] = Visit(
            id: v.id,
            clientUuid: v.clientUuid,
            accountName: v.accountName,
            activityType: v.activityType,
            repName: v.repName,
            repId: v.repId,
            purpose: v.purpose,
            productsDiscussed: v.productsDiscussed,
            productQuantities: v.productQuantities,
            samplesDistributed: v.samplesDistributed,
            giftsDistributed: v.giftsDistributed,
            feedbackNotes: v.feedbackNotes,
            nextFollowupDate: v.nextFollowupDate,
            latitude: v.latitude ?? doc.latitude,
            longitude: v.longitude ?? doc.longitude,
            wilaya: doc.wilaya,
            facilityName: doc.organization,
            status: v.status,
            scheduledAt: v.scheduledAt,
          );
        }
      }
    }
  }

  void _applyFilters() {
    final query = _searchQuery.trim().toLowerCase();
    final now = DateTime.now();

    _filteredVisits = _allVisits.where((v) {
      // 1. Text Search (Doctor, Products, Purpose, Feedback)
      if (query.isNotEmpty) {
        final matchDoc = v.accountName.toLowerCase().contains(query);
        final matchProd = (v.productsDiscussed ?? '').toLowerCase().contains(query);
        final matchNotes = (v.feedbackNotes ?? '').toLowerCase().contains(query);
        final matchType = v.activityType.toLowerCase().contains(query);
        final matchWilaya = (v.wilaya ?? '').toLowerCase().contains(query);
        if (!matchDoc && !matchProd && !matchNotes && !matchType && !matchWilaya) {
          return false;
        }
      }

      // 2. Doctor Filter
      if (_selectedDoctorName != null && _selectedDoctorName!.isNotEmpty) {
        if (v.accountName.toLowerCase() != _selectedDoctorName!.toLowerCase()) {
          return false;
        }
      }

      // 3. Territory / Wilaya Filter
      if (_selectedWilaya != null && _selectedWilaya!.isNotEmpty) {
        final w = (v.wilaya ?? '').toLowerCase();
        final selectedW = _selectedWilaya!.toLowerCase();

        // Extract wilaya code if formatted e.g. "31 · Oran" or "Oran"
        final codeMatch = RegExp(r'\b\d{2}\b').firstMatch(selectedW);
        final code = codeMatch?.group(0);

        final matchesName = selectedW.split('·').any((part) => w.contains(part.trim()));
        final matchesCode = code != null && w.contains(code);

        if (!matchesName && !matchesCode) {
          return false;
        }
      }

      // 4. Date Filter
      final visitDate = DateTime(v.scheduledAt.year, v.scheduledAt.month, v.scheduledAt.day);
      final todayDate = DateTime(now.year, now.month, now.day);

      if (_datePreset == 'today') {
        if (!visitDate.isAtSameMomentAs(todayDate)) return false;
      } else if (_datePreset == 'this_week') {
        final weekAgo = todayDate.subtract(const Duration(days: 7));
        if (visitDate.isBefore(weekAgo) || visitDate.isAfter(todayDate.add(const Duration(days: 1)))) {
          return false;
        }
      } else if (_datePreset == 'this_month') {
        if (visitDate.year != now.year || visitDate.month != now.month) return false;
      } else if (_datePreset == 'custom' && _selectedDate != null) {
        final targetDate = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
        if (!visitDate.isAtSameMomentAs(targetDate)) return false;
      }

      return true;
    }).toList();
  }

  // --- Filter Dialogs & Pickers ---

  Future<void> _pickDoctorFilter() async {
    // Collect distinct doctors from existing visits and cached doctors
    final Map<String, String> doctorMap = {};
    for (var d in _cachedDoctors) {
      doctorMap[d.name] = '${d.specialty} · ${d.organization} · ${d.wilaya}';
    }
    for (var v in _allVisits) {
      if (!doctorMap.containsKey(v.accountName)) {
        doctorMap[v.accountName] = v.wilaya ?? 'Praticien visité';
      }
    }

    final items = doctorMap.entries.map((entry) {
      return FilterableItem(
        id: entry.key,
        title: entry.key,
        subtitle: entry.value,
        badge: 'HCP',
      );
    }).toList();

    final picked = await showFilterableListPicker(
      context: context,
      title: 'Filtrer par Médecin / Établissement',
      items: items,
      searchHint: 'Rechercher médecin, hôpital, clinique...',
      allowCustom: false,
    );

    if (picked != null) {
      setState(() {
        _selectedDoctorName = picked.title;
        _applyFilters();
      });
    }
  }

  Future<void> _pickWilayaFilter() async {
    final items = _wilayasList.map((w) {
      return FilterableItem(
        id: w,
        title: w,
        subtitle: 'Territoire de délégation médicale',
        badge: 'Wilaya',
      );
    }).toList();

    final picked = await showFilterableListPicker(
      context: context,
      title: 'Filtrer par Territoire / Wilaya',
      items: items,
      searchHint: 'Rechercher wilaya (ex. Oran, Alger, 31, 16)...',
      allowCustom: false,
    );

    if (picked != null) {
      setState(() {
        _selectedWilaya = picked.title;
        _applyFilters();
      });
    }
  }

  Future<void> _pickCustomDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime(2027, 12, 31),
      locale: const Locale('fr', 'DZ'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F766E),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _datePreset = 'custom';
        _applyFilters();
      });
    }
  }

  void _clearAllFilters() {
    setState(() {
      _searchQuery = '';
      _searchCtrl.clear();
      _selectedDoctorName = null;
      _selectedWilaya = null;
      _selectedDate = null;
      _datePreset = 'all';
      _applyFilters();
    });
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedDoctorName != null ||
      _selectedWilaya != null ||
      _datePreset != 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Historique des Visites',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 19),
            tooltip: 'Actualiser',
            onPressed: _loadVisits,
          ),
          if (_hasActiveFilters)
            IconButton(
              icon: const Icon(LucideIcons.filterX, size: 19, color: Color(0xFFDC2626)),
              tooltip: 'Réinitialiser les filtres',
              onPressed: _clearAllFilters,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)))
          : Column(
              children: [
                // Top Filter Header & Search Bar
                _buildSearchAndFiltersHeader(),

                // Active Filters Chips Row
                if (_hasActiveFilters) _buildActiveFilterChips(),

                // Count & Summary Banner
                _buildSummaryBar(),

                // Visits List
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadVisits,
                    color: const Color(0xFF0F766E),
                    child: _filteredVisits.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: _filteredVisits.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final visit = _filteredVisits[index];
                              return _buildVisitCard(visit);
                            },
                          ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F766E),
        icon: const Icon(LucideIcons.plus, color: Colors.white, size: 20),
        label: const Text('Nouvelle Visite', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const VisitLoggerScreen()),
          );
          _loadVisits();
        },
      ),
    );
  }

  Widget _buildSearchAndFiltersHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        children: [
          // Search input bar
          TextField(
            controller: _searchCtrl,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
                _applyFilters();
              });
            },
            decoration: InputDecoration(
              hintText: 'Rechercher médecin, produit, wilaya, note...',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(LucideIcons.search, size: 18, color: Color(0xFF0F766E)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(LucideIcons.x, size: 16),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {
                          _searchQuery = '';
                          _applyFilters();
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Horizontal Filter Selectors (Doctor, Territory, Date)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Doctor Filter Pill
                _buildFilterButton(
                  label: _selectedDoctorName != null ? 'Dr. ${_selectedDoctorName!}' : 'Médecin (Tous)',
                  icon: LucideIcons.userCheck,
                  isActive: _selectedDoctorName != null,
                  onTap: _pickDoctorFilter,
                ),
                const SizedBox(width: 8),

                // Territory / Wilaya Filter Pill
                _buildFilterButton(
                  label: _selectedWilaya != null ? _selectedWilaya! : 'Territoire (Tous)',
                  icon: LucideIcons.mapPin,
                  isActive: _selectedWilaya != null,
                  onTap: _pickWilayaFilter,
                ),
                const SizedBox(width: 8),

                // Date Presets Dropdown Pill
                _buildDateFilterMenu(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0F766E).withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF0F766E) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? const Color(0xFF0F766E) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? const Color(0xFF0F766E) : const Color(0xFF334155),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              LucideIcons.chevronDown,
              size: 13,
              color: isActive ? const Color(0xFF0F766E) : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilterMenu() {
    final bool isDateActive = _datePreset != 'all';
    String dateLabel = 'Date (Toutes)';
    if (_datePreset == 'today') dateLabel = "Aujourd'hui";
    if (_datePreset == 'this_week') dateLabel = '7 derniers jours';
    if (_datePreset == 'this_month') dateLabel = 'Ce mois-ci';
    if (_datePreset == 'custom' && _selectedDate != null) {
      dateLabel = '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';
    }

    return PopupMenuButton<String>(
      onSelected: (val) {
        if (val == 'custom') {
          _pickCustomDatePicker();
        } else {
          setState(() {
            _datePreset = val;
            _selectedDate = null;
            _applyFilters();
          });
        }
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'all', child: Text('Toutes les dates')),
        const PopupMenuItem(value: 'today', child: Text("Aujourd'hui")),
        const PopupMenuItem(value: 'this_week', child: Text('7 derniers jours')),
        const PopupMenuItem(value: 'this_month', child: Text('Ce mois-ci')),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'custom',
          child: Row(
            children: [
              Icon(LucideIcons.calendar, size: 16, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text('Choisir un jour spécifique...'),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isDateActive ? const Color(0xFF0F766E).withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDateActive ? const Color(0xFF0F766E) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.calendar,
              size: 14,
              color: isDateActive ? const Color(0xFF0F766E) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              dateLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isDateActive ? FontWeight.bold : FontWeight.w500,
                color: isDateActive ? const Color(0xFF0F766E) : const Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              LucideIcons.chevronDown,
              size: 13,
              color: isDateActive ? const Color(0xFF0F766E) : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilterChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text('Filtres actifs : ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            if (_selectedDoctorName != null)
              _buildFilterBadge('Dr. $_selectedDoctorName', () {
                setState(() {
                  _selectedDoctorName = null;
                  _applyFilters();
                });
              }),
            if (_selectedWilaya != null)
              _buildFilterBadge(_selectedWilaya!, () {
                setState(() {
                  _selectedWilaya = null;
                  _applyFilters();
                });
              }),
            if (_datePreset != 'all')
              _buildFilterBadge(
                _datePreset == 'today'
                    ? "Aujourd'hui"
                    : _datePreset == 'this_week'
                        ? '7 jours'
                        : _datePreset == 'this_month'
                            ? 'Ce mois'
                            : '${_selectedDate?.day}/${_selectedDate?.month}/${_selectedDate?.year}',
                () {
                  setState(() {
                    _datePreset = 'all';
                    _selectedDate = null;
                    _applyFilters();
                  });
                },
              ),
            TextButton(
              onPressed: _clearAllFilters,
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: const Text('Effacer tout', style: TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBadge(String text, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFCCFBF1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Icon(LucideIcons.x, size: 12, color: Color(0xFF0F766E)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFF8FAFC),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_filteredVisits.length} visite(s) répertoriée(s)',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
          ),
          Row(
            children: [
              _buildLegendDot(const Color(0xFF0F766E), 'Synchronisé'),
              const SizedBox(width: 10),
              _buildLegendDot(const Color(0xFFD97706), 'Hors-ligne'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildVisitCard(Visit visit) {
    final bool isOffline = visit.status == 'pending';
    final dateStr =
        '${visit.scheduledAt.day.toString().padLeft(2, '0')}/${visit.scheduledAt.month.toString().padLeft(2, '0')}/${visit.scheduledAt.year} · ${visit.scheduledAt.hour.toString().padLeft(2, '0')}:${visit.scheduledAt.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOffline ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Doctor name + Sync status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visit.accountName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                    ),
                    if (visit.facilityName != null && visit.facilityName!.isNotEmpty)
                      Text(
                        visit.facilityName!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isOffline ? const Color(0xFFFEF3C7) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isOffline ? const Color(0xFFFDE68A) : const Color(0xFFDCFCE7),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOffline ? LucideIcons.database : LucideIcons.checkCircle2,
                      size: 11,
                      color: isOffline ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isOffline ? 'En attente sync' : 'Validé',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isOffline ? const Color(0xFFB45309) : const Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Territory Wilaya & Date Meta
          Row(
            children: [
              if (visit.wilaya != null && visit.wilaya!.isNotEmpty) ...[
                const Icon(LucideIcons.mapPin, size: 13, color: Color(0xFF0F766E)),
                const SizedBox(width: 4),
                Text(
                  visit.wilaya!,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
                ),
                const SizedBox(width: 12),
              ],
              const Icon(LucideIcons.calendar, size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                dateStr,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),

          // Activity Type & Purpose
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.activity, size: 12, color: Color(0xFF64748B)),
                const SizedBox(width: 5),
                Text(
                  visit.activityType,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
              ],
            ),
          ),

          // Products Discussed
          if (visit.productsDiscussed != null && visit.productsDiscussed!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(LucideIcons.pill, size: 13, color: Color(0xFF0284C7)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Produits : ${visit.productsDiscussed!}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF0369A1), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ],

          // Samples & Goodies Given
          if (visit.samplesDistributed != null && visit.samplesDistributed!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(LucideIcons.package, size: 13, color: Color(0xFF8B5CF6)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Échantillons : ${visit.samplesDistributed!}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF6D28D9)),
                  ),
                ),
              ],
            ),
          ],

          // Clinical Feedback & Notes
          if (visit.feedbackNotes != null && visit.feedbackNotes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Note : ${visit.feedbackNotes!}',
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
              ),
            ),
          ],

          // Footer info: Délégué + GPS coordinates
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Délégué : ${visit.repName}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
              if (visit.latitude != null && visit.longitude != null)
                Text(
                  'GPS : ${visit.latitude!.toStringAsFixed(3)}, ${visit.longitude!.toStringAsFixed(3)}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontFamily: 'monospace'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.calendarX2, size: 40, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucune visite trouvée',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            Text(
              _hasActiveFilters
                  ? 'Aucun rapport de visite ne correspond à vos critères de filtrage.'
                  : 'Vous n’avez encore enregistré aucune visite de délégation médicale.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            if (_hasActiveFilters) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _clearAllFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(LucideIcons.filterX, size: 16),
                label: const Text('Réinitialiser les filtres'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
