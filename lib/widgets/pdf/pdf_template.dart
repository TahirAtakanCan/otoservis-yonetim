import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:otoservis_app/models/service_record.dart';
import 'package:otoservis_app/models/vehicle.dart';
import 'package:otoservis_app/utils/formatters.dart';
import 'package:otoservis_app/utils/pdf_branding.dart';

class PdfTemplate {
  static Future<Uint8List> buildServiceSlip({
    required ServiceRecord service,
    required Vehicle vehicle,
    int? previousKm,
    int? currentKm,
  }) async {
    final branding = await PdfBranding.loadBundle();
    final doc = pw.Document(theme: branding.theme);
    final moneyFmt = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 2,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 24),
        build: (_) {
          return [
            PdfBranding.buildPremiumHeader(
              bundle: branding,
              title: 'SERVİS FİŞİ',
              date: service.date,
            ),
            pw.SizedBox(height: 10),
            _buildMetaCard(service: service, branding: branding),
            pw.SizedBox(height: 12),
            _buildVehicleInfoCard(
              vehicle: vehicle,
              previousKm: previousKm,
              currentKm: currentKm,
              branding: branding,
            ),
            pw.SizedBox(height: 14),
            _buildPartsSection(
              parts: service.parts,
              moneyFmt: moneyFmt,
              branding: branding,
            ),
            pw.SizedBox(height: 12),
            _buildLaborSection(
              laborItems: service.laborItems,
              moneyFmt: moneyFmt,
              branding: branding,
            ),
            pw.SizedBox(height: 14),
            _buildTotalBlock(
              service: service,
              moneyFmt: moneyFmt,
              branding: branding,
            ),
            pw.SizedBox(height: 14),
            PdfBranding.buildPremiumFooter(branding),
          ];
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildMetaCard({
    required ServiceRecord service,
    required PdfBrandingBundle branding,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfBranding.zebra,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfBranding.border, width: 1),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _metaItem('Fiş No', service.id, branding),
          _metaItem('Teknisyen', service.technicianName, branding),
          _metaItem(
            'Kayıt Tarihi',
            DateFormat('dd MMMM yyyy', 'tr_TR').format(service.date),
            branding,
          ),
        ],
      ),
    );
  }

  static pw.Widget _metaItem(
    String label,
    String value,
    PdfBrandingBundle branding,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: branding.bold,
            fontSize: 9,
            color: PdfBranding.navy,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(font: branding.regular, fontSize: 9.5),
        ),
      ],
    );
  }

  static pw.Widget _buildVehicleInfoCard({
    required Vehicle vehicle,
    required int? previousKm,
    required int? currentKm,
    required PdfBrandingBundle branding,
  }) {
    String kmText(int? km) {
      if (km == null || km <= 0) return '—';
      return '${AppFormatters.formatKm(km)} km';
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfBranding.border, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Araç ve Müşteri Bilgileri',
            style: pw.TextStyle(
              font: branding.bold,
              fontSize: 12,
              color: PdfBranding.navy,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoLine('Plaka', vehicle.plate, branding),
                    _infoLine(
                      'Araç',
                      '${vehicle.brand} ${vehicle.model} ${vehicle.year}',
                      branding,
                    ),
                    _infoLine('Önceki KM', kmText(previousKm), branding),
                    _infoLine('Şu an KM', kmText(currentKm), branding),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoLine('Müşteri', vehicle.ownerName, branding),
                    _infoLine('Telefon', vehicle.ownerPhone, branding),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPartsSection({
    required List<ServicePart> parts,
    required NumberFormat moneyFmt,
    required PdfBrandingBundle branding,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Parçalar', branding),
        pw.SizedBox(height: 6),
        _partsTable(parts: parts, moneyFmt: moneyFmt, branding: branding),
      ],
    );
  }

  static pw.Widget _partsTable({
    required List<ServicePart> parts,
    required NumberFormat moneyFmt,
    required PdfBrandingBundle branding,
  }) {
    final headerStyle = pw.TextStyle(
      font: branding.bold,
      color: PdfColors.white,
      fontSize: 9.5,
    );
    final bodyStyle = pw.TextStyle(font: branding.regular, fontSize: 9);

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfBranding.navy),
        children: [
          _cell('Parça Adı', headerStyle, alignRight: false),
          _cell('Adet', headerStyle),
          _cell('Birim Fiyat', headerStyle),
          _cell('Toplam', headerStyle),
        ],
      ),
    ];

    if (parts.isEmpty) {
      rows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.white),
          children: [
            _cell('Parça kaydı yok', bodyStyle, alignRight: false),
            _cell('-', bodyStyle),
            _cell('-', bodyStyle),
            _cell('-', bodyStyle),
          ],
        ),
      );
    } else {
      for (var i = 0; i < parts.length; i++) {
        final part = parts[i];
        rows.add(
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isEven ? PdfColors.white : PdfBranding.zebra,
            ),
            children: [
              _cell(
                part.isManual
                    ? '${part.partName} (Harici)'
                    : part.partName,
                bodyStyle,
                alignRight: false,
              ),
              _cell('${part.quantity}', bodyStyle),
              _cell(moneyFmt.format(part.unitPrice), bodyStyle),
              _cell(moneyFmt.format(part.totalPrice), bodyStyle),
            ],
          ),
        );
      }
    }

    return _buildRoundedTable(
      rows: rows,
      columnWidths: const {
        0: pw.FlexColumnWidth(4),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(2),
      },
    );
  }

  static pw.Widget _buildLaborSection({
    required List<LaborItem> laborItems,
    required NumberFormat moneyFmt,
    required PdfBrandingBundle branding,
  }) {
    final headerStyle = pw.TextStyle(
      font: branding.bold,
      color: PdfColors.white,
      fontSize: 9.5,
    );
    final bodyStyle = pw.TextStyle(font: branding.regular, fontSize: 9);

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfBranding.navy),
        children: [
          _cell('İşçilik', headerStyle, alignRight: false),
          _cell('Tutar', headerStyle),
        ],
      ),
    ];

    if (laborItems.isEmpty) {
      rows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.white),
          children: [
            _cell('İşçilik kaydı yok', bodyStyle, alignRight: false),
            _cell('-', bodyStyle),
          ],
        ),
      );
    } else {
      for (var i = 0; i < laborItems.length; i++) {
        final labor = laborItems[i];
        rows.add(
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isEven ? PdfColors.white : PdfBranding.zebra,
            ),
            children: [
              _cell(labor.description, bodyStyle, alignRight: false),
              _cell(moneyFmt.format(labor.price), bodyStyle),
            ],
          ),
        );
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('İşçilikler', branding),
        pw.SizedBox(height: 6),
        _buildRoundedTable(
          rows: rows,
          columnWidths: const {
            0: pw.FlexColumnWidth(4),
            1: pw.FlexColumnWidth(2),
          },
        ),
      ],
    );
  }

  static pw.Widget _buildRoundedTable({
    required List<pw.TableRow> rows,
    required Map<int, pw.TableColumnWidth> columnWidths,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfBranding.border, width: 0.8),
      ),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfBranding.border, width: 0.6),
        columnWidths: columnWidths,
        children: rows,
      ),
    );
  }

  static pw.Widget _buildTotalBlock({
    required ServiceRecord service,
    required NumberFormat moneyFmt,
    required PdfBrandingBundle branding,
  }) {
    final totalText = AppFormatters.formatLira(service.grandTotal);

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfBranding.zebra,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfBranding.totalBorder, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          _totalLine('Ara Toplam', moneyFmt.format(service.subtotal), branding),
          if (service.kdvIncluded)
            _totalLine(
              'KDV (%${(service.kdvRate * 100).toStringAsFixed(0)})',
              moneyFmt.format(service.kdvAmount),
              branding,
            ),
          pw.SizedBox(height: 4),
          pw.Row(
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
        ],
      ),
    );
  }

  static pw.Widget _totalLine(
    String label,
    String value,
    PdfBrandingBundle branding,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            '$label: ',
            style: pw.TextStyle(font: branding.regular, fontSize: 10),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(font: branding.regular, fontSize: 10),
          ),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String text, PdfBrandingBundle branding) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        font: branding.bold,
        fontSize: 12,
        color: PdfBranding.navy,
      ),
    );
  }

  static pw.Widget _infoLine(
    String label,
    String value,
    PdfBrandingBundle branding,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(
        text: pw.TextSpan(
          style: pw.TextStyle(font: branding.regular, fontSize: 9.5),
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(font: branding.bold),
            ),
            pw.TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  static pw.Widget _cell(
    String text,
    pw.TextStyle style, {
    bool alignRight = true,
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
}
