import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:otoservis_app/models/inventory_item.dart';
import 'package:otoservis_app/models/service_record.dart';
import 'package:otoservis_app/models/vehicle.dart';
import 'package:otoservis_app/screens/reports/reports_pdf_export.dart';
import 'package:otoservis_app/utils/constants.dart';
import 'package:otoservis_app/utils/formatters.dart';
import 'package:otoservis_app/widgets/common/app_sidebar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

// —— Tarih aralığı —— //
DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _endOfDay(DateTime d) =>
    DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

DateTime _minD(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

double _partsTotal(ServiceRecord r) =>
    r.parts.fold(0.0, (s, p) => s + p.totalPrice);

double _laborTotal(ServiceRecord r) =>
    r.laborItems.fold(0.0, (s, l) => s + l.price);

/// `service_records` sorgusu (tarih alanı [start, end] kapsar).
Future<List<ServiceRecord>> _queryServiceRecords(
  DateTime start,
  DateTime end,
) async {
  final s = _startOfDay(start);
  final e = _endOfDay(end);
  final snap = await FirebaseFirestore.instance
      .collection(FirestoreCollections.serviceRecords)
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(s))
      .where('date', isLessThanOrEqualTo: Timestamp.fromDate(e))
      .get();
  return snap.docs
      .map(
        (d) => ServiceRecord.fromMap({...d.data(), 'id': d.id}),
      )
      .toList();
}

Future<Map<String, Vehicle>> _loadVehiclesForPlates(
  Iterable<String> plates,
) async {
  final fs = FirebaseFirestore.instance;
  final out = <String, Vehicle>{};
  for (final p in plates) {
    final key = AppFormatters.normalizePlate(p);
    if (key.isEmpty) continue;
    final doc = await fs
        .collection(FirestoreCollections.vehicles)
        .doc(key)
        .get();
    if (doc.exists && doc.data() != null) {
      out[key] = Vehicle.fromMap({...doc.data()!, 'plate': key});
    }
  }
  return out;
}

Future<List<InventoryItem>> _loadAllInventory() async {
  final snap = await FirebaseFirestore.instance
      .collection(FirestoreCollections.inventory)
      .get();
  return snap.docs
      .map(
        (d) => InventoryItem.fromMap({...d.data(), 'id': d.id}),
      )
      .toList();
}

/// Raporlama ekranı: filtre, özet kartlar, 4 sekme, PDF dışa aktarma.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

