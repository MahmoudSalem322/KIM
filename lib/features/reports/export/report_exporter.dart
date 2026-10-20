import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// All amounts arrive formatted with exact decimal arithmetic. Spreadsheet cells
/// remain text so Excel cannot round large integers or six-place currencies.
class ReportExportData {
  const ReportExportData({
    required this.title,
    required this.subtitle,
    required this.generatedAt,
    required this.currency,
    required this.arabic,
    required this.headers,
    required this.rows,
    this.summary = const {},
    this.notes = const [],
  });
  final String title, subtitle, currency;
  final DateTime generatedAt;
  final bool arabic;
  final List<String> headers;
  final List<List<String>> rows;
  final Map<String, String> summary;
  final List<String> notes;
}

abstract final class ReportExporter {
  static List<List<String>> _rows(ReportExportData d) => [
    [d.title],
    [d.subtitle],
    [d.arabic ? 'عملة العرض' : 'Display currency', d.currency],
    [
      d.arabic ? 'تاريخ الإنشاء' : 'Generated at',
      d.generatedAt.toIso8601String(),
    ],
    ...d.summary.entries.map((e) => [e.key, e.value]),
    ...d.notes.map((e) => [e]),
    [],
    d.headers,
    ...d.rows,
  ];

  /// RFC 4180 quoting, UTF-8 BOM for Arabic desktop Excel, and formula defense.
  static Uint8List csv(ReportExportData data) {
    String cell(String value) {
      final dangerous = RegExp(r'^[\s]*[=+\-@\t\r]').hasMatch(value);
      final safe = dangerous ? "'$value" : value;
      return '"${safe.replaceAll('"', '""')}"';
    }

    return Uint8List.fromList(
      utf8.encode(
        '\uFEFF${_rows(data).map((r) => r.map(cell).join(',')).join('\r\n')}\r\n',
      ),
    );
  }

  static String _xml(String value) => value
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  static Uint8List xlsx(ReportExportData data) {
    String col(int n) {
      var s = '';
      for (n++; n > 0; n = (n - 1) ~/ 26) {
        s = String.fromCharCode(65 + (n - 1) % 26) + s;
      }
      return s;
    }

    final rows = _rows(data);
    final body = StringBuffer();
    for (var i = 0; i < rows.length; i++) {
      body.write('<row r="${i + 1}">');
      for (var j = 0; j < rows[i].length; j++) {
        body.write(
          '<c r="${col(j)}${i + 1}" t="inlineStr"><is><t xml:space="preserve">${_xml(rows[i][j])}</t></is></c>',
        );
      }
      body.write('</row>');
    }
    final files = <String, String>{
      '[Content_Types].xml': '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>',
      '_rels/.rels': '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
      'xl/workbook.xml': '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Report" sheetId="1" r:id="rId1"/></sheets></workbook>',
      'xl/_rels/workbook.xml.rels': '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>',
      'xl/worksheets/sheet1.xml':
          '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetViews><sheetView workbookViewId="0" rightToLeft="${data.arabic ? 1 : 0}"/></sheetViews><sheetFormatPr defaultRowHeight="20"/><cols><col min="1" max="${data.headers.length < 2 ? 2 : data.headers.length}" width="24" customWidth="1"/></cols><sheetData>$body</sheetData></worksheet>',
    };
    final archive = Archive();
    for (final file in files.entries) {
      final bytes = utf8.encode(file.value);
      archive.addFile(ArchiveFile(file.key, bytes.length, bytes));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static Future<Uint8List> pdf(ReportExportData input) async {
    // Currency/date separators use the bundled fonts' guaranteed glyphs.
    String clean(String value) => value
        .replaceAll('→', ' / ')
        .replaceAll('\uFFFD', '')
        .replaceAll('—', '-')
        .replaceAll('…', '...');
    final d = ReportExportData(
      title: clean(input.title),
      subtitle: clean(input.subtitle),
      generatedAt: input.generatedAt,
      currency: input.currency,
      arabic: input.arabic,
      headers: input.headers.map(clean).toList(),
      rows: input.rows.map((r) => r.map(clean).toList()).toList(),
      summary: {
        for (final e in input.summary.entries) clean(e.key): clean(e.value),
      },
      notes: input.notes.map(clean).toList(),
    );
    final tableHeaders = d.headers.length >= 8
        ? d.headers.take(7).toList()
        : d.headers;
    final tableRows = d.rows
        .map((r) => r.take(tableHeaders.length).toList())
        .toList();
    final arabic = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic.ttf'),
    );
    final latin = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans.ttf'),
    );
    final doc = pw.Document(title: d.title, author: 'Kim', compress: true);
    final direction = d.arabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    doc.addPage(
      pw.MultiPage(
        maxPages: 10000,
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        textDirection: direction,
        theme: pw.ThemeData.withFont(
          base: d.arabic ? arabic : latin,
          bold: d.arabic ? arabic : latin,
          italic: d.arabic ? arabic : latin,
          boldItalic: d.arabic ? arabic : latin,
          fontFallback: [latin, arabic],
        ),
        footer: (context) => pw.Text(
          '${context.pageNumber} / ${context.pagesCount}',
          textDirection: pw.TextDirection.ltr,
          style: const pw.TextStyle(fontSize: 8),
        ),
        build: (_) => [
          pw.Text(
            d.title,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(d.subtitle, textDirection: pw.TextDirection.ltr),
          pw.Text(
            '${d.currency} | ${d.generatedAt.toIso8601String()}',
            textDirection: pw.TextDirection.ltr,
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.SizedBox(height: 14),
          ...d.summary.entries.map(
            (e) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Row(
                children: [
                  pw.Expanded(child: pw.Text(e.key)),
                  pw.Expanded(
                    child: pw.Text(
                      e.value,
                      textDirection: pw.TextDirection.ltr,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ...d.notes.map(
            (n) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Text(n, style: const pw.TextStyle(fontSize: 8)),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: d.arabic ? tableHeaders.reversed.toList() : tableHeaders,
            data: tableRows
                .map((r) => d.arabic ? r.reversed.toList() : r)
                .toList(),
            columnWidths: {
              for (var i = 0; i < tableHeaders.length; i++)
                i: const pw.FlexColumnWidth(),
            },
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xff163a48),
            ),
            oddRowDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xfff0f5f6),
            ),
            cellPadding: const pw.EdgeInsets.all(6),
            cellAlignment: d.arabic
                ? pw.Alignment.centerRight
                : pw.Alignment.centerLeft,
            border: pw.TableBorder.all(color: PdfColors.grey300, width: .4),
          ),
          if (d.headers.length >= 8) ...[
            pw.SizedBox(height: 16),
            pw.Text(d.arabic ? 'ملاحظات العمليات' : 'Transaction notes'),
            for (var i = 0; i < d.rows.length; i++) ...[
              if (d.rows[i].length >= 8 && d.rows[i][7].isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Text(
                  '${i + 1}. ${d.rows[i][0]}',
                  textDirection: pw.TextDirection.ltr,
                  style: const pw.TextStyle(fontSize: 8),
                ),
                for (var start = 0; start < d.rows[i][7].length; start += 400)
                  pw.Text(
                    d.rows[i][7].substring(
                      start,
                      (start + 400).clamp(0, d.rows[i][7].length),
                    ),
                    style: const pw.TextStyle(fontSize: 8),
                  ),
              ],
            ],
          ],
          if (d.rows.isEmpty)
            pw.Text(
              d.arabic
                  ? 'لا توجد عمليات ضمن الفلاتر المحددة'
                  : 'No transactions match these filters',
            ),
        ],
      ),
    );
    return doc.save();
  }
}
