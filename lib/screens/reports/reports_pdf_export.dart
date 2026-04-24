import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:otoservis_app/models/inventory_item.dart';
import 'package:otoservis_app/models/service_record.dart';
import 'package:otoservis_app/models/vehicle.dart';
import 'package:otoservis_app/utils/formatters.dart';
import 'package:otoservis_app/utils/constants.dart';
import 'package:otoservis_app/utils/pdf_branding.dart';

/// PDF yardımcıları — Roboto fontları [PdfBranding.loadBundle] ile yüklenir.
abstract final class ReportsPdfExport {
  static final PdfColor _totalBoxColor = PdfColor.fromHex('121212');

  static pw.Widget _footer(pw.Context context, PdfBrandingBundle bundle) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          pdfServiceTagline,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            font: bundle.regular,
            fontSize: 9,
            color: PdfColor.fromHex('424242'),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Sayfa ${context.pageNumber} / ${context.pagesCount}',
            style: pw.TextStyle(
              font: bundle.regular,
              fontSize: 8,
              color: PdfColors.grey700,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _rangeSubtitle(
    PdfBrandingBundle bundle,
    DateTime start,
    DateTime end,
  ) {
    final fmt = DateFormat('d MMMM yyyy', 'tr_TR');
    return pw.Text(
      '${fmt.format(start)} — ${fmt.format(end)}',
      style: pw.TextStyle(font: bundle.regular, fontSize: 10),
    );
  }

  static pw.Widget _reportHeader(
    PdfBrandingBundle bundle,
    String title,
    DateTime date,
  ) {
    return PdfBranding.buildPremiumHeader(
      bundle: bundle,
      title: title.toUpperCase(),
      date: date,
    );
  }

  static pw.Widget _sectionTitle(PdfBrandingBundle bundle, String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        font: bundle.bold,
        fontSize: 14,
        color: PdfBranding.navy,
      ),
    );
  }

  static pw.TableRow _headerRow(List<String> cells, PdfBrandingBundle bundle) {
    final style = pw.TextStyle(
      font: bundle.bold,
      color: PdfColors.white,
      fontSize: 8.5,
    );
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: PdfBranding.navy),
      children:
          cells
              .map(
                (c) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 6,
                  ),
                  child: pw.Text(c, style: style),
                ),
              )
              .toList(),
    );
  }

  static pw.TableRow _dataRow(
    List<String> cells,
    PdfBrandingBundle bundle,
    int index,
  ) {
    final bodyStyle = pw.TextStyle(font: bundle.regular, fontSize: 8);
    final bg = index.isEven ? PdfColors.white : PdfBranding.zebra;
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: bg),
      children:
          cells
              .map(
                (c) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 5,
                  ),
                  child: pw.Text(c, style: bodyStyle),
                ),
              )
              .toList(),
    );
  }

  static pw.Widget _totalsBox(
    PdfBrandingBundle bundle,
    NumberFormat moneyFmt,
    List<(String label, double value)> lines,
    String grandLabel,
    double grandValue,
  ) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _totalBoxColor,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          for (final line in lines)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    '${line.$1}: ',
                    style: pw.TextStyle(
                      font: bundle.regular,
                      fontSize: 10,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    moneyFmt.format(line.$2),
                    style: pw.TextStyle(
                      font: bundle.bold,
                      fontSize: 10,
                      color: PdfBranding.gold,
                    ),
                  ),
                ],
              ),
            ),
          pw.Divider(color: PdfColors.white),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                '$grandLabel ',
                style: pw.TextStyle(
                  font: bundle.bold,
                  fontSize: 12,
                  color: PdfColors.white,
                ),
              ),
              pw.Text(
                moneyFmt.format(grandValue),
                style: pw.TextStyle(
                  font: bundle.bold,
                  fontSize: 14,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<Uint8List> buildRevenuePdf({
    required DateTime start,
    required DateTime end,
    required List<ServiceRecord> records,
  }) async {
    final bundle = await PdfBranding.loadBundle();
    final doc = pw.Document(theme: bundle.theme);
    final moneyFmt = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 2,
    );
    final rows = [...records]..sort((a, b) => a.date.compareTo(b.date));

    double partsSum(ServiceRecord r) =>
        r.parts.fold(0.0, (s, p) => s + p.totalPrice);
    double laborSum(ServiceRecord r) =>
        r.laborItems.fold(0.0, (s, l) => s + l.price);

    final totalKdv = rows.fold<double>(0, (a, r) => a + r.kdvAmount);
    final totalExcl = rows.fold<double>(0, (a, r) => a + r.subtotal);
    final totalGrand = rows.fold<double>(0, (a, r) => a + r.grandTotal);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: bundle.theme,
        footer: (c) => _footer(c, bundle),
        build: (context) {
          return [
            _reportHeader(bundle, 'Gelir Raporu', end),
            pw.SizedBox(height: 10),
            _rangeSubtitle(bundle, start, end),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfBranding.border, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(72),
                1: const pw.FixedColumnWidth(52),
                2: const pw.FixedColumnWidth(72),
                3: const pw.FixedColumnWidth(52),
                4: const pw.FixedColumnWidth(52),
                5: const pw.FixedColumnWidth(44),
                6: const pw.FixedColumnWidth(52),
              },
              children: [
                _headerRow([
                  'Tarih',
                  'Plaka',
                  'Teknisyen',
                  'Parça Top.',
                  'İşçilik',
                  'KDV',
                  'Genel Top.',
                ], bundle),
                for (var i = 0; i < rows.length; i++)
                  _dataRow(
                    [
                      DateFormat('d.MM.yyyy', 'tr_TR').format(rows[i].date),
                      AppFormatters.formatPlateDisplay(rows[i].vehiclePlate),
                      rows[i].technicianName,
                      moneyFmt.format(partsSum(rows[i])),
                      moneyFmt.format(laborSum(rows[i])),
                      moneyFmt.format(rows[i].kdvAmount),
                      moneyFmt.format(rows[i].grandTotal),
                    ],
                    bundle,
                    i,
                  ),
              ],
            ),
            pw.SizedBox(height: 16),
            _totalsBox(
              bundle,
              moneyFmt,
              [
                ('Toplam KDV tutarı', totalKdv),
                ('KDV hariç toplam', totalExcl),
              ],
              'Genel toplam',
              totalGrand,
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  static Future<Uint8List> buildVehiclePdf({
    required DateTime start,
    required DateTime end,
    required List<
      (String plate, String owner, int count, double spend, DateTime last)
    >
    rows,
  }) async {
    final bundle = await PdfBranding.loadBundle();
    final doc = pw.Document(theme: bundle.theme);
    final moneyFmt = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 2,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: bundle.theme,
        footer: (c) => _footer(c, bundle),
        build: (context) {
          return [
            _reportHeader(bundle, 'Araç Raporu', end),
            pw.SizedBox(height: 10),
            _rangeSubtitle(bundle, start, end),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfBranding.border, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(28),
                1: const pw.FixedColumnWidth(52),
                2: const pw.FixedColumnWidth(72),
                3: const pw.FixedColumnWidth(52),
                4: const pw.FixedColumnWidth(56),
                5: const pw.FixedColumnWidth(72),
              },
              children: [
                _headerRow([
                  'Sıra',
                  'Plaka',
                  'Araç Sahibi',
                  'Servis',
                  'Toplam',
                  'Son Servis',
                ], bundle),
                for (var i = 0; i < rows.length; i++)
                  _dataRow(
                    [
                      '${i + 1}',
                      AppFormatters.formatPlateDisplay(rows[i].$1),
                      rows[i].$2,
                      '${rows[i].$3}',
                      moneyFmt.format(rows[i].$4),
                      DateFormat('d.MM.yyyy', 'tr_TR').format(rows[i].$5),
                    ],
                    bundle,
                    i,
                  ),
              ],
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  /// Stok hareket PDF’inde filtre açıklaması (aralık satırının altı).
  static String stockMovementFilterCaption({
    required bool includeStok,
    required bool includeHarici,
  }) {
    if (includeStok && includeHarici) {
      return 'Hareket kapsamı: Stok parçaları + Harici (manuel) parçalar';
    }
    if (includeStok) {
      return 'Hareket kapsamı: Yalnızca stoktan düşen parçalar';
    }
    if (includeHarici) {
      return 'Hareket kapsamı: Yalnızca harici (manuel) parçalar';
    }
    return 'Hareket kapsamı: —';
  }

  static Future<Uint8List> buildStockPdf({
    required DateTime start,
    required DateTime end,
    required List<(String name, String category, int qty, double total)>
    partRows,
    required List<InventoryItem> criticalItems,
    String? movementFilterCaption,
  }) async {
    final bundle = await PdfBranding.loadBundle();
    final doc = pw.Document(theme: bundle.theme);
    final moneyFmt = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 2,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: bundle.theme,
        footer: (c) => _footer(c, bundle),
        build: (context) {
          return [
            _reportHeader(bundle, 'Stok Hareket Raporu', end),
            pw.SizedBox(height: 10),
            _rangeSubtitle(bundle, start, end),
            if (movementFilterCaption != null &&
                movementFilterCaption.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                movementFilterCaption,
                style: pw.TextStyle(
                  font: bundle.regular,
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ],
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfBranding.border, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FixedColumnWidth(48),
                3: const pw.FixedColumnWidth(56),
              },
              children: [
                _headerRow([
                  'Parça Adı',
                  'Kategori',
                  'Adet',
                  'Toplam Tutar',
                ], bundle),
                if (partRows.isEmpty)
                  _dataRow(
                    const [
                      'Seçilen filtreye uygun parça hareketi yok.',
                      '—',
                      '—',
                      '—',
                    ],
                    bundle,
                    0,
                  )
                else
                  for (var i = 0; i < partRows.length; i++)
                    _dataRow(
                      [
                        partRows[i].$1,
                        partRows[i].$2,
                        '${partRows[i].$3}',
                        moneyFmt.format(partRows[i].$4),
                      ],
                      bundle,
                      i,
                    ),
              ],
            ),
            pw.SizedBox(height: 14),
            _sectionTitle(bundle, 'Kritik stok uyarısı'),
            pw.SizedBox(height: 6),
            if (criticalItems.isEmpty)
              pw.Text(
                'Kritik seviyede parça yok.',
                style: pw.TextStyle(font: bundle.regular, fontSize: 9),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfBranding.border,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FixedColumnWidth(44),
                  2: const pw.FixedColumnWidth(44),
                },
                children: [
                  _headerRow(['Parça', 'Mevcut', 'Minimum'], bundle),
                  for (var i = 0; i < criticalItems.length; i++)
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color:
                            i.isEven
                                ? PdfColors.white
                                : PdfBranding.criticalRow,
                      ),
                      children: [
                        _cellText(criticalItems[i].name, bundle, bold: false),
                        _cellText(
                          '${criticalItems[i].quantity}',
                          bundle,
                          bold: true,
                        ),
                        _cellText(
                          '${criticalItems[i].minStockAlert}',
                          bundle,
                          bold: false,
                        ),
                      ],
                    ),
                ],
              ),
          ];
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _cellText(
    String t,
    PdfBrandingBundle bundle, {
    required bool bold,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: pw.Text(
        t,
        style: pw.TextStyle(
          font: bold ? bundle.bold : bundle.regular,
          fontSize: 8,
        ),
      ),
    );
  }

  static Future<Uint8List> buildTechnicianPdf({
    required DateTime start,
    required DateTime end,
    required List<
      (String name, int services, double revenue, double avg, String busiestDay)
    >
    rows,
  }) async {
    final bundle = await PdfBranding.loadBundle();
    final doc = pw.Document(theme: bundle.theme);
    final moneyFmt = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 2,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: bundle.theme,
        footer: (c) => _footer(c, bundle),
        build: (context) {
          return [
            _reportHeader(bundle, 'Teknisyen Raporu', end),
            pw.SizedBox(height: 10),
            _rangeSubtitle(bundle, start, end),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfBranding.border, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.5),
                1: const pw.FixedColumnWidth(44),
                2: const pw.FixedColumnWidth(56),
                3: const pw.FixedColumnWidth(56),
                4: const pw.FlexColumnWidth(2),
              },
              children: [
                _headerRow([
                  'Teknisyen',
                  'Servis',
                  'Toplam Ciro',
                  'Ort. Tutar',
                  'En Yoğun Gün',
                ], bundle),
                for (var i = 0; i < rows.length; i++)
                  _dataRow(
                    [
                      rows[i].$1,
                      '${rows[i].$2}',
                      moneyFmt.format(rows[i].$3),
                      moneyFmt.format(rows[i].$4),
                      rows[i].$5,
                    ],
                    bundle,
                    i,
                  ),
              ],
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  /// Çok sayfalı tek PDF: dört bölümü tek [pw.Document] içinde üretir.
  static Future<Uint8List> buildFullReportPdfCombined({
    required DateTime start,
    required DateTime end,
    required List<ServiceRecord> records,
    required Map<String, Vehicle> vehiclesByPlate,
    required List<InventoryItem> allInventory,
  }) async {
    final bundle = await PdfBranding.loadBundle();
    final doc = pw.Document(theme: bundle.theme);
    final moneyFmt = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 2,
    );

    // --- 1. Gelir ---
    double partsSum(ServiceRecord r) =>
        r.parts.fold(0.0, (s, p) => s + p.totalPrice);
    double laborSum(ServiceRecord r) =>
        r.laborItems.fold(0.0, (s, l) => s + l.price);
    final sorted = [...records]..sort((a, b) => a.date.compareTo(b.date));
    final totalKdv = sorted.fold<double>(0, (a, r) => a + r.kdvAmount);
    final totalExcl = sorted.fold<double>(0, (a, r) => a + r.subtotal);
    final totalGrand = sorted.fold<double>(0, (a, r) => a + r.grandTotal);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: bundle.theme,
        footer: (c) => _footer(c, bundle),
        build:
            (context) => [
              _reportHeader(bundle, 'Gelir Raporu', end),
              pw.SizedBox(height: 10),
              _rangeSubtitle(bundle, start, end),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfBranding.border,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FixedColumnWidth(72),
                  1: const pw.FixedColumnWidth(52),
                  2: const pw.FixedColumnWidth(72),
                  3: const pw.FixedColumnWidth(52),
                  4: const pw.FixedColumnWidth(52),
                  5: const pw.FixedColumnWidth(44),
                  6: const pw.FixedColumnWidth(52),
                },
                children: [
                  _headerRow([
                    'Tarih',
                    'Plaka',
                    'Teknisyen',
                    'Parça Top.',
                    'İşçilik',
                    'KDV',
                    'Genel Top.',
                  ], bundle),
                  for (var i = 0; i < sorted.length; i++)
                    _dataRow(
                      [
                        DateFormat('d.MM.yyyy', 'tr_TR').format(sorted[i].date),
                        AppFormatters.formatPlateDisplay(
                          sorted[i].vehiclePlate,
                        ),
                        sorted[i].technicianName,
                        moneyFmt.format(partsSum(sorted[i])),
                        moneyFmt.format(laborSum(sorted[i])),
                        moneyFmt.format(sorted[i].kdvAmount),
                        moneyFmt.format(sorted[i].grandTotal),
                      ],
                      bundle,
                      i,
                    ),
                ],
              ),
              pw.SizedBox(height: 16),
              _totalsBox(
                bundle,
                moneyFmt,
                [
                  ('Toplam KDV tutarı', totalKdv),
                  ('KDV hariç toplam', totalExcl),
                ],
                'Genel toplam',
                totalGrand,
              ),
            ],
      ),
    );

    final vehicleRows = vehicleRowsFromRecords(records, vehiclesByPlate);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: bundle.theme,
        footer: (c) => _footer(c, bundle),
        build:
            (context) => [
              _reportHeader(bundle, 'Araç Raporu', end),
              pw.SizedBox(height: 10),
              _rangeSubtitle(bundle, start, end),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfBranding.border,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FixedColumnWidth(28),
                  1: const pw.FixedColumnWidth(52),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FixedColumnWidth(48),
                  4: const pw.FixedColumnWidth(56),
                  5: const pw.FixedColumnWidth(72),
                },
                children: [
                  _headerRow([
                    'Sıra',
                    'Plaka',
                    'Araç Sahibi',
                    'Servis',
                    'Toplam',
                    'Son Servis',
                  ], bundle),
                  for (var i = 0; i < vehicleRows.length; i++)
                    _dataRow(
                      [
                        '${i + 1}',
                        AppFormatters.formatPlateDisplay(vehicleRows[i].$1),
                        vehicleRows[i].$2,
                        '${vehicleRows[i].$3}',
                        moneyFmt.format(vehicleRows[i].$4),
                        DateFormat(
                          'd.MM.yyyy',
                          'tr_TR',
                        ).format(vehicleRows[i].$5),
                      ],
                      bundle,
                      i,
                    ),
                ],
              ),
            ],
      ),
    );

    final partAgg = aggregateParts(records, allInventory);
    final critical =
        allInventory.where((e) => e.quantity <= e.minStockAlert).toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: bundle.theme,
        footer: (c) => _footer(c, bundle),
        build:
            (context) => [
              _reportHeader(bundle, 'Stok Hareket Raporu', end),
              pw.SizedBox(height: 10),
              _rangeSubtitle(bundle, start, end),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfBranding.border,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FixedColumnWidth(48),
                  3: const pw.FixedColumnWidth(56),
                },
                children: [
                  _headerRow([
                    'Parça Adı',
                    'Kategori',
                    'Adet',
                    'Toplam Tutar',
                  ], bundle),
                  for (var i = 0; i < partAgg.length; i++)
                    _dataRow(
                      [
                        partAgg[i].$1,
                        partAgg[i].$2,
                        '${partAgg[i].$3}',
                        moneyFmt.format(partAgg[i].$4),
                      ],
                      bundle,
                      i,
                    ),
                ],
              ),
              pw.SizedBox(height: 14),
              _sectionTitle(bundle, 'Kritik stok uyarısı'),
              pw.SizedBox(height: 6),
              if (critical.isEmpty)
                pw.Text(
                  'Kritik seviyede parça yok.',
                  style: pw.TextStyle(font: bundle.regular, fontSize: 9),
                )
              else
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfBranding.border,
                    width: 0.5,
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FixedColumnWidth(44),
                    2: const pw.FixedColumnWidth(44),
                  },
                  children: [
                    _headerRow(['Parça', 'Mevcut', 'Minimum'], bundle),
                    for (var i = 0; i < critical.length; i++)
                      pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color:
                              i.isEven
                                  ? PdfColors.white
                                  : PdfBranding.criticalRow,
                        ),
                        children: [
                          _cellText(critical[i].name, bundle, bold: false),
                          _cellText(
                            '${critical[i].quantity}',
                            bundle,
                            bold: true,
                          ),
                          _cellText(
                            '${critical[i].minStockAlert}',
                            bundle,
                            bold: false,
                          ),
                        ],
                      ),
                  ],
                ),
            ],
      ),
    );

    final techRows = technicianRows(records);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: bundle.theme,
        footer: (c) => _footer(c, bundle),
        build:
            (context) => [
              _reportHeader(bundle, 'Teknisyen Raporu', end),
              pw.SizedBox(height: 10),
              _rangeSubtitle(bundle, start, end),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfBranding.border,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2.5),
                  1: const pw.FixedColumnWidth(44),
                  2: const pw.FixedColumnWidth(56),
                  3: const pw.FixedColumnWidth(56),
                  4: const pw.FlexColumnWidth(2),
                },
                children: [
                  _headerRow([
                    'Teknisyen',
                    'Servis',
                    'Toplam Ciro',
                    'Ort. Tutar',
                    'En Yoğun Gün',
                  ], bundle),
                  for (var i = 0; i < techRows.length; i++)
                    _dataRow(
                      [
                        techRows[i].$1,
                        '${techRows[i].$2}',
                        moneyFmt.format(techRows[i].$3),
                        moneyFmt.format(techRows[i].$4),
                        techRows[i].$5,
                      ],
                      bundle,
                      i,
                    ),
                ],
              ),
            ],
      ),
    );

    return doc.save();
  }

  /// Ekran tabloları ile aynı satır üretimi.
  static List<
    (String plate, String owner, int count, double spend, DateTime last)
  >
  vehicleRowsFromRecords(
    List<ServiceRecord> records,
    Map<String, Vehicle> vehiclesByPlate,
  ) {
    final map = <String, ({int c, double s, DateTime last})>{};
    for (final r in records) {
      final p = AppFormatters.normalizePlate(r.vehiclePlate);
      final cur = map[p];
      final last = cur == null || r.date.isAfter(cur.last) ? r.date : cur.last;
      map[p] = (
        c: (cur?.c ?? 0) + 1,
        s: (cur?.s ?? 0) + r.grandTotal,
        last: last,
      );
    }
    final list =
        map.entries.map((e) {
          final v = vehiclesByPlate[e.key];
          final owner = v?.ownerName ?? '—';
          return (e.key, owner, e.value.c, e.value.s, e.value.last);
        }).toList();
    list.sort((a, b) => b.$3.compareTo(a.$3));
    return list;
  }

  static List<(String name, String category, int qty, double total)>
  aggregateParts(
    List<ServiceRecord> records,
    List<InventoryItem> inventory, {
    bool includeStok = true,
    bool includeHarici = true,
  }) {
    final byId = {for (final i in inventory) i.id: i};
    final byName = <String, InventoryItem>{};
    for (final i in inventory) {
      byName.putIfAbsent(i.name, () => i);
    }

    final agg = <String, ({int q, double t, String cat})>{};
    for (final r in records) {
      for (final pt in r.parts) {
        if (pt.isManual) {
          if (!includeHarici) continue;
        } else {
          if (!includeStok) continue;
        }
        final inv = pt.isManual
            ? null
            : (byId[pt.partId] ?? byName[pt.partName]);
        final cat = pt.isManual ? 'Harici' : (inv?.category ?? '—');
        final prev = agg[pt.partName];
        final resolvedCat = (prev != null && prev.cat != '—') ? prev.cat : cat;
        agg[pt.partName] = (
          q: (prev?.q ?? 0) + pt.quantity,
          t: (prev?.t ?? 0) + pt.totalPrice,
          cat: resolvedCat,
        );
      }
    }
    final out =
        agg.entries
            .map((e) => (e.key, e.value.cat, e.value.q, e.value.t))
            .toList();
    out.sort((a, b) => b.$4.compareTo(a.$4));
    return out;
  }

  static List<
    (String name, int services, double revenue, double avg, String busiestDay)
  >
  technicianRows(List<ServiceRecord> records) {
    final byTech = <String, ({int n, double rev, Map<DateTime, int> days})>{};
    for (final r in records) {
      final name = r.technicianName.trim().isEmpty ? '—' : r.technicianName;
      final day = DateTime(r.date.year, r.date.month, r.date.day);
      final prev = byTech[name];
      final days = prev?.days ?? {};
      days[day] = (days[day] ?? 0) + 1;
      byTech[name] = (
        n: (prev?.n ?? 0) + 1,
        rev: (prev?.rev ?? 0) + r.grandTotal,
        days: days,
      );
    }
    final fmt = DateFormat('d MMMM yyyy', 'tr_TR');
    final out = <(String, int, double, double, String)>[];
    for (final e in byTech.entries) {
      final days = e.value.days;
      DateTime? bestDay;
      var bestC = 0;
      for (final d in days.entries) {
        if (d.value > bestC) {
          bestC = d.value;
          bestDay = d.key;
        }
      }
      final busiest = bestDay != null ? fmt.format(bestDay) : '—';
      final avg = e.value.n > 0 ? e.value.rev / e.value.n : 0.0;
      out.add((e.key, e.value.n, e.value.rev, avg, busiest));
    }
    out.sort((a, b) => b.$3.compareTo(a.$3));
    return out;
  }
}