enum _DateFilterKind { thisWeek, thisMonth, thisYear, custom }

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  static const _navyBox = Color(0xFF1a237e);

  late TabController _tabController;

  _DateFilterKind _filter = _DateFilterKind.thisMonth;
  DateTime? _customStart;
  DateTime? _customEnd;

  int _reloadToken = 0;
  (int, DateTime, DateTime)? _recordsCacheKey;
  Future<List<ServiceRecord>>? _recordsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final now = DateTime.now();
    _customStart = DateTime(now.year, now.month, 1);
    _customEnd = now;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  (DateTime start, DateTime end) _effectiveRange() {
    final now = DateTime.now();
    final today = _startOfDay(now);
    switch (_filter) {
      case _DateFilterKind.thisWeek:
        final monday = today.subtract(Duration(days: today.weekday - 1));
        final sunday = _endOfDay(monday.add(const Duration(days: 6)));
        final end = _minD(sunday, _endOfDay(now));
        return (monday, end);
      case _DateFilterKind.thisMonth:
        return (
          DateTime(now.year, now.month, 1),
          _endOfDay(now),
        );
      case _DateFilterKind.thisYear:
        return (
          DateTime(now.year, 1, 1),
          _endOfDay(now),
        );
      case _DateFilterKind.custom:
        final s = _customStart ?? DateTime(now.year, now.month, 1);
        final e = _customEnd ?? now;
        final first = s.isBefore(e) ? s : e;
        final second = s.isBefore(e) ? e : s;
        return (_startOfDay(first), _endOfDay(second));
    }
  }

  Future<List<ServiceRecord>> _ensureRecords() {
    final range = _effectiveRange();
    final key = (_reloadToken, range.$1, range.$2);
    if (_recordsCacheKey == key && _recordsFuture != null) {
      return _recordsFuture!;
    }
    _recordsCacheKey = key;
    _recordsFuture = _queryServiceRecords(range.$1, range.$2);
    return _recordsFuture!;
  }

  void _invalidateAndReload() {
    setState(() {
      _reloadToken++;
      _recordsCacheKey = null;
      _recordsFuture = null;
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final range = _effectiveRange();
    final initial =
        isStart ? (_customStart ?? range.$1) : (_customEnd ?? range.$2);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      locale: const Locale('tr', 'TR'),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _filter = _DateFilterKind.custom;
      if (isStart) {
        _customStart = picked;
      } else {
        _customEnd = picked;
      }
      _invalidatePartial();
    });
  }

  void _invalidatePartial() {
    _recordsCacheKey = null;
    _recordsFuture = null;
  }

  Future<void> _persistPdfBytes(Uint8List bytes, String filename) async {
    if (kIsWeb) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF kaydedildi: ${file.path}')),
      );
    } catch (_) {
      // Yerel kaydetme başarısız olsa bile indirme/yazdırma adımına devam edilir.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'PDF cihaza kaydedilemedi. İndirme/yazdırma penceresi açılıyor.',
          ),
        ),
      );
    }
  }

  Future<void> _sharePdfWithFallback(
    Uint8List bytes,
    String filename,
  ) async {
    try {
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (_) {
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    }
  }

  Future<void> _exportFullPdf() async {
    final messenger = ScaffoldMessenger.of(context);
    final range = _effectiveRange();
    try {
      messenger.showSnackBar(
        const SnackBar(content: Text('Tam rapor hazırlanıyor…')),
      );
      final records = await _queryServiceRecords(range.$1, range.$2);
      final plates =
          records.map((r) => AppFormatters.normalizePlate(r.vehiclePlate)).toSet();
      final vehicles = await _loadVehiclesForPlates(plates);
      final inventory = await _loadAllInventory();
      final bytes = await ReportsPdfExport.buildFullReportPdfCombined(
        start: range.$1,
        end: range.$2,
        records: records,
        vehiclesByPlate: vehicles,
        allInventory: inventory,
      );
      await _persistPdfBytes(bytes, 'mert_otoservis_tum_rapor.pdf');
      await _sharePdfWithFallback(
        bytes,
        'mert_otoservis_tum_rapor.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('PDF oluşturulamadı: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = _effectiveRange();
    final theme = Theme.of(context);

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSidebar(),
          Expanded(
            child: ColoredBox(
              color: AppColors.surfaceMuted,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Raporlar',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryNavy,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _filterChip(
                                    'Bu Hafta',
                                    _filter == _DateFilterKind.thisWeek,
                                    () => setState(() {
                                      _filter = _DateFilterKind.thisWeek;
                                      _invalidatePartial();
                                    }),
                                  ),
                                  _filterChip(
                                    'Bu Ay',
                                    _filter == _DateFilterKind.thisMonth,
                                    () => setState(() {
                                      _filter = _DateFilterKind.thisMonth;
                                      _invalidatePartial();
                                    }),
                                  ),
                                  _filterChip(
                                    'Bu Yıl',
                                    _filter == _DateFilterKind.thisYear,
                                    () => setState(() {
                                      _filter = _DateFilterKind.thisYear;
                                      _invalidatePartial();
                                    }),
                                  ),
                                  _filterChip(
                                    'Özel Aralık',
                                    _filter == _DateFilterKind.custom,
                                    () => setState(() {
                                      _filter = _DateFilterKind.custom;
                                      _invalidatePartial();
                                    }),
                                  ),
                                  if (_filter == _DateFilterKind.custom) ...[
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _pickDate(isStart: true),
                                      icon: const Icon(Icons.calendar_today,
                                          size: 18),
                                      label: Text(
                                        'Başlangıç: ${DateFormat('d.MM.yyyy', 'tr_TR').format(_customStart ?? range.$1)}',
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _pickDate(isStart: false),
                                      icon: const Icon(Icons.calendar_today,
                                          size: 18),
                                      label: Text(
                                        'Bitiş: ${DateFormat('d.MM.yyyy', 'tr_TR').format(_customEnd ?? range.$2)}',
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _exportFullPdf,
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Tüm Raporu İndir'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.secondaryOrange,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 280,
                            child: _SummaryColumn(
                              recordsFuture: _ensureRecords(),
                              onRetry: _invalidateAndReload,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Material(
                                    color: Colors.transparent,
                                    child: TabBar(
                                      controller: _tabController,
                                      labelColor: _navyBox,
                                      unselectedLabelColor: Colors.grey,
                                      indicatorColor: _navyBox,
                                      isScrollable: true,
                                      tabs: const [
                                        Tab(text: 'Gelir'),
                                        Tab(text: 'Araç'),
                                        Tab(text: 'Stok Hareket'),
                                        Tab(text: 'Teknisyen'),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: TabBarView(
                                      controller: _tabController,
                                      children: [
                                        _RevenueTab(
                                          range: range,
                                          recordsFuture: _ensureRecords(),
                                          onRetry: _invalidateAndReload,
                                          onPdf: () async =>
                                              _revenuePdf(range),
                                        ),
                                        _VehicleTab(
                                          recordsFuture: _ensureRecords(),
                                          onRetry: _invalidateAndReload,
                                          onPdf: () async =>
                                              _vehiclePdf(range),
                                        ),
                                        _StockTab(
                                          recordsFuture: _ensureRecords(),
                                          onRetry: _invalidateAndReload,
                                          onPdf: (includeStok, includeHarici) async =>
                                              _stockPdf(
                                            range,
                                            includeStok: includeStok,
                                            includeHarici: includeHarici,
                                          ),
                                        ),
                                        _TechnicianTab(
                                          recordsFuture: _ensureRecords(),
                                          onRetry: _invalidateAndReload,
                                          onPdf: () async =>
                                              _technicianPdf(range),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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

  Widget _filterChip(String label, bool sel, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: sel,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.secondaryOrange.withValues(alpha: 0.35),
    );
  }

  Future<void> _revenuePdf((DateTime, DateTime) range) async {
    try {
      final records = await _queryServiceRecords(range.$1, range.$2);
      final bytes = await ReportsPdfExport.buildRevenuePdf(
        start: range.$1,
        end: range.$2,
        records: records,
      );
      await _persistPdfBytes(bytes, 'gelir_raporu.pdf');
      await _sharePdfWithFallback(bytes, 'gelir_raporu.pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF hatası: $e')),
      );
    }
  }

  Future<void> _vehiclePdf((DateTime, DateTime) range) async {
    try {
      final records = await _queryServiceRecords(range.$1, range.$2);
      final plates =
          records.map((r) => AppFormatters.normalizePlate(r.vehiclePlate)).toSet();
      final vehicles = await _loadVehiclesForPlates(plates);
      final rows =
          ReportsPdfExport.vehicleRowsFromRecords(records, vehicles);
      final bytes = await ReportsPdfExport.buildVehiclePdf(
        start: range.$1,
        end: range.$2,
        rows: rows,
      );
      await _persistPdfBytes(bytes, 'arac_raporu.pdf');
      await _sharePdfWithFallback(bytes, 'arac_raporu.pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF hatası: $e')),
      );
    }
  }

  Future<void> _stockPdf(
    (DateTime, DateTime) range, {
    bool includeStok = true,
    bool includeHarici = true,
  }) async {
    if (!includeStok && !includeHarici) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Stok hareket raporu için en az biri seçilmelidir: stok parçaları veya harici parçalar.',
          ),
        ),
      );
      return;
    }
    try {
      final records = await _queryServiceRecords(range.$1, range.$2);
      final inventory = await _loadAllInventory();
      final partRows = ReportsPdfExport.aggregateParts(
        records,
        inventory,
        includeStok: includeStok,
        includeHarici: includeHarici,
      );
      final critical =
          inventory.where((e) => e.quantity <= e.minStockAlert).toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      final bytes = await ReportsPdfExport.buildStockPdf(
        start: range.$1,
        end: range.$2,
        partRows: partRows,
        criticalItems: critical,
        movementFilterCaption: ReportsPdfExport.stockMovementFilterCaption(
          includeStok: includeStok,
          includeHarici: includeHarici,
        ),
      );
      await _persistPdfBytes(bytes, 'stok_hareket_raporu.pdf');
      await _sharePdfWithFallback(bytes, 'stok_hareket_raporu.pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF hatası: $e')),
      );
    }
  }

  Future<void> _technicianPdf((DateTime, DateTime) range) async {
    try {
      final records = await _queryServiceRecords(range.$1, range.$2);
      final rows = ReportsPdfExport.technicianRows(records);
      final bytes = await ReportsPdfExport.buildTechnicianPdf(
        start: range.$1,
        end: range.$2,
        rows: rows,
      );
      await _persistPdfBytes(bytes, 'teknisyen_raporu.pdf');
      await _sharePdfWithFallback(bytes, 'teknisyen_raporu.pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF hatası: $e')),
      );
    }
  }
}

// —— Özet kartlar —— //

class _SummaryColumn extends StatelessWidget {
  const _SummaryColumn({
    required this.recordsFuture,
    required this.onRetry,
  });

  final Future<List<ServiceRecord>> recordsFuture;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ServiceRecord>>(
      future: recordsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _TabError(message: '${snapshot.error}', onRetry: onRetry);
        }
        final records = snapshot.data ?? [];
        if (records.isEmpty) {
          return const Center(
            child: Text(
              'Bu tarih aralığında kayıt bulunamadı.',
              textAlign: TextAlign.center,
            ),
          );
        }

        double totalRev =
            records.fold(0.0, (s, r) => s + r.grandTotal);
        final avg = records.isEmpty ? 0.0 : totalRev / records.length;

        final byPlate = <String, int>{};
        for (final r in records) {
          final p = AppFormatters.normalizePlate(r.vehiclePlate);
          byPlate[p] = (byPlate[p] ?? 0) + 1;
        }
        String topPlate = '—';
        var maxC = 0;
        byPlate.forEach((k, v) {
          if (v > maxC) {
            maxC = v;
            topPlate = k;
          }
        });

        return ListView(
          children: [
            _SummaryCard(
              title: 'Toplam Ciro',
              value: AppFormatters.formatLira(totalRev),
              icon: Icons.payments_outlined,
            ),
            const SizedBox(height: 12),
            _SummaryCard(
              title: 'Toplam Servis Sayısı',
              value: '${records.length}',
              icon: Icons.build_circle_outlined,
            ),
            const SizedBox(height: 12),
            _SummaryCard(
              title: 'En Çok Gelen Araç',
              value: maxC == 0
                  ? '—'
                  : AppFormatters.formatPlateDisplay(topPlate),
              subtitle: maxC > 0 ? '$maxC servis' : null,
              icon: Icons.directions_car_filled_outlined,
            ),
            const SizedBox(height: 12),
            _SummaryCard(
              title: 'Ortalama Servis Tutarı',
              value: AppFormatters.formatLira(avg),
              icon: Icons.analytics_outlined,
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
  });

  final String title;
  final String value;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryNavy, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: t.textTheme.labelMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: t.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: t.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
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

// —— Sekme: Gelir —— //

class _RevenueTab extends StatelessWidget {
  const _RevenueTab({
    required this.range,
    required this.recordsFuture,
    required this.onRetry,
    required this.onPdf,
  });

  final (DateTime, DateTime) range;
  final Future<List<ServiceRecord>> recordsFuture;
  final VoidCallback onRetry;
  final Future<void> Function() onPdf;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ServiceRecord>>(
      future: recordsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _TabError(message: '${snapshot.error}', onRetry: onRetry);
        }
        final records = snapshot.data ?? [];
        if (records.isEmpty) {
          return const _EmptyTabMessage();
        }

        final sorted = [...records]..sort((a, b) => a.date.compareTo(b.date));
        final totalKdv =
            sorted.fold<double>(0, (a, r) => a + r.kdvAmount);
        final totalExcl =
            sorted.fold<double>(0, (a, r) => a + r.subtotal);
        final totalGrand =
            sorted.fold<double>(0, (a, r) => a + r.grandTotal);

        final spanDays = range.$2.difference(range.$1).inDays;
        final weekly = spanDays > 31;

        final buckets = <DateTime, double>{};
        for (final r in sorted) {
          DateTime key;
          if (weekly) {
            final d = DateTime(r.date.year, r.date.month, r.date.day);
            key = d.subtract(Duration(days: d.weekday - 1));
          } else {
            key = DateTime(r.date.year, r.date.month, r.date.day);
          }
          buckets[key] = (buckets[key] ?? 0) + r.grandTotal;
        }
        final sortedKeys = buckets.keys.toList()..sort();

        final maxY = buckets.values.fold<double>(
          1,
          (p, e) => e > p ? e : p,
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            return Scrollbar(
              child: SingleChildScrollView(
                primary: true,
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () => onPdf(),
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Gelir raporu PDF\'i al'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 260,
                        child: sortedKeys.isEmpty
                            ? const Center(child: Text('Grafik için veri yok'))
                            : Padding(
                                padding: const EdgeInsets.only(
                                  right: 12,
                                  top: 16,
                                  bottom: 8,
                                ),
                                child: BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    maxY: maxY * 1.15,
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: false,
                                      horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                                      getDrawingHorizontalLine: (_) => FlLine(
                                        color: Colors.grey.shade300,
                                        strokeWidth: 1,
                                      ),
                                    ),
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 44,
                                          getTitlesWidget: (v, meta) =>
                                              Text(
                                            NumberFormat.compact(locale: 'tr_TR')
                                                .format(v),
                                            style: const TextStyle(fontSize: 10),
                                          ),
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          interval: sortedKeys.length > 12
                                              ? (sortedKeys.length / 8).ceilToDouble()
                                              : 1,
                                          getTitlesWidget: (vi, _) {
                                            final i = vi.toInt();
                                            if (i < 0 ||
                                                i >= sortedKeys.length) {
                                              return const SizedBox.shrink();
                                            }
                                            final d = sortedKeys[i];
                                            final fmt = weekly
                                                ? DateFormat('d MMM', 'tr_TR')
                                                : DateFormat('d.MM', 'tr_TR');
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: Text(
                                                fmt.format(d),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      topTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                      rightTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    barGroups: [
                                      for (var i = 0;
                                          i < sortedKeys.length;
                                          i++)
                                        BarChartGroupData(
                                          x: i,
                                          barRods: [
                                            BarChartRodData(
                                              toY: buckets[sortedKeys[i]] ?? 0,
                                              width: weekly ? 14 : 12,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              color:
                                                  AppColors.secondaryOrange,
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                      Text(
                        weekly ? 'Haftalık ciro' : 'Günlük ciro',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            AppColors.primaryNavy.withValues(alpha: 0.12),
                          ),
                          columns: const [
                            DataColumn(label: Text('Tarih')),
                            DataColumn(label: Text('Plaka')),
                            DataColumn(label: Text('Teknisyen')),
                            DataColumn(label: Text('Parça Toplamı')),
                            DataColumn(label: Text('İşçilik')),
                            DataColumn(label: Text('KDV')),
                            DataColumn(label: Text('Genel Toplam')),
                          ],
                          rows: [
                            for (var ri = 0; ri < sorted.length; ri++)
                              DataRow(
                                color: WidgetStateProperty.resolveWith((_) {
                                  return ri.isEven
                                      ? Colors.white
                                      : Colors.grey.shade100;
                                }),
                                cells: [
                                  DataCell(Text(DateFormat(
                                    'd.MM.yyyy',
                                    'tr_TR',
                                  ).format(sorted[ri].date))),
                                  DataCell(Text(
                                    AppFormatters.formatPlateDisplay(
                                      sorted[ri].vehiclePlate,
                                    ),
                                  )),
                                  DataCell(Text(sorted[ri].technicianName)),
                                  DataCell(Text(AppFormatters.formatLira(
                                    _partsTotal(sorted[ri]),
                                  ))),
                                  DataCell(Text(AppFormatters.formatLira(
                                    _laborTotal(sorted[ri]),
                                  ))),
                                  DataCell(Text(AppFormatters.formatLira(
                                    sorted[ri].kdvAmount,
                                  ))),
                                  DataCell(Text(AppFormatters.formatLira(
                                    sorted[ri].grandTotal,
                                  ))),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1a237e),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _totalLineWhite('Toplam KDV tutarı', totalKdv),
                            _totalLineWhite('KDV hariç toplam', totalExcl),
                            const Divider(color: Colors.white54),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Genel toplam',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  AppFormatters.formatLira(totalGrand),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
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
              ),
            );
          },
        );
      },
    );
  }

  Widget _totalLineWhite(String label, double v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            AppFormatters.formatLira(v),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// —— Sekme: Araç —— //

class _VehicleTab extends StatelessWidget {
  const _VehicleTab({
    required this.recordsFuture,
    required this.onRetry,
    required this.onPdf,
  });

  final Future<List<ServiceRecord>> recordsFuture;
  final VoidCallback onRetry;
  final Future<void> Function() onPdf;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ServiceRecord>>(
      future: recordsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _TabError(message: '${snap.error}', onRetry: onRetry);
        }
        final records = snap.data ?? [];
        if (records.isEmpty) {
          return const _EmptyTabMessage();
        }

        final plates =
            records.map((r) => AppFormatters.normalizePlate(r.vehiclePlate)).toSet();

        return FutureBuilder<Map<String, Vehicle>>(
          future: _loadVehiclesForPlates(plates),
          builder: (context, vs) {
            if (vs.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (vs.hasError) {
              return _TabError(
                message: '${vs.error}',
                onRetry: onRetry,
              );
            }
            final vehicles = vs.data ?? {};
            final rows =
                ReportsPdfExport.vehicleRowsFromRecords(records, vehicles);

            return Scrollbar(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => onPdf(),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Araç raporu PDF\'i al'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        AppColors.primaryNavy.withValues(alpha: 0.12),
                      ),
                      columns: const [
                        DataColumn(label: Text('Sıra')),
                        DataColumn(label: Text('Plaka')),
                        DataColumn(label: Text('Araç Sahibi')),
                        DataColumn(label: Text('Servis Sayısı')),
                        DataColumn(label: Text('Toplam Harcama')),
                        DataColumn(label: Text('Son Servis')),
                      ],
                      rows: [
                        for (var i = 0; i < rows.length; i++)
                          DataRow(
                            onSelectChanged: (_) {
                              final plateUrl = Uri.encodeComponent(rows[i].$1);
                              context.go('/vehicle/$plateUrl/history');
                            },
                            color: WidgetStateProperty.resolveWith((_) {
                              return i.isEven
                                  ? Colors.white
                                  : Colors.grey.shade100;
                            }),
                            cells: [
                              DataCell(Text('${i + 1}')),
                              DataCell(Text(
                                AppFormatters.formatPlateDisplay(rows[i].$1),
                              )),
                              DataCell(Text(rows[i].$2)),
                              DataCell(Text('${rows[i].$3}')),
                              DataCell(Text(
                                AppFormatters.formatLira(rows[i].$4),
                              )),
                              DataCell(Text(
                                DateFormat('d.MM.yyyy', 'tr_TR')
                                    .format(rows[i].$5),
                              )),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Satıra tıklayarak araç geçmişine gidebilirsiniz.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// —— Sekme: Stok —— //

class _StockTab extends StatefulWidget {
  const _StockTab({
    required this.recordsFuture,
    required this.onRetry,
    required this.onPdf,
  });

  final Future<List<ServiceRecord>> recordsFuture;
  final VoidCallback onRetry;
  final Future<void> Function(bool includeStok, bool includeHarici) onPdf;

  @override
  State<_StockTab> createState() => _StockTabState();
}

class _StockTabState extends State<_StockTab> {
  bool _includeStok = true;
  bool _includeHarici = true;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ServiceRecord>>(
      future: widget.recordsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _TabError(message: '${snap.error}', onRetry: widget.onRetry);
        }
        final records = snap.data ?? [];
        if (records.isEmpty) {
          return const _EmptyTabMessage();
        }

        return FutureBuilder<List<InventoryItem>>(
          future: _loadAllInventory(),
          builder: (context, invSnap) {
            if (invSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (invSnap.hasError) {
              return _TabError(
                message: '${invSnap.error}',
                onRetry: widget.onRetry,
              );
            }
            final inventory = invSnap.data ?? [];
            final partRows = ReportsPdfExport.aggregateParts(
              records,
              inventory,
              includeStok: _includeStok,
              includeHarici: _includeHarici,
            );
            final byName = {for (final i in inventory) i.name: i};
            final byId = {for (final i in inventory) i.id: i};

            return Scrollbar(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Harekete dahil edilecek parça türleri',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.primaryNavy,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Stoktan (envanter)'),
                        selected: _includeStok,
                        onSelected: (v) {
                          setState(() => _includeStok = v);
                        },
                      ),
                      FilterChip(
                        label: const Text('Harici (manuel)'),
                        selected: _includeHarici,
                        onSelected: (v) {
                          setState(() => _includeHarici = v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => widget.onPdf(
                        _includeStok,
                        _includeHarici,
                      ),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Stok hareket raporu PDF\'i al'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        AppColors.primaryNavy.withValues(alpha: 0.12),
                      ),
                      columns: const [
                        DataColumn(label: Text('Parça Adı')),
                        DataColumn(label: Text('Kategori')),
                        DataColumn(label: Text('Kullanım Adedi')),
                        DataColumn(label: Text('Toplam Tutar')),
                      ],
                      rows: partRows.isEmpty
                          ? [
                              DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      'Seçilen kapsamda hareket yok veya tüm türler kapalı.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.grey.shade600,
                                            fontStyle: FontStyle.italic,
                                          ),
                                    ),
                                  ),
                                  const DataCell(SizedBox.shrink()),
                                  const DataCell(SizedBox.shrink()),
                                  const DataCell(SizedBox.shrink()),
                                ],
                              ),
                            ]
                          : [
                              for (var i = 0; i < partRows.length; i++)
                                DataRow(
                                  color: WidgetStateProperty.resolveWith((_) {
                                    return i.isEven
                                        ? Colors.white
                                        : Colors.grey.shade100;
                                  }),
                                  cells: [
                                    DataCell(Text(partRows[i].$1)),
                                    DataCell(Text(partRows[i].$2)),
                                    DataCell(Text('${partRows[i].$3}')),
                                    DataCell(Text(
                                      AppFormatters.formatLira(partRows[i].$4),
                                    )),
                                  ],
                                ),
                            ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Mevcut stok durumu (rapordaki parçalar)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryNavy,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final row in partRows)
                        _stockBadgeForPart(
                          row.$1,
                          byName,
                          byId,
                          records,
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

  Widget _stockBadgeForPart(
    String partName,
    Map<String, InventoryItem> byName,
    Map<String, InventoryItem> byId,
    List<ServiceRecord> records,
  ) {
    InventoryItem? match = byName[partName];
    match ??= () {
      for (final r in records) {
        for (final p in r.parts) {
          if (p.partName == partName) {
            return byId[p.partId];
          }
        }
      }
      return null;
    }();

    final label =
        match != null ? '${match.name}: ${match.quantity} adet' : '$partName: —';
    final critical =
        match != null && match.quantity <= match.minStockAlert;

    return Chip(
      label: Text(label),
      backgroundColor:
          critical ? Colors.red.shade50 : Colors.blueGrey.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      avatar: critical
          ? const CircleAvatar(
              backgroundColor: Colors.red,
              radius: 8,
              child: Icon(Icons.priority_high, color: Colors.white, size: 12),
            )
          : null,
    );
  }
}

// —— Sekme: Teknisyen —— //

class _TechnicianTab extends StatelessWidget {
  const _TechnicianTab({
    required this.recordsFuture,
    required this.onRetry,
    required this.onPdf,
  });

  final Future<List<ServiceRecord>> recordsFuture;
  final VoidCallback onRetry;
  final Future<void> Function() onPdf;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ServiceRecord>>(
      future: recordsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _TabError(message: '${snapshot.error}', onRetry: onRetry);
        }
        final records = snapshot.data ?? [];
        if (records.isEmpty) {
          return const _EmptyTabMessage();
        }

        final rows = ReportsPdfExport.technicianRows(records);

        return Scrollbar(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => onPdf(),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Teknisyen raporu PDF\'i al'),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    AppColors.primaryNavy.withValues(alpha: 0.12),
                  ),
                  columns: const [
                    DataColumn(label: Text('Teknisyen')),
                    DataColumn(label: Text('Servis Sayısı')),
                    DataColumn(label: Text('Toplam Ciro')),
                    DataColumn(label: Text('Ortalama Tutar')),
                    DataColumn(label: Text('En Yoğun Gün')),
                  ],
                  rows: [
                    for (var i = 0; i < rows.length; i++)
                      DataRow(
                        color: WidgetStateProperty.resolveWith((_) {
                          return i.isEven
                              ? Colors.white
                              : Colors.grey.shade100;
                        }),
                        cells: [
                          DataCell(Text(rows[i].$1)),
                          DataCell(Text('${rows[i].$2}')),
                          DataCell(Text(
                            AppFormatters.formatLira(rows[i].$3),
                          )),
                          DataCell(Text(
                            AppFormatters.formatLira(rows[i].$4),
                          )),
                          DataCell(Text(rows[i].$5)),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// —— Ortak —— //

class _EmptyTabMessage extends StatelessWidget {
  const _EmptyTabMessage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Bu tarih aralığında kayıt bulunamadı.'),
    );
  }
}

class _TabError extends StatelessWidget {
  const _TabError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade800),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Yeniden dene'),
            ),
          ],
        ),
      ),
    );
  }
}
