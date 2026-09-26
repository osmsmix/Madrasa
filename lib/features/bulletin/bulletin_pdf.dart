import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/bulletin_repository.dart';
import '../../l10n/strings.dart';

String _num(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// Builds a printable report-card PDF. Uses Cairo (Arabic + Latin) so names in
/// any language render; falls back to the default font if the fetch fails.
Future<Uint8List> buildBulletinPdf({
  required AppStrings s,
  required String schoolName,
  required String studentName,
  required String className,
  required String termName,
  required String yearLabel,
  required double gradeMax,
  required BulletinData data,
  ({int rank, int total})? rank,
}) async {
  pw.ThemeData? theme;
  try {
    theme = pw.ThemeData.withFont(
      base: await PdfGoogleFonts.cairoRegular(),
      bold: await PdfGoogleFonts.cairoBold(),
    );
  } catch (_) {
    theme = null; // default fonts (Latin only)
  }

  final doc = pw.Document(theme: theme);
  final maxStr = _num(gradeMax);
  final rtl = s.locale.languageCode == 'ar';
  final textDir = rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;

  pw.Widget cell(String text,
          {bool bold = false, PdfColor? color, bool numeric = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: pw.Text(text,
            textDirection: numeric ? pw.TextDirection.ltr : textDir,
            style: pw.TextStyle(
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: color)),
      );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      textDirection: textDir,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(schoolName,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text('${s.bulletin} — $yearLabel — $termName',
              style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700)),
          pw.Divider(thickness: 1.5),
          pw.SizedBox(height: 6),
          pw.Row(children: [
            pw.Expanded(child: pw.Text('${s.studentLabel}: $studentName')),
            pw.Text('${s.classLabel}: $className'),
          ]),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FlexColumnWidth(1.4),
              2: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  cell(s.subjectCol, bold: true),
                  cell(s.coefficientLabel, bold: true),
                  cell('${s.averageLabel} /$maxStr', bold: true),
                ],
              ),
              for (final line in data.lines)
                pw.TableRow(children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(line.subjectName, textDirection: textDir),
                        if (line.types.isNotEmpty)
                          pw.Text(
                            line.types
                                .map((t) => s.assessmentTypeName(t))
                                .join(' · '),
                            textDirection: textDir,
                            style: const pw.TextStyle(
                                fontSize: 8, color: PdfColors.grey600),
                          ),
                      ],
                    ),
                  ),
                  cell(_num(line.coefficient), numeric: true),
                  cell('${_num(line.average)}/$maxStr', numeric: true),
                ]),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(s.overallAverage,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Row(children: [
                  if (rank != null)
                    pw.Text('${s.rankLabel}: ${rank.rank} / ${rank.total}     ',
                        style: const pw.TextStyle(color: PdfColors.grey700)),
                  pw.Text(
                    data.overall == null ? '—' : '${_num(data.overall!)}/$maxStr',
                    textDirection: pw.TextDirection.ltr,
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 14),
                  ),
                ]),
              ],
            ),
          ),
          pw.Spacer(),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Madrasa',
                style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 10)),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}
