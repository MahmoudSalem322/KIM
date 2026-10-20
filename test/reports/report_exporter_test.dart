import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kim/features/reports/export/report_exporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final data = ReportExportData(
    title: 'التقرير المالي',
    subtitle: '2026-10-01 - 2026-10-20',
    generatedAt: DateTime.utc(2026, 10, 20),
    currency: 'ILS',
    arabic: true,
    headers: ['المحفظة', 'المبلغ', 'التصنيف'],
    rows: [
      ['محفظتي', '9007199254740993.123456', 'طعام، ومشروبات'],
      ['=HYPERLINK("bad")', '-42.00', 'نص\nجديد'],
    ],
    summary: {'الدخل': '100.00', 'المصاريف': '42.00'},
    notes: ['سعر يدوي: 1 USD = 3.75 ILS؛ المصدر: المستخدم'],
  );
  test('CSV preserves Arabic, exact decimals and RFC quoting; neutralizes formulas', () {
    final csv = utf8.decode(ReportExporter.csv(data));
    expect(ReportExporter.csv(data).take(3), [239, 187, 191]);
    expect(csv, contains('9007199254740993.123456'));
    expect(csv, contains('محفظتي'));
    expect(csv, contains("'=HYPERLINK"));
    expect(csv, contains("'-42.00"));
    expect(csv, contains('"نص\nجديد"'));
    expect(csv, contains('""bad""'));
    expect(csv, contains('1 USD = 3.75 ILS'));
  });
  test('XLSX is real OOXML with exact text cells, Arabic direction and no formulas', () {
    final archive = ZipDecoder().decodeBytes(ReportExporter.xlsx(data));
    expect(archive.findFile('[Content_Types].xml'), isNotNull);
    final sheet = utf8.decode(
      archive.findFile('xl/worksheets/sheet1.xml')!.content,
    );
    expect(sheet, contains('rightToLeft="1"'));
    expect(sheet, contains('9007199254740993.123456'));
    expect(sheet, contains('محفظتي'));
    expect(sheet, contains('t="inlineStr"'));
    expect(sheet, isNot(contains('<f>')));
    expect(sheet, contains('&quot;bad&quot;'));
  });
  test(
    'Arabic PDF embeds fonts and supports multi-page transaction tables',
    () async {
      final many = ReportExportData(
        title: data.title,
        subtitle: data.subtitle,
        generatedAt: data.generatedAt,
        currency: data.currency,
        arabic: true,
        headers: data.headers,
        rows: [for (var i = 0; i < 120; i++) data.rows.first],
        notes: data.notes,
        summary: data.summary,
      );
      final bytes = await ReportExporter.pdf(many);
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      final raw = latin1.decode(bytes);
      expect(raw, contains('/FontFile2'));
      await Directory('.dart_tool/phase-10').create(recursive: true);
      await File('.dart_tool/phase-10/arabic-report.pdf').writeAsBytes(bytes);
      await File('.dart_tool/phase-10/arabic-report.xlsx')
          .writeAsBytes(ReportExporter.xlsx(data));
    },
  );
  test(
    'Eight-column report wraps long notes and mixed-language rate sources',
    () async {
      final detail = ReportExportData(
        title: data.title,
        subtitle: data.subtitle,
        generatedAt: data.generatedAt,
        currency: data.currency,
        arabic: true,
        headers: [
          'Date',
          'Type',
          'Wallet',
          'Category',
          'Original',
          'Display',
          'Rate',
          'Notes',
        ],
        rows: [
          [
            '2026-10-20',
            'المصاريف',
            'Shekels',
            'طعام',
            '10.00 USD',
            '37.50 ILS',
            "3.75 USD / ILS source ${'Manual source '.padRight(160, 'a')}",
            'ملاحظات '.padRight(1000, 'a'),
          ],
        ],
        notes: ['سعر الصرف → USD / ILS'],
        summary: data.summary,
      );
      final bytes = await ReportExporter.pdf(detail);
      await Directory('.dart_tool/phase-10').create(recursive: true);
      await File('.dart_tool/phase-10/long-notes.pdf').writeAsBytes(bytes);
      expect(bytes, isNotEmpty);
    },
  );
  test('Empty exports remain valid and retain summary provenance', () async {
    final empty = ReportExportData(
      title: 'Empty',
      subtitle: 'No rows',
      generatedAt: DateTime.utc(2026),
      currency: 'USD',
      arabic: false,
      headers: ['Date', 'Amount'],
      rows: [],
      notes: ['Missing rate: EUR'],
    );
    expect(
      utf8.decode(ReportExporter.csv(empty)),
      contains('Missing rate: EUR'),
    );
    expect(
      ZipDecoder().decodeBytes(ReportExporter.xlsx(empty)).files,
      hasLength(5),
    );
    expect(await ReportExporter.pdf(empty), isNotEmpty);
  });
}
