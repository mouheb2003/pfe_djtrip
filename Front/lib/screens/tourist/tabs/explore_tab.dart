import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/lieu_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/lieu_service.dart';
import '../../../theme/app_theme.dart';
import '../lieux_map_screen.dart';
import '../place_detail_screen.dart';

class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  bool _isLoading = true;
  bool _topDestinationOnly = false;
  String? _selectedCategory; // Beaches | Museums | Villages | Nature | Other
  List<LieuModel> _lieux = [];
  String? _avatarUrl;

  static const List<Map<String, String?>> _categories = [
    {'label': 'All', 'value': null},
    {'label': 'Beaches', 'value': 'Beaches'},
    {'label': 'Museums', 'value': 'Museums'},
    {'label': 'Villages', 'value': 'Villages'},
    {'label': 'Nature', 'value': 'Nature'},
    {'label': 'Other', 'value': 'Other'},
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _loadCurrentUser();
    _loadLieux();
  }

  @override
  void reassemble() {
    super.reassemble();
    // In debug, hot reload keeps State. Force a fresh fetch.
    _loadLieux();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _loadLieux);
  }

  Future<void> _loadLieux() async {
    setState(() => _isLoading = true);
    final data = await LieuService.getLieux(
      search: _searchCtrl.text,
      categorie: _selectedCategory,
      topDestination: _topDestinationOnly ? true : null,
    );
    if (!mounted) return;
    setState(() {
      _lieux = data;
      _isLoading = false;
    });
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService.getUser();
    if (!mounted || user == null) return;
    final avatar = (user['avatar'] as String?)?.trim();
    setState(() => _avatarUrl = (avatar?.isNotEmpty == true) ? avatar : null);
  }

  List<LieuModel> get _incontournables {
    final tops = _lieux.where((l) => l.topDestination).toList();
    if (tops.isNotEmpty) return tops;
    return _lieux.take(6).toList();
  }

  Map<String, dynamic> _toPlaceMap(LieuModel l) {
    return {
      '_id': l.id,
      'title': l.titre,
      'subtitle': l.sousTitre,
      'description': l.description,
      'image': l.displayImage,
      'images': l.images,
      'rating': l.noteMoyenne.toStringAsFixed(1),
      'nombreAvis': l.nombreAvis,
      'top_destination': l.topDestination,
      'activity_id': l.activiteLieeId,
      'coordonnees': {'latitude': l.latitude, 'longitude': l.longitude},
      'price': l.prix,
      'categorie': l.categorie,
    };
  }

  Future<void> _openMapPicker({LieuModel? initialLieu}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LieuxMapScreen(
          lieux: _lieux,
          initialLieuId: initialLieu?.id,
        ),
      ),
    );
  }

  void _openFilters() {
    String? tempCategory = _selectedCategory;
    bool tempTopOnly = _topDestinationOnly;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Top destination only'),
                    value: tempTopOnly,
                    onChanged: (v) => setModalState(() => tempTopOnly = v),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Category',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((c) {
                      final selected = tempCategory == c['value'];
                      return ChoiceChip(
                        label: Text(c['label']!),
                        selected: selected,
                        showCheckmark: false,
                        selectedColor: AppColors.primary.withOpacity(0.14),
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceVariant,
                        side: BorderSide(
                          color: selected
                              ? AppColors.primary
                              : Theme.of(context).colorScheme.outline,
                        ),
                        labelStyle: TextStyle(
                          color: selected
                              ? AppColors.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                        onSelected: (_) =>
                            setModalState(() => tempCategory = c['value']),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedCategory = null;
                              _topDestinationOnly = false;
                            });
                            Navigator.pop(context);
                            _loadLieux();
                          },
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedCategory = tempCategory;
                              _topDestinationOnly = tempTopOnly;
                            });
                            Navigator.pop(context);
                            _loadLieux();
                          },
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadLieux,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, topInset + 10, 16, 96),
          children: [
            Row(
              children: [
                const Icon(Icons.explore, color: AppColors.primary),
                const SizedBox(width: 10),
                const Text(
                  'DJTrip',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                _iconCircle(Icons.notifications_none),
                const SizedBox(width: 8),
                _avatarCircle(),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                    hintText: 'Search for a place...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                    fillColor: cs.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(26),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: _openFilters,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                    child: const Icon(Icons.tune, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _categories.map((c) {
                  final selected = _selectedCategory == c['value'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c['label']!),
                      selected: selected,
                      showCheckmark: false,
                      selectedColor: AppColors.primary.withOpacity(0.16),
                          backgroundColor: cs.surfaceVariant,
                      side: BorderSide(
                        color: selected
                            ? AppColors.primary
                                : cs.outline,
                      ),
                      labelStyle: TextStyle(
                        color: selected
                            ? AppColors.primary
                                : cs.onSurfaceVariant,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      onSelected: (_) {
                        setState(() => _selectedCategory = c['value']);
                        _loadLieux();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Must-see',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Discover the best places in Djerba',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 14),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text(
                        'Loading places...',
                      ),
                    ],
                  ),
                ),
              )
            else if (_lieux.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 28,
                ),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outline),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.travel_explore, size: 40, color: AppColors.primary),
                    SizedBox(height: 10),
                    Text(
                      'No places available',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Add places to the database to show them here.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else ...[
              ..._incontournables.map(
                (l) => Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: _LieuCard(
                    lieu: l,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlaceDetailScreen(place: _toPlaceMap(l)),
                      ),
                    ),
                    onMapTap: () => _openMapPicker(initialLieu: l),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'All places',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ..._lieux.map(
                (l) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    tileColor: cs.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: cs.outline),
                    ),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: l.displayImage.isEmpty
                            ? Container(color: cs.surfaceVariant)
                            : Image.network(
                                l.displayImage,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Container(color: cs.surfaceVariant),
                              ),
                      ),
                    ),
                    title: Text(
                      l.titre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${l.categoryLabelEn} • ${l.noteMoyenne.toStringAsFixed(1)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.map_outlined),
                      onPressed: () => _openMapPicker(initialLieu: l),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlaceDetailScreen(place: _toPlaceMap(l)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openMapPicker(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.map),
      ),
    );
  }

  Widget _iconCircle(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFF1F5F9),
      ),
      child: Icon(icon, color: const Color(0xFF475569)),
    );
  }

  Widget _avatarCircle() {
    if (_avatarUrl != null) {
      return SizedBox(
        width: 44,
        height: 44,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFF1F5F9),
          ),
          child: ClipOval(
            child: Image.network(
              _avatarUrl!,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.person_outline,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ),
      );
    }
    return _iconCircle(Icons.person_outline);
  }
}

class _LieuCard extends StatelessWidget {
  final LieuModel lieu;
  final VoidCallback onTap;
  final VoidCallback onMapTap;

  const _LieuCard({
    required this.lieu,
    required this.onTap,
    required this.onMapTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outline),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 220,
              width: double.infinity,
              child: lieu.displayImage.isEmpty
                  ? Container(color: cs.surfaceVariant)
                  : Image.network(
                      lieu.displayImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: cs.surfaceVariant),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (lieu.topDestination)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'TOP DESTINATION',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 14,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              lieu.noteMoyenne.toStringAsFixed(1),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    lieu.titre,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lieu.sousTitre.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lieu.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.bolt,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Category: ${lieu.categoryLabelEn}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: onMapTap,
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                          child: const Icon(Icons.map, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

