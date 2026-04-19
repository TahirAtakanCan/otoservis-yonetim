import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:otoservis_app/models/inventory_item.dart';
import 'package:otoservis_app/providers/inventory_provider.dart';
import 'package:otoservis_app/utils/constants.dart';
import 'package:otoservis_app/utils/formatters.dart';
import 'package:otoservis_app/utils/pdf_branding.dart';
import 'package:otoservis_app/widgets/common/app_error_banner.dart';
import 'package:otoservis_app/widgets/common/app_sidebar.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();
  String? _categoryFilter;
  bool _reportBusy = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<InventoryItem> _filtered(List<InventoryItem> all) {
    final q = _searchController.text.trim().toLowerCase();
    return all.where((e) {
      if (_categoryFilter != null && e.category != _categoryFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return e.name.toLowerCase().contains(q);
    }).toList();
  }

  Color? _rowColor(InventoryItem i) {
    if (i.quantity == 0) return Colors.red.shade50;
    if (i.minStockAlert > 0 && i.quantity <= i.minStockAlert) {
      return Colors.orange.shade50;
    }
    return null;
  }

  Future<void> _showPartForm({InventoryItem? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final qtyCtrl = TextEditingController(
      text: existing != null ? '${existing.quantity}' : '',
    );
    final priceCtrl = TextEditingController(
      text: existing != null ? existing.unitPrice.toString() : '',
    );
    final minCtrl = TextEditingController(
      text: existing != null ? '${existing.minStockAlert}' : '',
    );
    var category = existing?.category ?? PartCategories.all.first;
    if (existing != null && !PartCategories.all.contains(existing.category)) {
      category = 'Diğer';
    }
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(existing == null ? 'Yeni parça' : 'Parça düzenle'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Parça adı',
                      border: OutlineInputBorder(),
                    ),
                    validator:
                        (v) =>
                            (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
                  ),
                  const SizedBox(height: 12),
                  StatefulBuilder(
                    builder: (context, setLocal) {
                      return DropdownButtonFormField<String>(
                        value: category,
                        decoration: const InputDecoration(
                          labelText: 'Kategori',
                          border: OutlineInputBorder(),
                        ),
                        items:
                            PartCategories.all
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) {
                          if (v != null) setLocal(() => category = v);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText:
                          existing == null
                              ? 'Başlangıç miktarı'
                              : 'Stok miktarı',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Zorunlu';
                      final n = int.tryParse(v.trim());
                      if (n == null || n < 0) return 'Geçerli miktar';
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
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Zorunlu';
                      final p =
                          double.tryParse(v.trim().replaceAll(',', '.')) ?? -1;
                      if (p < 0) return 'Geçerli fiyat';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: minCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Minimum stok uyarı miktarı',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Zorunlu';
                      final n = int.tryParse(v.trim());
                      if (n == null || n < 0) return 'Geçerli değer';
                      return null;
                    },
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
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    if (ok != true || !mounted) {
      nameCtrl.dispose();
      qtyCtrl.dispose();
      priceCtrl.dispose();
      minCtrl.dispose();
      return;
    }

    final inv = context.read<InventoryProvider>();
    final qty = int.parse(qtyCtrl.text.trim());
    final price = double.parse(priceCtrl.text.trim().replaceAll(',', '.'));
    final minS = int.parse(minCtrl.text.trim());

    try {
      if (existing == null) {
        await inv.createItem(
          name: nameCtrl.text,
          category: category.trim(),
          quantity: qty,
          unitPrice: price,
          minStockAlert: minS,
        );
      } else {
        await inv.updateItem(
          existing.copyWith(
            name: nameCtrl.text.trim(),
            category: category,
            quantity: qty,
            unitPrice: price,
            minStockAlert: minS,
            updatedAt: DateTime.now(),
          ),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Kaydedildi.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      nameCtrl.dispose();
      qtyCtrl.dispose();
      priceCtrl.dispose();
      minCtrl.dispose();
    }
  }

  Future<void> _confirmDelete(InventoryItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Parçayı sil'),
            content: Text('"${item.name}" silinsin mi?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('İptal'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Sil'),
              ),
            ],
          ),
    );
    if (ok != true || !mounted) return;

    try {
      await context.read<InventoryProvider>().deleteItem(item.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Silindi.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _showStockEntry() async {
    final inv = context.read<InventoryProvider>();
    final items = inv.allItems;
    if (items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Önce parça ekleyin.')));
      return;
    }

    var selected = items.first;
    final qtyCtrl = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Stok girişi'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatefulBuilder(
                  builder: (context, setLocal) {
                    return DropdownButtonFormField<InventoryItem>(
                      value: selected,
                      decoration: const InputDecoration(
                        labelText: 'Parça',
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items:
                          items
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                    '${e.name} (stok: ${e.quantity})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (v) {
                        if (v != null) setLocal(() => selected = v);
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Eklenecek miktar',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Zorunlu';
                    final n = int.tryParse(v.trim());
                    if (n == null || n < 1) return 'En az 1';
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
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    final addQty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
    qtyCtrl.dispose();

    if (ok != true || !mounted) return;

    try {
      await inv.addStockTransaction(itemId: selected.id, addQuantity: addQty);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Stok güncellendi.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _showReportTypeDialog() async {
    final reportType = await showDialog<_InventoryReportType>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Rapor Al'),
            content: const Text(
              'Lütfen oluşturmak istediğiniz rapor türünü seçin.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal'),
              ),
              OutlinedButton(
                onPressed:
                    () => Navigator.pop(ctx, _InventoryReportType.criticalOnly),
                child: const Text('Kritik Stok Raporu'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, _InventoryReportType.all),
                child: const Text('Tüm Stok Raporu'),
              ),
            ],
          ),
    );

    if (!mounted || reportType == null) return;
    await _generateStockReport(reportType);
  }

  Future<void> _generateStockReport(_InventoryReportType reportType) async {
    if (_reportBusy) return;

    setState(() => _reportBusy = true);
    try {
      final snap =
          await FirebaseFirestore.instance
              .collection(FirestoreCollections.inventory)
              .orderBy('name')
              .get();

      final allItems =
          snap.docs
              .map((d) => InventoryItem.fromMap({...d.data(), 'id': d.id}))
              .toList();

      final criticalOnly = reportType == _InventoryReportType.criticalOnly;
      final rows =
          criticalOnly
              ? allItems
                  .where((i) => i.quantity <= i.minStockAlert)
                  .toList(growable: false)
              : allItems;

      final totalStockValue = rows.fold<double>(
        0,
        (total, item) => total + (item.quantity * item.unitPrice),
      );

      final branding = await PdfBranding.loadBundle();
      final doc = pw.Document(theme: branding.theme);
      final title = criticalOnly ? 'KRİTİK STOK RAPORU' : 'STOK RAPORU';

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pdfContext) {
            return [
              PdfBranding.buildPremiumHeader(
                bundle: branding,
                title: title,
                date: DateTime.now(),
              ),
              pw.SizedBox(height: 14),
              if (rows.isEmpty)
                pw.Text(
                  'Rapor kriterine uyan stok kaydı bulunamadı.',
                  style: pw.TextStyle(font: branding.regular, fontSize: 10),
                )
              else
                _buildStockTablePdf(
                  rows,
                  criticalOnly: criticalOnly,
                  branding: branding,
                ),
              pw.SizedBox(height: 12),
              _buildStockTotalBlock(
                totalStockValue: totalStockValue,
                branding: branding,
              ),
              pw.SizedBox(height: 14),
              PdfBranding.buildPremiumFooter(branding),
            ];
          },
        ),
      );

      final bytes = await doc.save();
      final prefix = criticalOnly ? 'kritik_stok_raporu' : 'stok_raporu';
      final filename = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (kIsWeb) {
        if (!mounted) return;
        await _showWebReportReadyDialog(bytes: bytes, filename: filename);
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      await _showReportReadyDialog(file: file, bytes: bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Rapor oluşturulurken hata: $e')));
    } finally {
      if (mounted) {
        setState(() => _reportBusy = false);
      }
    }
  }

  Future<void> _showReportReadyDialog({
    required File file,
    required Uint8List bytes,
  }) async {
    await showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Rapor hazır'),
            content: Text('PDF kaydedildi:\n${file.path}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Kapat'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await Printing.layoutPdf(onLayout: (_) async => bytes);
                },
                icon: const Icon(Icons.print),
                label: const Text('Yazdır'),
              ),
            ],
          ),
    );
  }

  Future<void> _showWebReportReadyDialog({
    required Uint8List bytes,
    required String filename,
  }) async {
    await showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Rapor hazır'),
            content: const Text(
              'Web ortamında dosya uygulama dizinine kaydedilemez. PDF indirme veya yazdırma seçebilirsiniz.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Kapat'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await Printing.sharePdf(bytes: bytes, filename: filename);
                },
                icon: const Icon(Icons.download_outlined),
                label: const Text('PDF İndir'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await Printing.layoutPdf(onLayout: (_) async => bytes);
                },
                icon: const Icon(Icons.print),
                label: const Text('Yazdır'),
              ),
            ],
          ),
    );
  }

  pw.Widget _buildStockTablePdf(
    List<InventoryItem> rows, {
    required bool criticalOnly,
    required PdfBrandingBundle branding,
  }) {
    final headerStyle = pw.TextStyle(
      font: branding.bold,
      fontSize: 10,
      color: PdfColors.white,
    );
    final bodyStyle = pw.TextStyle(font: branding.regular, fontSize: 9);
    final criticalBodyStyle = pw.TextStyle(
      font: branding.bold,
      fontSize: 9,
      color: PdfColors.red800,
    );

    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfBranding.border, width: 0.8),
      ),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfBranding.border, width: 0.6),
        columnWidths: {
          0: const pw.FlexColumnWidth(3.3),
          1: const pw.FlexColumnWidth(2),
          2: const pw.FlexColumnWidth(1.2),
          3: const pw.FlexColumnWidth(1.8),
          4: const pw.FlexColumnWidth(2),
        },
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: PdfBranding.navy),
            children: [
              _pdfCell('Parça Adı', headerStyle),
              _pdfCell('Kategori', headerStyle),
              _pdfCell('Miktar', headerStyle, alignRight: true),
              _pdfCell('Birim Fiyat', headerStyle, alignRight: true),
              _pdfCell('Toplam Değer', headerStyle, alignRight: true),
            ],
          ),
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final rowTotal = item.quantity * item.unitPrice;
            final isCritical = item.quantity <= item.minStockAlert;
            final showCritical = criticalOnly && isCritical;
            final textStyle = showCritical ? criticalBodyStyle : bodyStyle;
            final rowColor =
                showCritical
                    ? PdfBranding.criticalRow
                    : (index.isEven ? PdfColors.white : PdfBranding.zebra);

            return pw.TableRow(
              decoration: pw.BoxDecoration(color: rowColor),
              children: [
                _pdfCell(item.name, textStyle),
                _pdfCell(item.category, textStyle),
                _pdfCell('${item.quantity}', textStyle, alignRight: true),
                _pdfCell(
                  AppFormatters.formatLira(item.unitPrice),
                  textStyle,
                  alignRight: true,
                ),
                _pdfCell(
                  AppFormatters.formatLira(rowTotal),
                  textStyle,
                  alignRight: true,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  pw.Widget _buildStockTotalBlock({
    required double totalStockValue,
    required PdfBrandingBundle branding,
  }) {
    final totalText = AppFormatters.formatLira(totalStockValue);
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfBranding.zebra,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfBranding.totalBorder, width: 1),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            'GENEL TOPLAM: ',
            style: pw.TextStyle(font: branding.bold, fontSize: 13),
          ),
          pw.Text(
            totalText,
            style: pw.TextStyle(
              font: branding.bold,
              fontSize: 16,
              color: PdfBranding.navy,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfCell(
    String text,
    pw.TextStyle style, {
    bool alignRight = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Align(
        alignment:
            alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(text, style: style),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryProvider>();
    final rows = _filtered(inv.allItems);

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSidebar(),
          Expanded(
            child: ColoredBox(
              color: AppColors.surfaceMuted,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final controls = Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: 280,
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Parça adına göre ara',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  prefixIcon: const Icon(Icons.search),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            SizedBox(
                              width: 200,
                              child: DropdownButtonFormField<String?>(
                                value: _categoryFilter,
                                decoration: InputDecoration(
                                  labelText: 'Kategori',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Tümü'),
                                  ),
                                  ...PartCategories.all.map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  ),
                                ],
                                onChanged:
                                    (v) => setState(() => _categoryFilter = v),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: () => _showPartForm(),
                              icon: const Icon(Icons.add, size: 20),
                              label: const Text('Yeni parça ekle'),
                            ),
                            OutlinedButton.icon(
                              onPressed:
                                  inv.inventoryLoading ? null : _showStockEntry,
                              icon: const Icon(
                                Icons.add_box_outlined,
                                size: 20,
                              ),
                              label: const Text('Stok girişi'),
                            ),
                          ],
                        );

                        final reportButton = FilledButton.icon(
                          onPressed: _reportBusy ? null : _showReportTypeDialog,
                          icon:
                              _reportBusy
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Icon(Icons.picture_as_pdf, size: 20),
                          label: const Text('Rapor Al'),
                        );

                        if (constraints.maxWidth > 1100) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: controls),
                              const SizedBox(width: 12),
                              reportButton,
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            controls,
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: reportButton,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child:
                        inv.inventoryLoading
                            ? const Center(child: CircularProgressIndicator())
                            : inv.inventoryError != null
                            ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: AppErrorBanner(
                                  message:
                                      'Stok listesi yüklenemedi: ${inv.inventoryError}',
                                  onRetry: () => inv.retryInventoryStream(),
                                ),
                              ),
                            )
                            : rows.isEmpty
                            ? const Center(
                              child: Text(
                                'Kayıt yok veya filtreye uyan parça yok.',
                                style: TextStyle(color: Colors.black54),
                              ),
                            )
                            : Scrollbar(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(
                                      Colors.grey.shade200,
                                    ),
                                    columns: const [
                                      DataColumn(label: Text('Parça adı')),
                                      DataColumn(label: Text('Kategori')),
                                      DataColumn(
                                        label: Text('Stok miktarı'),
                                        numeric: true,
                                      ),
                                      DataColumn(
                                        label: Text('Birim fiyat'),
                                        numeric: true,
                                      ),
                                      DataColumn(
                                        label: Text('Min. stok'),
                                        numeric: true,
                                      ),
                                      DataColumn(label: Text('İşlemler')),
                                    ],
                                    rows:
                                        rows.map((item) {
                                          final c = _rowColor(item);
                                          return DataRow(
                                            color:
                                                c != null
                                                    ? WidgetStateProperty.all(c)
                                                    : null,
                                            cells: [
                                              DataCell(Text(item.name)),
                                              DataCell(Text(item.category)),
                                              DataCell(
                                                Text(
                                                  '${item.quantity}',
                                                  style: TextStyle(
                                                    fontWeight:
                                                        item.quantity == 0
                                                            ? FontWeight.bold
                                                            : null,
                                                    color:
                                                        item.quantity == 0
                                                            ? Colors
                                                                .red
                                                                .shade900
                                                            : null,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  AppFormatters.formatLira(
                                                    item.unitPrice,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text('${item.minStockAlert}'),
                                              ),
                                              DataCell(
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      tooltip: 'Düzenle',
                                                      icon: const Icon(
                                                        Icons.edit_outlined,
                                                        size: 20,
                                                      ),
                                                      onPressed:
                                                          () => _showPartForm(
                                                            existing: item,
                                                          ),
                                                    ),
                                                    IconButton(
                                                      tooltip: 'Sil',
                                                      icon: Icon(
                                                        Icons.delete_outline,
                                                        size: 20,
                                                        color:
                                                            Colors.red.shade700,
                                                      ),
                                                      onPressed:
                                                          () => _confirmDelete(
                                                            item,
                                                          ),
                                                    ),
                                                  ],
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
            ),
          ),
        ],
      ),
    );
  }
}

enum _InventoryReportType { all, criticalOnly }
