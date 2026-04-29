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
  final _newIssueController = TextEditingController();
  Timer? _searchDebounce;

  final List<ServicePart> _parts = [];
  final List<LaborItem> _labor = [];
  final List<Map<String, dynamic>> _newIssueNotes = [];

  final _stockSearchFocus = FocusNode();

  bool _kdvIncluded = true;
  double _kdvRate = KdvRates.values.last;

  String? _inventorySearchError;
  bool _resolvingVehicle = true;
  String? _vehicleGateError;

  static const double _leftWidth = 300;
  static const double _rightWidth = 230;
  static const double _panelRadius = 18;

  static const Color _pageBg = Color(0xFFF0F2F5);
  static const Color _cardLine = Color(0xFFE2E8F0);
  static const List<BoxShadow> _cardShadow = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 20, offset: Offset(0, 4)),
  ];

  BoxDecoration _panelShell({Color? color}) {
    return BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(_panelRadius),
      border: Border.all(color: _cardLine, width: 1),
      boxShadow: _cardShadow,
    );
  }

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
      _vehicleKmController.text =
          vehicle.currentKm > 0 ? '${vehicle.currentKm}' : '';

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
    _newIssueController.dispose();
    _stockSearchFocus.dispose();
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

  void _addIssueNote() {
    final text = _newIssueController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _newIssueNotes.add({'text': text, 'addedAt': DateTime.now()});
        _newIssueController.clear();
      });
    }
  }

  void _removeNewIssueNote(int index) {
    setState(() {
      if (index >= 0 && index < _newIssueNotes.length) {
        _newIssueNotes.removeAt(index);
      }
    });
  }

  Widget _buildCurrentAndNewIssues() {
    final vp = context.read<VehicleProvider>();
    final currentIssues = vp.selectedVehicle?.issueNotes ?? const [];
    final allIssues = [...currentIssues, ..._newIssueNotes];

    if (allIssues.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: Color(0xFF121212),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Araç Arızaları',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: _cardLine),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...allIssues.asMap().entries.map((entry) {
                final idx = entry.key;
                final issue = entry.value;
                final isNew = idx >= currentIssues.length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (idx > 0) const Divider(height: 1, color: _cardLine),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• ',
                            style: TextStyle(
                              color:
                                  isNew
                                      ? Colors.blue.shade600
                                      : Colors.orange.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  issue['text'] ?? '',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  AppFormatters.formatDateTime(
                                    issue['addedAt'] is DateTime
                                        ? issue['addedAt'] as DateTime
                                        : DateTime.now(),
                                  ),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                if (isNew)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text(
                                      '(Yeni)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isNew)
                            IconButton(
                              iconSize: 18,
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              onPressed:
                                  () => _removeNewIssueNote(
                                    idx - currentIssues.length,
                                  ),
                              icon: const Icon(Icons.close, size: 18),
                              color: Colors.red.shade600,
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
              const Divider(height: 1, color: _cardLine),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newIssueController,
                        maxLines: 2,
                        minLines: 1,
                        style: const TextStyle(fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'Yeni arıza notu ekle...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12.5,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _cardLine),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton.small(
                      heroTag: 'add_issue',
                      backgroundColor: Colors.blue.shade600,
                      onPressed: _addIssueNote,
                      child: const Icon(Icons.add, size: 20),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
            isManual: false,
          ),
        );
      }
    });
  }

  void _requestStockFromPanel() {
    _tabController.index = 0;
    _stockSearchFocus.requestFocus();
  }

  Future<void> _showManualPartDialog() async {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            int qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
            double price =
                double.tryParse(priceCtrl.text.trim().replaceAll(',', '.')) ??
                0;
            final total = qty * price;

            return AlertDialog(
              title: const Text('Manuel parça / malzeme'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Parça / malzeme adı',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setLocal(() {}),
                        validator: (v) {
                          if (v == null || v.trim().length < 2) {
                            return 'En az 2 karakter girin';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Adet',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setLocal(() {}),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Zorunlu';
                          }
                          final n = int.tryParse(v.trim());
                          if (n == null || n < 1) {
                            return 'En az 1 adet';
                          }
                          return null;
                        },
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
                          labelText: 'Birim fiyat (₺)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setLocal(() {}),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Zorunlu';
                          }
                          final p = double.tryParse(
                            v.trim().replaceAll(',', '.'),
                          );
                          if (p == null || p < 0) {
                            return '0 veya üzeri girin';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Toplam: ${AppFormatters.formatLira(total)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
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
            );
          },
        );
      },
    );

    try {
      if (ok != true || !mounted) return;

      final name = nameCtrl.text.trim();
      final q = int.parse(qtyCtrl.text.trim());
      final unitP = double.parse(priceCtrl.text.trim().replaceAll(',', '.'));

      if (!mounted) return;
      setState(() {
        _parts.add(
          ServicePart(
            partId: 'manual',
            partName: name,
            quantity: q,
            unitPrice: unitP,
            totalPrice: q * unitP,
            isManual: true,
          ),
        );
      });
      if (mounted) {
        _tabController.index = 0;
      }
    } finally {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        nameCtrl.dispose();
        qtyCtrl.dispose();
        priceCtrl.dispose();
      });
    }
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
      // Yeni arıza notlarını save et
      if (_newIssueNotes.isNotEmpty) {
        final vehicle = vp.selectedVehicle;
        if (vehicle != null) {
          final updatedNotes = [...vehicle.issueNotes, ..._newIssueNotes];
          final updatedVehicle = vehicle.copyWith(issueNotes: updatedNotes);
          await vp.saveVehicle(updatedVehicle);
        }
      }

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
      backgroundColor: _pageBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/vehicles');
            }
          },
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Yeni servis girişi',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.3),
        ),
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: _panelShell(),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(_panelRadius),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  width: 4,
                                  color: AppColors.secondaryOrange,
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      14,
                                      16,
                                      14,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: AppColors
                                              .secondaryOrange
                                              .withValues(alpha: 0.22),
                                          child: const Icon(
                                            Icons.directions_car_rounded,
                                            color: AppColors.primaryNavy,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 200,
                                          ),
                                          child: TextField(
                                            controller: _plateController,
                                            readOnly: true,
                                            textCapitalization:
                                                TextCapitalization.characters,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                            decoration: InputDecoration(
                                              labelText: 'Araç plakası',
                                              hintText: 'Örn: 34 ABC 123',
                                              filled: true,
                                              fillColor: const Color(
                                                0xFFF8FAFC,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: const BorderSide(
                                                  color: _cardLine,
                                                ),
                                              ),
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
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              LengthLimitingTextInputFormatter(
                                                8,
                                              ),
                                            ],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                            decoration: InputDecoration(
                                              labelText: 'Araç KM (bu servis)',
                                              hintText: 'Örn: 128500',
                                              filled: true,
                                              fillColor: const Color(
                                                0xFFF8FAFC,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: const BorderSide(
                                                  color: _cardLine,
                                                ),
                                              ),
                                              isDense: true,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildCurrentAndNewIssues(),
                      const SizedBox(height: 14),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: _leftWidth,
                              child: _buildLeftPanel(inv),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: _buildCenterPanel()),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: _rightWidth,
                              child: _buildRightPanel(
                                saving: svc.isSaving,
                                online: online,
                              ),
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

    return Container(
      decoration: _panelShell(),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
            Row(
              children: [
                Icon(
                  Icons.warehouse_outlined,
                  size: 20,
                  color: AppColors.primaryNavy.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 8),
                Text(
                  'Stoktan parça',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryNavy,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Listeden tıklayarak sepete ekleyin',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              focusNode: _stockSearchFocus,
              decoration: InputDecoration(
                hintText: 'Parça adı veya kod ara',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.grey.shade500,
                  size: 22,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _cardLine),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primaryNavy,
                    width: 1.2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
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
                        : null,
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
                                    : const Color(0xFFF8FAFC),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color:
                                    disabled ? Colors.red.shade200 : _cardLine,
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              enabled: !disabled,
                              title: Text(
                                item.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                'Stok: ${item.quantity} · ${AppFormatters.formatLira(item.unitPrice)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      disabled
                                          ? Colors.red.shade700
                                          : Colors.grey.shade600,
                                ),
                              ),
                              trailing: Icon(
                                disabled
                                    ? Icons.block_outlined
                                    : Icons.add_circle_rounded,
                                color:
                                    disabled
                                        ? Colors.red.shade700
                                        : AppColors.secondaryOrange,
                                size: 22,
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
    return Container(
      decoration: _panelShell(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _cardLine),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: AppColors.primaryNavy,
                unselectedLabelColor: Colors.black45,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                tabs: const [Tab(text: 'Parçalar'), Tab(text: 'İşçilik')],
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

  Widget _emptyHintBlock({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _cardLine),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryOrange.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 30, color: AppColors.primaryNavy),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.primaryNavy,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPartsTable() {
    final btnStyle = OutlinedButton.styleFrom(
      foregroundColor: AppColors.primaryNavy,
      backgroundColor: Colors.white,
      side: BorderSide(color: AppColors.primaryNavy.withValues(alpha: 0.18)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                style: btnStyle,
                onPressed: _requestStockFromPanel,
                icon: const Icon(Icons.inventory_2_outlined, size: 19),
                label: const Text('Stoktan Ekle'),
              ),
              OutlinedButton.icon(
                style: btnStyle,
                onPressed: _showManualPartDialog,
                icon: const Icon(Icons.edit_outlined, size: 19),
                label: const Text('Manuel Ekle'),
              ),
            ],
          ),
        ),
        Expanded(
          child:
              _parts.isEmpty
                  ? _emptyHintBlock(
                    icon: Icons.inventory_2_outlined,
                    title: 'Bu servise henüz parça eklenmedi',
                    subtitle:
                        'Üstteki butonlarla stoktan veya manuel ekleyin; '
                        'veya soldaki listeden arayıp + ile ekleyin.',
                  )
                  : Padding(
                    padding: const EdgeInsets.all(12),
                    child: Scrollbar(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowHeight: 40,
                            dataRowMinHeight: 40,
                            headingRowColor: WidgetStatePropertyAll(
                              const Color(0xFFE8ECF1),
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
                                  final isManual = p.isManual;
                                  return DataRow(
                                    color: WidgetStatePropertyAll(
                                      isManual
                                          ? const Color(0xFFFFF8E1)
                                          : (i.isEven
                                              ? Colors.white
                                              : AppColors.surfaceMuted
                                                  .withValues(alpha: 0.7)),
                                    ),
                                    cells: [
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isManual
                                                  ? Icons.edit_outlined
                                                  : Icons.inventory_2_outlined,
                                              size: 18,
                                              color:
                                                  isManual
                                                      ? Colors.amber.shade800
                                                      : AppColors.primaryNavy,
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                p.partName,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      DataCell(Text('${p.quantity}')),
                                      DataCell(
                                        Text(
                                          AppFormatters.formatLira(p.unitPrice),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          AppFormatters.formatLira(
                                            p.totalPrice,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 20,
                                          ),
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
                  ),
        ),
      ],
    );
  }

  Widget _buildLaborTable() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryNavy,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: AppColors.primaryNavy.withValues(alpha: 0.18),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _addLaborRow,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('İşçilik satırı ekle'),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child:
                _labor.isEmpty
                    ? _emptyHintBlock(
                      icon: Icons.design_services_outlined,
                      title: 'İşçilik kalemi yok',
                      subtitle:
                          'Balata, yağ değişimi gibi işçilik tutarlarını '
                          'buraya satır satır ekleyebilirsiniz.',
                    )
                    : Scrollbar(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowHeight: 40,
                            dataRowMinHeight: 40,
                            headingRowColor: WidgetStatePropertyAll(
                              const Color(0xFFE8ECF1),
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
    return Container(
      decoration: _panelShell(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryOrange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.summarize_rounded,
                    size: 18,
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Özet',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryNavy,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Fiyatlandırma özeti',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: _cardLine),
            ),
            _kv('Ara toplam', AppFormatters.formatLira(_subtotal())),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _cardLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'KDV uygula',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Transform.scale(
                        scale: 0.9,
                        child: Switch(
                          value: _kdvIncluded,
                          activeThumbColor: AppColors.secondaryOrange,
                          activeTrackColor: AppColors.primaryNavy.withValues(
                            alpha: 0.45,
                          ),
                          onChanged: (v) => setState(() => _kdvIncluded = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  DropdownButtonFormField<double>(
                    initialValue: _kdvRate,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'KDV oranı',
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
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
                ],
              ),
            ),
            const SizedBox(height: 8),
            _kv('KDV tutarı', AppFormatters.formatLira(_kdvAmount())),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F0F0F), Color(0xFF1E1E1E)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryNavy.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryOrange,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(12),
                          bottomLeft: const Radius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GENEL TOPLAM',
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppFormatters.formatLira(_grandTotal()),
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Teknisyen',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _technicianController,
              maxLines: 1,
              style: const TextStyle(fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Servisi yapan kişi',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _cardLine),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              maxLines: 4,
              style: const TextStyle(fontSize: 13, height: 1.35),
              decoration: InputDecoration(
                labelText: 'Notlar',
                alignLabelWithHint: true,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _cardLine),
                ),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: (saving || !online) ? null : _complete,
              icon:
                  saving
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.check_rounded, size: 22),
              label: Text(
                saving
                    ? 'Kaydediliyor…'
                    : online
                    ? 'Servisi tamamla'
                    : 'İnternet gerekir',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondaryOrange,
                foregroundColor: AppColors.primaryNavy,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            k,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
        ),
        Text(
          v,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AppColors.primaryNavy,
          ),
        ),
      ],
    );
  }
}
