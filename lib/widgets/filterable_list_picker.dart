import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class FilterableItem {
  final String id;
  final String title;
  final String? subtitle;
  final String? badge;

  FilterableItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.badge,
  });
}

/// A reusable bottom sheet modal for picking a single item from a filterable list
Future<FilterableItem?> showFilterableListPicker({
  required BuildContext context,
  required String title,
  required List<FilterableItem> items,
  String? searchHint,
  String? selectedId,
  bool allowCustom = false,
}) {
  return showModalBottomSheet<FilterableItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _FilterablePickerSheet(
      title: title,
      items: items,
      searchHint: searchHint ?? 'Rechercher...',
      selectedId: selectedId,
      allowCustom: allowCustom,
    ),
  );
}

/// A reusable bottom sheet modal for picking multiple items with search & badges
Future<List<FilterableItem>?> showMultiFilterableListPicker({
  required BuildContext context,
  required String title,
  required List<FilterableItem> items,
  String? searchHint,
  List<String> selectedIds = const [],
  bool allowCustom = false,
}) {
  return showModalBottomSheet<List<FilterableItem>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _MultiFilterablePickerSheet(
      title: title,
      items: items,
      searchHint: searchHint ?? 'Rechercher des éléments...',
      initialSelectedIds: selectedIds,
      allowCustom: allowCustom,
    ),
  );
}

class _FilterablePickerSheet extends StatefulWidget {
  final String title;
  final List<FilterableItem> items;
  final String searchHint;
  final String? selectedId;
  final bool allowCustom;

  const _FilterablePickerSheet({
    required this.title,
    required this.items,
    required this.searchHint,
    this.selectedId,
    this.allowCustom = false,
  });

  @override
  State<_FilterablePickerSheet> createState() => _FilterablePickerSheetState();
}

class _FilterablePickerSheetState extends State<_FilterablePickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<FilterableItem> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items.where((item) {
          final matchesTitle = item.title.toLowerCase().contains(q);
          final matchesSub = item.subtitle?.toLowerCase().contains(q) ?? false;
          final matchesBadge = item.badge?.toLowerCase().contains(q) ?? false;
          return matchesTitle || matchesSub || matchesBadge;
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75 + bottomInset * 0.5,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 16),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Items List
          Expanded(
            child: _filteredItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.searchX, size: 36, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 8),
                          const Text(
                            'Aucun résultat correspondant',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                          ),
                          if (widget.allowCustom && _searchCtrl.text.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F766E),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                final customText = _searchCtrl.text.trim();
                                Navigator.pop(
                                  context,
                                  FilterableItem(id: customText, title: customText, subtitle: 'Saisie personnalisée'),
                                );
                              },
                              icon: const Icon(LucideIcons.plus, size: 16),
                              label: Text('Utiliser "${_searchCtrl.text.trim()}"'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filteredItems.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      final isSelected = item.id == widget.selectedId;

                      return InkWell(
                        onTap: () => Navigator.pop(context, item),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFF0FDFA) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            item.title,
                                            style: TextStyle(
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                              fontSize: 14,
                                              color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF1E293B),
                                            ),
                                          ),
                                        ),
                                        if (item.badge != null) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                            ),
                                            child: Text(
                                              item.badge!,
                                              style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (item.subtitle != null) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        item.subtitle!,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(LucideIcons.check, size: 18, color: Color(0xFF0F766E)),
                            ],
                          ),
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

class _MultiFilterablePickerSheet extends StatefulWidget {
  final String title;
  final List<FilterableItem> items;
  final String searchHint;
  final List<String> initialSelectedIds;
  final bool allowCustom;

  const _MultiFilterablePickerSheet({
    required this.title,
    required this.items,
    required this.searchHint,
    required this.initialSelectedIds,
    this.allowCustom = false,
  });

  @override
  State<_MultiFilterablePickerSheet> createState() => _MultiFilterablePickerSheetState();
}

class _MultiFilterablePickerSheetState extends State<_MultiFilterablePickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<FilterableItem> _filteredItems = [];
  late List<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.initialSelectedIds);
    _filteredItems = widget.items;
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items.where((item) {
          final matchesTitle = item.title.toLowerCase().contains(q);
          final matchesSub = item.subtitle?.toLowerCase().contains(q) ?? false;
          final matchesBadge = item.badge?.toLowerCase().contains(q) ?? false;
          return matchesTitle || matchesSub || matchesBadge;
        }).toList();
      }
    });
  }

  void _toggleItem(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8 + bottomInset * 0.5,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final selectedList = widget.items.where((i) => _selectedIds.contains(i.id)).toList();
                    Navigator.pop(context, selectedList);
                  },
                  child: const Text('Valider', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 16),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Items List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filteredItems.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                final isSelected = _selectedIds.contains(item.id);

                return InkWell(
                  onTap: () => _toggleItem(item.id),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFF0FDFA) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isSelected,
                          activeColor: const Color(0xFF0F766E),
                          onChanged: (_) => _toggleItem(item.id),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      item.title,
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        fontSize: 14,
                                        color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                  if (item.badge != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Text(
                                        item.badge!,
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (item.subtitle != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  item.subtitle!,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Bottom selection bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              color: Color(0xFFF8FAFC),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selectedIds.length} sélectionné(s)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final selectedList = widget.items.where((i) => _selectedIds.contains(i.id)).toList();
                    Navigator.pop(context, selectedList);
                  },
                  child: const Text('Confirmer la sélection', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
