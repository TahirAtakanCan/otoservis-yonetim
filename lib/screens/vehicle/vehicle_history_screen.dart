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

  String? _kmInfoLine(int index) {
    final current = _records[index].vehicleKm;
    if (current <= 0) return null;

    final base = 'KM: ${AppFormatters.formatKm(current)} km';
    if (index + 1 >= _records.length) {
      return base;
    }

    final previous = _records[index + 1].vehicleKm;
    if (previous <= 0) {
      return base;
    }

    final diff = current - previous;
    final sign = diff >= 0 ? '+' : '-';
    return '$base · Son 2 işlem farkı: $sign${AppFormatters.formatKm(diff.abs())} km';
  }

  void _openPdfPreview(ServiceRecord record) {
    if (record.id.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servis kaydı kimliği bulunamadı.')),
      );
      return;
    }
    context.push('/pdf/preview/${Uri.encodeComponent(record.id)}');
  }

  Future<void> _confirmDeleteRecord(ServiceRecord record) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dCtx) => AlertDialog(
            title: const Text('Servis kaydını sil'),
            content: const Text(
              'Bu servis kaydı kalıcı olarak silinecek. Emin misiniz?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dCtx).pop(false),
                child: const Text('İptal'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade800,
                ),
                onPressed: () => Navigator.of(dCtx).pop(true),
                child: const Text('Sil'),
              ),
            ],
          ),
    );
    if (ok != true || !mounted) return;

    try {
      final vp = context.read<VehicleProvider>();
      await vp.deleteServiceRecordById(record.id);
      if (!mounted) return;
      setState(() {
        _records.removeWhere((r) => r.id == record.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servis kaydı silindi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Silinemedi: $e')));
    }
  }

  Future<void> _confirmDeleteVehicleHistory() async {
    if (_vehicle == null || _records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silinecek servis geçmişi bulunmuyor.')),
      );
      return;
    }

    final count = _records.length;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dCtx) => AlertDialog(
            title: const Text('Araç geçmişini sil'),
            content: Text(
              'Bu araca ait tüm servis geçmişi ($count kayıt) kalıcı olarak silinecek. Emin misiniz?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dCtx).pop(false),
                child: const Text('İptal'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade800,
                ),
                onPressed: () => Navigator.of(dCtx).pop(true),
                child: const Text('Hepsini Sil'),
              ),
            ],
          ),
    );
    if (ok != true || !mounted) return;

    try {
      final vp = context.read<VehicleProvider>();
      final deleted = await vp.deleteServiceHistoryForPlate(_vehicle!.plate);
      if (!mounted) return;
      setState(() => _records = []);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$deleted servis kaydı silindi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Geçmiş silinemedi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VehicleProvider>();
    final v = _vehicle;
    final vehicleIssues = v?.issueNotes ?? const <String>[];
    const maxIssuesShown = 3;
    final shownIssues =
        vehicleIssues.length > maxIssuesShown ? vehicleIssues.take(maxIssuesShown).toList() : vehicleIssues;
    final hiddenCount = vehicleIssues.length - shownIssues.length;
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
                                    _infoRow(
                                      'Güncel KM',
                                      v.currentKm > 0
                                          ? '${AppFormatters.formatKm(v.currentKm)} km'
                                          : '—',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Servis kayıtları',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                if (_records.isNotEmpty)
                                  OutlinedButton.icon(
                                    onPressed: _confirmDeleteVehicleHistory,
                                    icon: const Icon(
                                      Icons.delete_sweep_outlined,
                                    ),
                                    label: const Text('Araç Geçmişini Sil'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red.shade700,
                                    ),
                                  ),
                              ],
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
                              ..._records.asMap().entries.map(
                                (entry) {
                                  final i = entry.key;
                                  final r = entry.value;
                                  final kmLine = _kmInfoLine(i);
                                  final summary = _summary(r);
                                  final subtitle =
                                      kmLine == null ? summary : '$summary\n$kmLine';

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: Column(
                                      children: [
                                        ListTile(
                                          onTap: () => _openPdfPreview(r),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
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
                                              subtitle,
                                              maxLines: 4,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Column(
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
                                                      color: _statusColor(
                                                        r.status,
                                                      ),
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              PopupMenuButton<String>(
                                                tooltip: 'İşlemler',
                                                onSelected: (value) {
                                                  if (value == 'pdf') {
                                                    _openPdfPreview(r);
                                                    return;
                                                  }
                                                  if (value == 'delete') {
                                                    _confirmDeleteRecord(r);
                                                  }
                                                },
                                                itemBuilder:
                                                    (ctx) => const [
                                                  PopupMenuItem<String>(
                                                    value: 'pdf',
                                                    child: Text('PDF Aç'),
                                                  ),
                                                  PopupMenuItem<String>(
                                                    value: 'delete',
                                                    child: Text(
                                                      'Servis Kaydını Sil',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (vehicleIssues.isNotEmpty) ...[
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              0,
                                              16,
                                              12,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Araç arızaları',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                ),
                                                const SizedBox(height: 6),
                                                ...shownIssues.map(
                                                  (note) => Text(
                                                    '- $note',
                                                    style: const TextStyle(
                                                      fontSize: 12.5,
                                                      height: 1.35,
                                                    ),
                                                  ),
                                                ),
                                                if (hiddenCount > 0)
                                                  Text(
                                                    '+$hiddenCount daha',
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      height: 1.35,
                                                      color: Colors.grey.shade700,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
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
