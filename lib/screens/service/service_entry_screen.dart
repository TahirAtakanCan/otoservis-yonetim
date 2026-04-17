import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:otoservis_app/models/inventory_item.dart';
import 'package:otoservis_app/models/service_record.dart';
import 'package:otoservis_app/providers/auth_provider.dart';
import 'package:otoservis_app/providers/inventory_provider.dart';
import 'package:otoservis_app/providers/service_provider.dart';
import 'package:otoservis_app/providers/vehicle_provider.dart';
import 'package:otoservis_app/utils/constants.dart';
import 'package:otoservis_app/utils/formatters.dart';
import 'package:otoservis_app/widgets/common/app_error_banner.dart';

class ServiceEntryScreen extends StatefulWidget {
  const ServiceEntryScreen({
    super.key,
    this.initialPlate,
  });

  final String? initialPlate;

  @override
  State<ServiceEntryScreen> createState() => _ServiceEntryScreenState();
}

class _ServiceEntryScreenState extends State<ServiceEntryScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  final _plateController = TextEditingController();
  final _notesController = TextEditingController();
  Timer? _searchDebounce;

  final List<ServicePart> _parts = [];
  final List<LaborItem> _labor = [];

  bool _kdvIncluded = true;
  double _kdvRate = KdvRates.values.last;

  String? _inventorySearchError;

  static const double _leftWidth = 280;
  static const double _rightWidth = 200;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vp = context.read<VehicleProvider>();
      final initial = widget.initialPlate;
      if (initial != null && initial.isNotEmpty) {
        _plateController.text = vp.formatPlateForDisplay(vp.normalizePlate(initial));
        _plateController.selection = TextSelection.collapsed(
          offset: _plateController.text.length,
        );
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _plateController.dispose();
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
    qtyCtrl.dispose();

    if (ok == null || ok < 1) return;
    if (ok > item.quantity) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stokta yalnızca ${item.quantity} adet var.',
          ),
        ),
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

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Fiyat (₺)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Zorunlu';
                  final p = double.tryParse(v.trim().replaceAll(',', '.'));
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

    if (ok != true) {
      descCtrl.dispose();
      priceCtrl.dispose();
      return;
    }

    final price = double.parse(
      priceCtrl.text.trim().replaceAll(',', '.'),
    );
    setState(() {
      _labor.add(
        LaborItem(
          description: descCtrl.text.trim(),
          price: price,
        ),
      );
    });
    descCtrl.dispose();
    priceCtrl.dispose();
  }

  Future<void> _complete() async {
    final vp = context.read<VehicleProvider>();
    final auth = context.read<AuthProvider>();
    final svc = context.read<ServiceProvider>();

    final plate = _normalizedPlate(vp);
    if (plate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Araç plakası girin.')),
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

    final user = auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oturum bulunamadı.')),
      );
      return;
    }

    final techName =
        user.name.trim().isNotEmpty ? user.name : user.email;

    final st = _subtotal();
    final kdv = _kdvAmount();
    final grand = _grandTotal();

    final record = ServiceRecord(
      id: '',
      vehiclePlate: plate,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Servis kaydedilemedi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryProvider>();
    final svc = context.watch<ServiceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni servis girişi'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _plateController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Araç plakası',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _leftWidth,
                  child: _buildLeftPanel(inv),
                ),
                Expanded(
                  child: _buildCenterPanel(),
                ),
                SizedBox(
                  width: _rightWidth,
                  child: _buildRightPanel(
                    svc.isSaving,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftPanel(InventoryProvider inv) {
    return Material(
      color: AppColors.surfaceMuted,
      child: Padding(
        padding: const EdgeInsets.all(10),
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
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Parça adı ara (min. 2 karakter)',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                suffixIcon: inv.isSearching
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
              child: inv.lastSearchResults.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.trim().length < 2
                            ? 'Aramak için yazın.'
                            : 'Sonuç yok.',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView.separated(
                      itemCount: inv.lastSearchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final item = inv.lastSearchResults[i];
                        final disabled = item.quantity <= 0;
                        return ListTile(
                          dense: true,
                          enabled: !disabled,
                          title: Text(
                            item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            'Stok: ${item.quantity} · ${AppFormatters.formatLira(item.unitPrice)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: disabled ? Colors.red : null,
                            ),
                          ),
                          onTap: disabled
                              ? () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Stokta yok, bu parça seçilemez.',
                                      ),
                                    ),
                                  );
                                }
                              : () => _onPartTap(item),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Parçalar'),
            Tab(text: 'İşçilik'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPartsTable(),
              _buildLaborTable(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPartsTable() {
    if (_parts.isEmpty) {
      return const Center(
        child: Text(
          'Henüz parça eklenmedi.\nSoldan stokta arayın.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              headingRowHeight: 40,
              dataRowMinHeight: 40,
              columns: const [
                DataColumn(label: Text('Parça adı')),
                DataColumn(label: Text('Adet')),
                DataColumn(label: Text('Birim fiyat')),
                DataColumn(label: Text('Toplam')),
                DataColumn(label: Text('')),
              ],
              rows: _parts.asMap().entries.map((e) {
                final i = e.key;
                final p = e.value;
                return DataRow(
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
      padding: const EdgeInsets.all(8),
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
            child: _labor.isEmpty
                ? const Center(
                    child: Text(
                      'Henüz işçilik satırı yok.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                : Scrollbar(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowHeight: 40,
                          dataRowMinHeight: 40,
                          columns: const [
                            DataColumn(label: Text('İşlem açıklaması')),
                            DataColumn(label: Text('Fiyat')),
                            DataColumn(label: Text('')),
                          ],
                          rows: _labor.asMap().entries.map((e) {
                            final i = e.key;
                            final l = e.value;
                            return DataRow(
                              cells: [
                                DataCell(Text(l.description)),
                                DataCell(Text(AppFormatters.formatLira(l.price))),
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

  Widget _buildRightPanel(
    bool saving,
  ) {
    final auth = context.watch<AuthProvider>();
    final tech =
        auth.currentUser?.name.trim().isNotEmpty == true
            ? auth.currentUser!.name
            : (auth.currentUser?.email ?? '—');

    return Material(
      color: AppColors.secondaryOrange.withValues(alpha: 0.08),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Özet',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            _kv('Ara toplam', AppFormatters.formatLira(_subtotal())),
            const SizedBox(height: 8),
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
              value: _kdvRate,
              decoration: const InputDecoration(
                labelText: 'KDV oranı',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
              ),
              items: KdvRates.values
                  .map(
                    (r) => DropdownMenuItem<double>(
                      value: r,
                      child: Text(KdvRates.label(r)),
                    ),
                  )
                  .toList(),
              onChanged: _kdvIncluded
                  ? (v) => setState(() => _kdvRate = v ?? 0.2)
                  : null,
            ),
            const SizedBox(height: 8),
            _kv('KDV tutarı', AppFormatters.formatLira(_kdvAmount())),
            const Divider(height: 20),
            Text(
              'GENEL TOPLAM',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              AppFormatters.formatLira(_grandTotal()),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Teknisyen',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            Text(
              tech,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
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
            FilledButton(
              onPressed: saving ? null : _complete,
              child: saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Servisi tamamla'),
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
        Expanded(
          child: Text(
            k,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Text(
          v,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ],
    );
  }
}
