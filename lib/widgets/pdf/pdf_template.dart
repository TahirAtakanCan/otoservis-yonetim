import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:otoservis_app/models/service_record.dart';
import 'package:otoservis_app/models/vehicle.dart';
import 'package:otoservis_app/utils/constants.dart';

class PdfTemplate {
  static Future<Uint8List> buildServiceSlip({
    required ServiceRecord service,
    required Vehicle vehicle,
  }) async {
    final doc = pw.Document();
    final dateFmt = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR');
    final moneyFmt = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: 'TL',
      decimalDigits: 2,
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginTop: 20 * PdfPageFormat.mm,
          marginBottom: 20 * PdfPageFormat.mm,
          marginLeft: 15 * PdfPageFormat.mm,
          marginRight: 15 * PdfPageFormat.mm,
        ),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(
                service: service,
                dateText: dateFmt.format(service.date),
              ),
              pw.SizedBox(height: 14),
              _buildVehicleInfo(vehicle),
              pw.SizedBox(height: 16),
              _buildPartsTable(service.parts, moneyFmt),
              pw.SizedBox(height: 12),
              _buildLaborTable(service.laborItems, moneyFmt),
              pw.Spacer(),
              _buildTotalBlock(service, moneyFmt),
              pw.SizedBox(height: 16),
              _buildFooter(service),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildHeader({
    required ServiceRecord service,
    required String dateText,
  }) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    BusinessInfo.name,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${BusinessInfo.address}\nTel: ${BusinessInfo.phone}',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 20),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'SERVIS FISI',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Fis No: ${service.id}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'Tarih: $dateText',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 0.8, color: PdfColors.grey500),
      ],
    );
  }

  static pw.Widget _buildVehicleInfo(Vehicle vehicle) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoLine('Plaka', vehicle.plate),
                _infoLine('Arac', '${vehicle.brand} ${vehicle.model} ${vehicle.year}'),
              ],
            ),
          ),
          pw.SizedBox(width: 24),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoLine('Musteri', vehicle.ownerName),
                _infoLine('Telefon', vehicle.ownerPhone),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPartsTable(
    List<ServicePart> parts,
    NumberFormat moneyFmt,
  ) {
    final headerStyle = pw.TextStyle(
      color: PdfColors.white,
      fontWeight: pw.FontWeight.bold,
      fontSize: 10,
    );
    final bodyStyle = const pw.TextStyle(fontSize: 9.5);

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
        children: [
          _cell('Parca Adi', headerStyle, alignRight: false),
          _cell('Adet', headerStyle),
          _cell('Birim Fiyat', headerStyle),
          _cell('Toplam', headerStyle),
        ],
      ),
    ];

    if (parts.isEmpty) {
      rows.add(
        pw.TableRow(
          children: [
            _cell('Parca yok', bodyStyle, alignRight: false),
            _cell('-', bodyStyle),
            _cell('-', bodyStyle),
            _cell('-', bodyStyle),
          ],
        ),
      );
    } else {
      for (var i = 0; i < parts.length; i++) {
        final p = parts[i];
        rows.add(
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isEven ? PdfColors.grey100 : PdfColors.white,
            ),
            children: [
              _cell(p.partName, bodyStyle, alignRight: false),
              _cell('${p.quantity}', bodyStyle),
              _cell(moneyFmt.format(p.unitPrice), bodyStyle),
              _cell(moneyFmt.format(p.totalPrice), bodyStyle),
            ],
          ),
        );
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'PARCALAR',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(4),
            1: pw.FlexColumnWidth(1.2),
            2: pw.FlexColumnWidth(2),
            3: pw.FlexColumnWidth(2),
          },
          children: rows,
        ),
      ],
    );
  }

  static pw.Widget _buildLaborTable(
    List<LaborItem> laborItems,
    NumberFormat moneyFmt,
  ) {
    final headerStyle = pw.TextStyle(
      color: PdfColors.white,
      fontWeight: pw.FontWeight.bold,
      fontSize: 10,
    );
    final bodyStyle = const pw.TextStyle(fontSize: 9.5);

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
        children: [
          _cell('Islem', headerStyle, alignRight: false),
          _cell('Tutar', headerStyle),
        ],
      ),
    ];

    if (laborItems.isEmpty) {
      rows.add(
        pw.TableRow(
          children: [
            _cell('Iscilik yok', bodyStyle, alignRight: false),
            _cell('-', bodyStyle),
          ],
        ),
      );
    } else {
      for (var i = 0; i < laborItems.length; i++) {
        final l = laborItems[i];
        rows.add(
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isEven ? PdfColors.grey100 : PdfColors.white,
            ),
            children: [
              _cell(l.description, bodyStyle, alignRight: false),
              _cell(moneyFmt.format(l.price), bodyStyle),
            ],
          ),
        );
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ISCILIK',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(4),
            1: pw.FlexColumnWidth(2),
          },
          children: rows,
        ),
      ],
    );
  }

  static pw.Widget _buildTotalBlock(ServiceRecord service, NumberFormat moneyFmt) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 220,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _totalRow('Ara toplam', moneyFmt.format(service.subtotal)),
            if (service.kdvIncluded)
              _totalRow(
                'KDV (%${(service.kdvRate * 100).toStringAsFixed(0)})',
                moneyFmt.format(service.kdvAmount),
              ),
            pw.SizedBox(height: 4),
            pw.Divider(color: PdfColors.black, thickness: 0.8),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'GENEL TOPLAM',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                pw.Text(
                  moneyFmt.format(service.grandTotal),
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildFooter(ServiceRecord service) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                service.technicianName,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              ),
              pw.Text(
                'Bakim Ustasi',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
        pw.Expanded(
          child: pw.Center(
            child: pw.Text(
              'Bizi tercih ettiginiz icin tesekkurler',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                width: 120,
                child: pw.Divider(thickness: 0.8, color: PdfColors.black),
              ),
              pw.Text(
                'Imza',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _infoLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(
        text: pw.TextSpan(
          style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.black),
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
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
        alignment: alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(text, style: style),
      ),
    );
  }

  static pw.Widget _totalRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}

