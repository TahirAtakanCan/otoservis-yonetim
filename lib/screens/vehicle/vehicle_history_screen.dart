import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:otoservis_app/models/service_record.dart';
import 'package:otoservis_app/models/vehicle.dart';
import 'package:otoservis_app/providers/vehicle_provider.dart';
import 'package:otoservis_app/utils/constants.dart';
import 'package:otoservis_app/utils/formatters.dart';
import 'package:otoservis_app/widgets/common/app_error_banner.dart';
import 'package:otoservis_app/widgets/common/app_sidebar.dart';

class VehicleHistoryScreen extends StatefulWidget {
  const VehicleHistoryScreen({super.key, required this.plate});

  /// Route parametresi (URL decode edilmiş veya ham plaka).
  final String plate;

  @override
  State<VehicleHistoryScreen> createState() => _VehicleHistoryScreenState();
}

class _VehicleHistoryScreenState extends State<VehicleHistoryScreen> {
  Vehicle? _vehicle;
  List<ServiceRecord> _records = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final vp = context.read<VehicleProvider>();
    final key = vp.normalizePlate(Uri.decodeComponent(widget.plate));

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final v = await vp.fetchVehicleByPlate(key);
      if (v == null) {
        if (!mounted) return;
        setState(() {
          _vehicle = null;
          _records = [];
          _loading = false;
          _error = 'Araç bulunamadı.';
        });
        return;
      }

      vp.setSelectedVehicle(v);
      final list = await vp.fetchServiceHistoryForPlate(key);
      if (!mounted) return;
      setState(() {
        _vehicle = v;
        _records = list;
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

  String _summary(ServiceRecord r) {
    final labor = r.laborItems
        .map((e) => e.description)
        .where((s) => s.isNotEmpty);
    final parts = r.parts.map((e) => '${e.partName}×${e.quantity}');
    final bits = [...labor, ...parts];
    if (bits.isEmpty) {
      return r.notes.isNotEmpty ? r.notes : '—';
    }
    return bits.join(' · ');
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'open':
        return 'Açık';
      case 'completed':
        return 'Tamamlandı';
      case 'invoiced':
        return 'Faturalandı';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.orange.shade800;
      case 'completed':
        return Colors.green.shade800;
      case 'invoiced':
        return Colors.blue.shade800;
      default:
        return Colors.black54;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VehicleProvider>();
    final v = _vehicle;
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSidebar(),
          Expanded(
            child: ColoredBox(
              color: AppColors.surfaceMuted,
              child:
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null && v == null
                      ? Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppErrorBanner(message: _error!, onRetry: _load),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: () => context.go('/vehicles'),
                                child: const Text('Araç listesine dön'),
                              ),
                            ],
                          ),
                        ),
                      )
                      : v == null
                      ? const SizedBox.shrink()
                      : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed: () => context.go('/vehicles'),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Araç geçmişi',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Card(
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            vp.formatPlateForDisplay(v.plate),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.headlineSmall?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ),
                                        FilledButton.icon(
                                          onPressed: () {
                                            vp.setSelectedVehicle(v);
                                            context.go(
                                              '/service/new?plate=${Uri.encodeQueryComponent(v.plate)}',
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.add_task,
                                            size: 20,
                                          ),
                                          label: const Text(
                                            'Yeni Servis Girişi',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 28),
                                    _infoRow('Sahip', v.ownerName),
                                    _infoRow('Telefon', v.ownerPhone),
                                    _infoRow(
                                      'Araç',
                                      '${v.brand} ${v.model} (${v.year})',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Servis kayıtları',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            if (_records.isEmpty)
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Center(
                                    child: Text(
                                      'Henüz servis kaydı yok.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(color: Colors.black45),
                                    ),
                                  ),
                                ),
                              )
                            else
                              ..._records.map(
                                (r) => Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    title: Text(
                                      AppFormatters.formatDateTime(r.date),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        _summary(r),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          AppFormatters.formatLira(
                                            r.grandTotal,
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _statusLabel(r.status),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _statusColor(r.status),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
