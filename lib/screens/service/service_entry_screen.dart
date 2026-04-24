import 'dart:async';
import 'package:flutter/scheduler.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:otoservis_app/models/inventory_item.dart';
import 'package:otoservis_app/models/service_record.dart';
import 'package:otoservis_app/providers/auth_provider.dart';
import 'package:otoservis_app/providers/connectivity_notifier.dart';
import 'package:otoservis_app/providers/inventory_provider.dart';
import 'package:otoservis_app/providers/service_provider.dart';
import 'package:otoservis_app/providers/vehicle_provider.dart';
import 'package:otoservis_app/utils/constants.dart';
import 'package:otoservis_app/utils/formatters.dart';
import 'package:otoservis_app/widgets/common/app_error_banner.dart';

class ServiceEntryScreen extends StatefulWidget {
  const ServiceEntryScreen({super.key, this.initialPlate});

  final String? initialPlate;

  @override
  State<ServiceEntryScreen> createState() => _ServiceEntryScreenState();
}

class _ServiceEntryScreenState extends State<ServiceEntryScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  final _plateController = TextEditingController();
  final _vehicleKmController = TextEditingController();
  final _technicianController = TextEditingController();
  final _notesController = TextEditingController();
  Timer? _searchDebounce;

  final List<ServicePart> _parts = [];
  final List<LaborItem> _labor = [];

  bool _kdvIncluded = true;
  double _kdvRate = KdvRates.values.last;

  String? _inventorySearchError;
  bool _resolvingVehicle = true;
  String? _vehicleGateError;

  static const double _leftWidth = 280;
  static const double _rightWidth = 200;
  static const double _panelRadius = 16;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final vp = context.read<VehicleProvider>();
    final auth = context.read<AuthProvider>();

    final user = auth.currentUser;
    _technicianController.text =
        (user?.name.trim().isNotEmpty ?? false)
            ? user!.name
            : (user?.email ?? '');

    final initialRaw = widget.initialPlate ?? '';
    final normalizedPlate = vp.normalizePlate(initialRaw);
    if (normalizedPlate.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Servis başlatmak için önce kayıtlı araç seçin.'),
        ),
      );
      context.go('/vehicles');
      return;
    }

    try {
      final selected = vp.selectedVehicle;
      final vehicle =
          selected != null &&
                  vp.normalizePlate(selected.plate) == normalizedPlate
              ? selected
              : await vp.fetchVehicleByPlate(normalizedPlate);

      if (!mounted) return;
      if (vehicle == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Araç bulunamadı. Önce araç kaydı oluşturun.'),
          ),
        );
        context.go('/vehicles/new?plate=$normalizedPlate');
        return;
      }

      vp.setSelectedVehicle(vehicle);
      _plateController.text = vp.formatPlateForDisplay(vehicle.plate);
      _plateController.selection = TextSelection.collapsed(
        offset: _plateController.text.length,
      );
      _vehicleKmController.text = vehicle.currentKm > 0
          ? '${vehicle.currentKm}'
          : '';

      setState(() {
        _resolvingVehicle = false;
        _vehicleGateError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _vehicleGateError = 'Araç bilgisi doğrulanamadı: $e';
        _resolvingVehicle = false;
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _plateController.dispose();
    _vehicleKmController.dispose();
    _technicianController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _normalizedPlate(VehicleProvider vp) {
    return vp.normalizePlate(_plateController.text);
  }

  double _partsTotal() {
    return _parts.fold(0.0, (s, p) => s + p.totalPrice);
  }

  double _laborTotal() {
    return _labor.fold(0.0, (s, l) => s + l.price);
  }

  double _subtotal() {
    return _partsTotal() + _laborTotal();
  }

  double _kdvAmount() {
    if (!_kdvIncluded) return 0;
    final st = _subtotal();
    return double.parse((st * _kdvRate).toStringAsFixed(2));
  }

  double _grandTotal() {
    return double.parse((_subtotal() + _kdvAmount()).toStringAsFixed(2));
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      final inv = context.read<InventoryProvider>();
      try {
        await inv.searchParts(value);
        if (mounted) setState(() => _inventorySearchError = null);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _inventorySearchError =
              'Parça araması yapılamadı. Bağlantınızı kontrol edin. ($e)';
        });
      }
    });
  }

  Future<void> _onPartTap(InventoryItem item) async {
    if (item.quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu parça stokta yok, seçilemez.')),
      );
      return;
    }

    final qtyCtrl = TextEditingController(text: '1');
    final ok = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(item.name),
          content: TextField(
            controller: qtyCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Adet',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () {
                final n = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                Navigator.pop(ctx, n);
              },
              child: const Text('Ekle'),
            ),
          ],
        );
      },
    );
    SchedulerBinding.instance.addPostFrameCallback((_) {
      qtyCtrl.dispose();
    });

    if (ok == null || ok < 1) return;
    if (ok > item.quantity) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stokta yalnızca ${item.quantity} adet var.')),
      );
      return;
    }

    final existingIdx = _parts.indexWhere((p) => p.partId == item.id);
    if (existingIdx >= 0) {
      final ex = _parts[existingIdx];
      final newQty = ex.quantity + ok;
      if (newQty > item.quantity) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Toplam adet stok üst sınırını (${item.quantity}) aşamaz.',
            ),
          ),
        );
        return;
      }
    }

    setState(() {
      final idx = _parts.indexWhere((p) => p.partId == item.id);
      if (idx >= 0) {
        final ex = _parts[idx];
        final newQty = ex.quantity + ok;
        _parts[idx] = ex.copyWith(
          quantity: newQty,
          totalPrice: newQty * ex.unitPrice,
        );
      } else {
        _parts.add(
          ServicePart(
            partId: item.id,
            partName: item.name,
            quantity: ok,
            unitPrice: item.unitPrice,
            totalPrice: ok * item.unitPrice,
          ),
        );
      }
    });
  }

  Future<void> _addLaborRow() async {
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('İşçilik satırı'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'İşlem açıklaması',
                        border: OutlineInputBorder(),
                      ),
                      validator:
                          (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Zorunlu'
                                  : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Fiyat (₺)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Zorunlu';
                        final p = double.tryParse(
                          v.trim().replaceAll(',', '.'),
                        );
                        if (p == null || p < 0) return 'Geçerli fiyat girin';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('İptal'),
                ),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.pop(ctx, true);
                    }
                  },
                  child: const Text('Ekle'),
                ),
              ],
            ),
      );

      if (ok != true) return;

      final price = double.parse(priceCtrl.text.trim().replaceAll(',', '.'));
      setState(() {
        _labor.add(LaborItem(description: descCtrl.text.trim(), price: price));
      });
    } finally {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        descCtrl.dispose();
        priceCtrl.dispose();
      });
    }
  }

  Future<void> _complete() async {
    final vp = context.read<VehicleProvider>();
    final auth = context.read<AuthProvider>();
    final svc = context.read<ServiceProvider>();

    final plate = _normalizedPlate(vp);
    if (plate.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Araç plakası girin.')));
      return;
    }

    final selected = vp.selectedVehicle;
    if (selected == null || vp.normalizePlate(selected.plate) != plate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Servise devam etmek için kayıtlı bir araç seçin.'),
        ),
      );
      return;
    }

    if (_parts.isEmpty && _labor.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('En az bir parça veya işçilik satırı ekleyin.'),
        ),
      );
      return;
    }

    if (_labor.any((l) => l.description.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İşçilik açıklamaları boş olamaz.')),
      );
      return;
    }

    final serviceKm = int.tryParse(_vehicleKmController.text.trim());
    if (serviceKm == null || serviceKm < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servis için geçerli KM girin.')),
      );
      return;
    }

    if (!context.read<ConnectivityNotifier>().isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Stok düşümü ve güvenli servis kaydı için internet gerekir. '
            'Bağlantı gelince tekrar deneyin.',
          ),
        ),
      );
      return;
    }

    final user = auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Oturum bulunamadı.')));
      return;
    }

    final techName =
        _technicianController.text.trim().isNotEmpty
            ? _technicianController.text.trim()
            : (user.name.trim().isNotEmpty ? user.name : user.email);

    final st = _subtotal();
    final kdv = _kdvAmount();
    final grand = _grandTotal();

    final record = ServiceRecord(
      id: '',
      vehiclePlate: plate,
      vehicleKm: serviceKm,
      technicianId: user.uid,
      technicianName: techName,
      date: DateTime.now(),
      parts: List<ServicePart>.from(_parts),
      laborItems: List<LaborItem>.from(_labor),
      subtotal: double.parse(st.toStringAsFixed(2)),
      kdvIncluded: _kdvIncluded,
      kdvRate: _kdvRate,
      kdvAmount: kdv,
      grandTotal: grand,
      notes: _notesController.text.trim(),
      status: 'completed',
    );

    try {
      final id = await svc.completeServiceAndDeductStock(record: record);
      if (!mounted) return;
      context.go('/pdf/preview/$id');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Servis kaydedilemedi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryProvider>();
    final svc = context.watch<ServiceProvider>();
    final online = context.watch<ConnectivityNotifier>().isOnline;

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/vehicles');
            }
          },
        ),
        title: const Text('Yeni servis girişi'),
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child:
            _resolvingVehicle
                ? const Center(child: CircularProgressIndicator())
                : _vehicleGateError != null
                ? Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppErrorBanner(
                            message: _vehicleGateError!,
                            onRetry: _bootstrap,
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => context.go('/vehicles'),
                            child: const Text('Araç listesine dön'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                : Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(_panelRadius),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x15000000),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Icon(
                                Icons.directions_car_filled_outlined,
                                color: AppColors.primaryNavy,
                              ),
                              const SizedBox(width: 10),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 200,
                                ),
                                child: TextField(
                                  controller: _plateController,
                                  readOnly: true,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  decoration: const InputDecoration(
                                    labelText: 'Araç plakası',
                                    hintText: 'Örn: 34 ABC 123',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _vehicleKmController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(8),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Araç KM (bu servis)',
                                    hintText: 'Örn: 128500',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: _leftWidth,
                              child: _buildLeftPanel(inv),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: _buildCenterPanel()),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: _rightWidth,
                              child: _buildRightPanel(saving: svc.isSaving, online: online),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildLeftPanel(InventoryProvider inv) {
    final showAll = _searchController.text.trim().length < 2;
    final visibleItems = showAll ? inv.allItems : inv.lastSearchResults;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_panelRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_inventorySearchError != null) ...[
              AppErrorBanner(
                message: _inventorySearchError!,
                onRetry: () {
                  setState(() => _inventorySearchError = null);
                  _onSearchChanged(_searchController.text);
                },
              ),
              const SizedBox(height: 8),
            ],
            Text(
              'Stoktan parça',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Parça adı ara',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                suffixIcon:
                    inv.isSearching
                        ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                        : const Icon(Icons.search),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 10),
            Expanded(
              child:
                  inv.inventoryLoading && showAll
                      ? const Center(child: CircularProgressIndicator())
                      : visibleItems.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.manage_search_outlined,
                              color: Colors.grey.shade500,
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              showAll
                                  ? 'Stokta görüntülenecek parça bulunamadı.'
                                  : 'Aramaya uygun parça bulunamadı.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      )
                      : ListView.separated(
                        itemCount: visibleItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, i) {
                          final item = visibleItems[i];
                          final disabled = item.quantity <= 0;
                          return Material(
                            color:
                                disabled
                                    ? Colors.red.shade50
                                    : Colors.blueGrey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            child: ListTile(
                              dense: true,
                              enabled: !disabled,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              title: Text(
                                item.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                'Stok: ${item.quantity} · ${AppFormatters.formatLira(item.unitPrice)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: disabled ? Colors.red.shade700 : null,
                                ),
                              ),
                              trailing: Icon(
                                disabled
                                    ? Icons.block_outlined
                                    : Icons.add_circle_outline,
                                color:
                                    disabled
                                        ? Colors.red.shade700
                                        : AppColors.primaryNavy,
                                size: 20,
                              ),
                              onTap:
                                  disabled
                                      ? () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Stokta yok, bu parça seçilemez.',
                                            ),
                                          ),
                                        );
                                      }
                                      : () => _onPartTap(item),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterPanel() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_panelRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ColoredBox(
                color: AppColors.surfaceMuted,
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primaryNavy,
                  unselectedLabelColor: Colors.black54,
                  indicatorColor: AppColors.primaryNavy,
                  tabs: const [Tab(text: 'Parçalar'), Tab(text: 'İşçilik')],
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildPartsTable(), _buildLaborTable()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartsTable() {
    if (_parts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.inventory_2_outlined, size: 32, color: Colors.black45),
            SizedBox(height: 8),
            Text(
              'Henüz parça eklenmedi.\nSoldan stokta arayın.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              headingRowHeight: 40,
              dataRowMinHeight: 40,
              headingRowColor: WidgetStatePropertyAll(
                AppColors.primaryNavy.withValues(alpha: 0.1),
              ),
              columns: const [
                DataColumn(label: Text('Parça adı')),
                DataColumn(label: Text('Adet')),
                DataColumn(label: Text('Birim fiyat')),
                DataColumn(label: Text('Toplam')),
                DataColumn(label: Text('')),
              ],
              rows:
                  _parts.asMap().entries.map((e) {
                    final i = e.key;
                    final p = e.value;
                    return DataRow(
                      color: WidgetStatePropertyAll(
                        i.isEven
                            ? Colors.white
                            : AppColors.surfaceMuted.withValues(alpha: 0.7),
                      ),
                      cells: [
                        DataCell(Text(p.partName)),
                        DataCell(Text('${p.quantity}')),
                        DataCell(Text(AppFormatters.formatLira(p.unitPrice))),
                        DataCell(Text(AppFormatters.formatLira(p.totalPrice))),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () {
                              setState(() => _parts.removeAt(i));
                            },
                          ),
                        ),
                      ],
                    );
                  }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLaborTable() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: _addLaborRow,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Yeni satır ekle'),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child:
                _labor.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.design_services_outlined,
                            size: 32,
                            color: Colors.black45,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Henüz işçilik satırı yok.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    )
                    : Scrollbar(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowHeight: 40,
                            dataRowMinHeight: 40,
                            headingRowColor: WidgetStatePropertyAll(
                              AppColors.primaryNavy.withValues(alpha: 0.1),
                            ),
                            columns: const [
                              DataColumn(label: Text('İşlem açıklaması')),
                              DataColumn(label: Text('Fiyat')),
                              DataColumn(label: Text('')),
                            ],
                            rows:
                                _labor.asMap().entries.map((e) {
                                  final i = e.key;
                                  final l = e.value;
                                  return DataRow(
                                    color: WidgetStatePropertyAll(
                                      i.isEven
                                          ? Colors.white
                                          : AppColors.surfaceMuted.withValues(
                                            alpha: 0.7,
                                          ),
                                    ),
                                    cells: [
                                      DataCell(Text(l.description)),
                                      DataCell(
                                        Text(AppFormatters.formatLira(l.price)),
                                      ),
                                      DataCell(
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            setState(() => _labor.removeAt(i));
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                          ),
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanel({required bool saving, required bool online}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_panelRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Özet',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 10),
            _kv('Ara toplam', AppFormatters.formatLira(_subtotal())),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'KDV',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Switch(
                  value: _kdvIncluded,
                  onChanged: (v) => setState(() => _kdvIncluded = v),
                ),
              ],
            ),
            DropdownButtonFormField<double>(
              initialValue: _kdvRate,
              decoration: const InputDecoration(
                labelText: 'KDV oranı',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
              ),
              items:
                  KdvRates.values
                      .map(
                        (r) => DropdownMenuItem<double>(
                          value: r,
                          child: Text(KdvRates.label(r)),
                        ),
                      )
                      .toList(),
              onChanged:
                  _kdvIncluded
                      ? (v) => setState(() => _kdvRate = v ?? 0.2)
                      : null,
            ),
            const SizedBox(height: 8),
            _kv('KDV tutarı', AppFormatters.formatLira(_kdvAmount())),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primaryNavy,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GENEL TOPLAM',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppFormatters.formatLira(_grandTotal()),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Teknisyen', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            TextField(
              controller: _technicianController,
              maxLines: 1,
              decoration: const InputDecoration(
                hintText: 'Servisi yapan kişi',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notlar',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: (saving || !online) ? null : _complete,
              icon: const Icon(Icons.check_circle_outline),
              label:
                  saving
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : Text(
                        online
                            ? 'Servisi tamamla'
                            : 'Servisi tamamla (internet gerekir)',
                      ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(k, style: Theme.of(context).textTheme.bodySmall)),
        Text(
          v,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ],
    );
  }
}
