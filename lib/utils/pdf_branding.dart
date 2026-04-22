import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:otoservis_app/utils/constants.dart';

class PdfBrandingBundle {
  const PdfBrandingBundle({
    required this.regular,
    required this.bold,
    required this.theme,
    required this.logo,
  });

  final pw.Font regular;
  final pw.Font bold;
  final pw.ThemeData theme;
  final pw.MemoryImage logo;
}

abstract final class PdfBranding {
  static final PdfColor navy = PdfColor.fromHex('121212');
  static final PdfColor softBlue = PdfColor.fromHex('fde68a');
  static final PdfColor zebra = PdfColor.fromHex('fffbea');
  static final PdfColor criticalRow = PdfColor.fromHex('fff6cc');
  static final PdfColor border = PdfColor.fromHex('e5d37a');
  static final PdfColor totalBorder = PdfColor.fromHex('c9a700');
  static final PdfColor gold = PdfColor.fromHex('facc15');

  static PdfBrandingBundle? _cache;

  static Future<PdfBrandingBundle> loadBundle() async {
    if (_cache != null) return _cache!;

    final regularData = await rootBundle.load(
      'assets/fonts/Roboto-Regular.ttf',
    );
    final boldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');

    final regular = pw.Font.ttf(regularData);
    final bold = pw.Font.ttf(boldData);
    final logoData = await rootBundle.load('assets/images/app_logo.png');
    final logo = pw.MemoryImage(logoData.buffer.asUint8List());

    final bundle = PdfBrandingBundle(
      regular: regular,
      bold: bold,
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      logo: logo,
    );
    _cache = bundle;
    return bundle;
  }

  static String formatDocumentDate(DateTime date) {
    return DateFormat('dd MMMM yyyy', 'tr_TR').format(date);
  }

  static pw.Widget buildPremiumHeader({
    required PdfBrandingBundle bundle,
    required String title,
    required DateTime date,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: navy,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: totalBorder, width: 1.2),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 58,
                  height: 58,
                  padding: const pw.EdgeInsets.all(7),
                  decoration: pw.BoxDecoration(
                    color: gold,
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Image(bundle.logo, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        companyName.toUpperCase(),
                        style: pw.TextStyle(
                          font: bundle.bold,
                          fontSize: 24,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        companySubtitle,
                        style: pw.TextStyle(
                          font: bundle.regular,
                          fontSize: 11,
                          color: softBlue,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Tel: $companyPhone',
                        style: pw.TextStyle(
                          font: bundle.regular,
                          fontSize: 10,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        companyAddress,
                        style: pw.TextStyle(
                          font: bundle.regular,
                          fontSize: 9,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  font: bundle.bold,
                  fontSize: 16,
                  color: gold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Tarih: ${formatDocumentDate(date)}',
                style: pw.TextStyle(
                  font: bundle.regular,
                  fontSize: 10,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget buildPremiumFooter(PdfBrandingBundle bundle) {
    return pw.Column(
      children: [
        pw.Divider(color: navy),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '$companyName - Tüm hakları saklıdır',
              style: pw.TextStyle(
                font: bundle.regular,
                fontSize: 8,
                color: PdfColors.grey,
              ),
            ),
            pw.Text(
              'Bu belge otomatik oluşturulmuştur',
              style: pw.TextStyle(
                font: bundle.regular,
                fontSize: 8,
                color: PdfColors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
