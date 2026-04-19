import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:otoservis_app/models/vehicle.dart';
import 'package:otoservis_app/providers/vehicle_provider.dart';
import 'package:otoservis_app/utils/constants.dart';
import 'package:otoservis_app/utils/formatters.dart';
import 'package:otoservis_app/widgets/common/app_error_banner.dart';
import 'package:otoservis_app/widgets/common/app_sidebar.dart';
import 'package:otoservis_app/widgets/vehicle/add_vehicle_dialog.dart';
import 'package:otoservis_app/widgets/vehicle/edit_vehicle_dialog.dart';

class _VehicleListEntry {
  const _VehicleListEntry({
    required this.vehicle,
    required this.serviceCount,
    this.lastServiceDate,
  });

  final Vehicle vehicle;
  final int serviceCount;
  final DateTime? lastServiceDate;
}

class VehiclesListScreen extends StatefulWidget {
  const VehiclesListScreen({super.key});

  @override
  State<VehiclesListScreen> createState() => _VehiclesListScreenState();
}

class _VehiclesListScreenState extends State<VehiclesListScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _searchController = TextEditingController();

  List<_VehicleListEntry> _entries = [];
  String _searchQuery = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTime? _maxServiceDate(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    DateTime? last;
    for (final d in docs) {
      final raw = d.data()['date'];
      final dt = _asDateTime(raw);
      if (last == null || dt.isAfter(last)) last = dt;
    }
    return last;
  }

  DateTime _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final vehiclesSnap = await _firestore
          .collection(FirestoreCollections.vehicles)
          .orderBy('createdAt', descending: true)
          .get();

      if (!mounted) return;
      final vp = context.read<VehicleProvider>();
      final results = await Future.wait(
        vehiclesSnap.docs.map((doc) async {
          final data = doc.data();
          final plate = (data['plate'] as String?)?.trim().isNotEmpty == true
              ? (data['plate'] as String)
              : doc.id;
          final key = vp.normalizePlate(plate);
          final vehicle = Vehicle.fromMap({...data, 'plate': key});

          final services = await _firestore
              .collection(FirestoreCollections.serviceRecords)
              .where('vehiclePlate', isEqualTo: key)
              .get();

          return _VehicleListEntry(
            vehicle: vehicle,
            serviceCount: services.docs.length,
            lastServiceDate: services.docs.isEmpty
                ? null
                : _maxServiceDate(services.docs),
          );
        }),
      );

      if (!mounted) return;
      setState(() {
        _entries = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Veriler yüklenirken bir hata oluştu: $e';
        _loading = false;
      });
    }
  }

  List<_VehicleListEntry> _filtered(VehicleProvider vp) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _entries;

    return _entries.where((e) {
      final v = e.vehicle;
      final plate = vp.normalizePlate(v.plate).toLowerCase();
      final owner = v.ownerName.toLowerCase();
      final brand = v.brand.toLowerCase();
      final model = v.model.toLowerCase();
      final brandModel = '$brand $model'.trim();
      return plate.contains(q) ||
          owner.contains(q) ||
          brand.contains(q) ||
          model.contains(q) ||
          brandModel.contains(q);
    }).toList();
  }

  Future<void> _openEdit(Vehicle vehicle) async {
    final ok = await showEditVehicleDialog(context, vehicle);
    if (ok == true && mounted) await _load();
  }

  void _goHistory(VehicleProvider vp, Vehicle vehicle) {
    vp.setSelectedVehicle(vehicle);
    final plate = vp.normalizePlate(vehicle.plate);
    context.go('/vehicle/$plate/history');
  }

  void _goNewService(VehicleProvider vp, Vehicle vehicle) {
    vp.setSelectedVehicle(vehicle);
    context.go(
      '/service/new?plate=${Uri.encodeQueryComponent(vehicle.plate)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VehicleProvider>();
    final filtered = _filtered(vp);

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSidebar(),
          Expanded(
            child: ColoredBox(
              color: AppColors.surfaceMuted,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: () => context.go('/'),
                                tooltip: 'Ana sayfa',
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Araçlar',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: AppErrorBanner(
                              message: _error!,
                              onRetry: _load,
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (v) {
                                    setState(() => _searchQuery = v);
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Plaka, sahip, marka veya model ara…',
                                    prefixIcon: const Icon(Icons.search),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Material(
                                color: AppColors.primaryNavy,
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    '${filtered.length} araç',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _load,
                            child: _entries.isEmpty && _error != null
                                ? ListView(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    children: [
                                      SizedBox(
                                        height: 220,
                                        child: Center(
                                          child: Text(
                                            'Araç listesi alınamadı. Yukarıdan yeniden deneyin.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : _entries.isEmpty
                                    ? ListView(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        children: [
                                          SizedBox(
                                            height:
                                                MediaQuery.sizeOf(context).height *
                                                    0.45,
                                            child: Center(
                                              child: _EmptyAllVehicles(
                                                onAdd: () async {
                                                  final v =
                                                      await showAddVehicleDialog(
                                                    context,
                                                  );
                                                  if (v != null && mounted) {
                                                    await _load();
                                                    if (!context.mounted) return;
                                                    ScaffoldMessenger.of(context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          '${v.plate} plakalı araç kaydedildi.',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                : filtered.isEmpty
                                    ? ListView(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        children: [
                                          SizedBox(
                                            height: 200,
                                            child: Center(
                                              child: Text(
                                                'Arama kriterine uyan araç yok.',
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : LayoutBuilder(
                                        builder: (context, constraints) {
                                          final maxW = constraints.maxWidth;
                                          final pad = 24.0;
                                          final inner = maxW > 920
                                              ? (maxW - pad * 2 - 16) / 2
                                              : maxW - pad * 2;
                                          final cardW = inner.clamp(280.0, maxW);

                                          return ListView(
                                            padding: EdgeInsets.fromLTRB(
                                              pad,
                                              0,
                                              pad,
                                              24,
                                            ),
                                            children: [
                                              Wrap(
                                                spacing: 16,
                                                runSpacing: 16,
                                                children: filtered.map((e) {
                                                  return SizedBox(
                                                    width: cardW.toDouble(),
                                                    child: _VehicleCard(
                                                      entry: e,
                                                      vp: vp,
                                                      onEdit: () =>
                                                          _openEdit(e.vehicle),
                                                      onHistory: () =>
                                                          _goHistory(
                                                            vp,
                                                            e.vehicle,
                                                          ),
                                                      onNewService: () =>
                                                          _goNewService(
                                                            vp,
                                                            e.vehicle,
                                                          ),
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAllVehicles extends StatelessWidget {
  const _EmptyAllVehicles({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.directions_car_outlined,
          size: 72,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 16),
        Text(
          'Henüz araç kaydı yok',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('İlk Aracı Ekle'),
        ),
      ],
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.entry,
    required this.vp,
    required this.onEdit,
    required this.onHistory,
    required this.onNewService,
  });

  final _VehicleListEntry entry;
  final VehicleProvider vp;
  final VoidCallback onEdit;
  final VoidCallback onHistory;
  final VoidCallback onNewService;

  @override
  Widget build(BuildContext context) {
    final v = entry.vehicle;
    final plateDisplay = vp.formatPlateForDisplay(v.plate);
    final last = entry.lastServiceDate;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    plateDisplay,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Düzenle',
                  onPressed: onEdit,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              v.ownerName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${v.brand} ${v.model} · ${v.year}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.phone_outlined, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  v.ownerPhone,
                  style: TextStyle(color: Colors.grey.shade800, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.build_circle_outlined,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    last != null
                        ? 'Son servis: ${AppFormatters.formatDateLong(last)}'
                        : 'Henüz servis yok',
                    style: TextStyle(
                      fontSize: 13,
                      color: last != null ? Colors.black87 : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Toplam servis: ${entry.serviceCount}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onHistory,
                    child: const Text('Servis Geçmişi'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onNewService,
                    child: const Text('Yeni Servis'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
