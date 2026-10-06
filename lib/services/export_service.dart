import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/strings.dart';
import '../models/finance.dart';
import 'finance_store.dart';
import 'xlsx_writer.dart';

const xlsxMime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
const jsonMime = 'application/json';

/// Exportar a Excel, copia de seguridad (JSON) y restaurar.
class ExportService {
  ExportService(this.store);

  static const _channel = MethodChannel('ficonza/files');
  static const backupFormat = 'ficonza-backup';
  static const backupVersion = 1;

  final FinanceStore store;

  // ---------- Excel ----------

  /// Libro con una hoja "Consolidado" y una hoja por cada mes entre [from] y [to].
  Future<Uint8List> buildExcel({String? from, String? to, int decimals = 0}) async {
    final s = S.current;
    final summaries = await store.summaries(from: from, to: to);
    final entries = await store.db.entries(fromMonth: from, toMonth: to);
    final money = decimals > 0 ? '#,##0.${'0' * decimals}' : '#,##0';
    final wb = XlsxWorkbook();

    // ----- Consolidado: una fila por mes -----
    final sheet = wb.addSheet(s.consolidated);
    const headers = 8;
    final titleStyle = XStyle(bold: true, fill: '0B1530', color: 'FFFFFF', center: true, size: 13);
    final headStyle = XStyle(bold: true, fill: '424242', color: 'FFFFFF', center: true);
    final moneyStyle = XStyle(numberFormat: money);
    final totalLabel = XStyle(bold: true, fill: 'E0E0E0');
    final totalMoney = XStyle(bold: true, fill: 'E0E0E0', numberFormat: money);
    sheet.set(0, 0, 'Ficonza — ${s.consolidated}', titleStyle);
    for (var c = 1; c < headers; c++) {
      sheet.set(0, c, null, titleStyle);
    }
    sheet.merge(0, 0, headers - 1);
    final cols = [s.month, s.moduleIncome, s.moduleOccasional, s.totalDeductions, s.netIncome, s.moduleFixed, s.moduleVariable, s.balance];
    for (var c = 0; c < cols.length; c++) {
      sheet.set(2, c, cols[c], headStyle);
      sheet.width(c, c == 0 ? 18 : 17);
    }
    var row = 3;
    for (final m in summaries) {
      sheet.set(row, 0, s.monthLabel(m.month), const XStyle());
      final values = [m.income, m.occasional, m.totalDeductions, m.netIncome, m.fixed, m.variable, m.balance];
      for (var c = 0; c < values.length; c++) {
        sheet.set(row, c + 1, values[c], c == values.length - 1 ? _balanceStyle(m.balance, money) : moneyStyle);
      }
      row++;
    }
    double total(double Function(MonthSummary) f) => summaries.fold(0.0, (a, m) => a + f(m));
    sheet.set(row, 0, s.total, totalLabel);
    final totals = [
      total((m) => m.income),
      total((m) => m.occasional),
      total((m) => m.totalDeductions),
      total((m) => m.netIncome),
      total((m) => m.fixed),
      total((m) => m.variable),
      total((m) => m.balance),
    ];
    for (var c = 0; c < totals.length; c++) {
      sheet.set(row, c + 1, totals[c], totalMoney);
    }

    // ----- Una hoja por mes, con el diseño de la hoja original -----
    for (final m in summaries) {
      _monthSheet(wb, m, entries.where((e) => e.month == m.month).toList(), money);
    }
    return wb.encode();
  }

  static XStyle _balanceStyle(double value, String money) =>
      XStyle(bold: true, numberFormat: money, color: value < 0 ? 'C62828' : '2E7D32');

  void _monthSheet(XlsxWorkbook wb, MonthSummary m, List<Entry> entries, String money) {
    final s = S.current;
    final sheet = wb.addSheet(s.monthLabel(m.month));
    sheet
      ..width(0, 34)
      ..width(1, 16)
      ..width(2, 14);
    var row = 0;
    sheet.set(row, 0, 'Ficonza — ${s.monthLabel(m.month)}', const XStyle(bold: true, size: 14, border: false));
    row += 2;

    final moneyStyle = XStyle(numberFormat: money);
    final headStyle = XStyle(bold: true, fill: '424242', color: 'FFFFFF');
    final totalLabel = XStyle(bold: true, fill: 'E0E0E0');
    final totalMoney = XStyle(bold: true, fill: 'E0E0E0', numberFormat: money);

    /// Una tabla: título de color, encabezado, renglones y total.
    void table(FinanceModule module, String title, String totalTitle, double totalValue, {bool withDate = false}) {
      final lastCol = withDate ? 2 : 1;
      final titleStyle = XStyle(bold: true, fill: module.hex, color: 'FFFFFF', center: true);
      for (var c = 0; c <= lastCol; c++) {
        sheet.set(row, c, c == 0 ? title : null, titleStyle);
      }
      sheet.merge(row, 0, lastCol);
      row++;
      sheet.set(row, 0, s.concept, headStyle);
      sheet.set(row, 1, s.value, headStyle);
      if (withDate) sheet.set(row, 2, s.date, headStyle);
      row++;
      for (final e in entries.where((e) => e.module == module)) {
        final label = module == FinanceModule.fixed && e.paid ? '${e.concept} ✓' : e.concept;
        sheet.set(row, 0, e.note.isEmpty ? label : '$label (${e.note})');
        sheet.set(row, 1, e.amount, moneyStyle);
        if (withDate) sheet.set(row, 2, e.date, const XStyle(numberFormat: 'dd/mm/yyyy'));
        row++;
      }
      sheet.set(row, 0, totalTitle, totalLabel);
      sheet.set(row, 1, totalValue, totalMoney);
      if (withDate) sheet.set(row, 2, null, totalLabel);
      row += 2;
    }

    table(FinanceModule.income, s.moduleIncome.toUpperCase(), s.totalIncome, m.income);
    table(FinanceModule.occasional, s.moduleOccasional.toUpperCase(), s.totalOccasional, m.occasional);
    table(FinanceModule.fixed, s.moduleFixed.toUpperCase(), s.totalFixed, m.fixed);
    table(FinanceModule.variable, s.moduleVariable.toUpperCase(), s.totalVariable, m.variable, withDate: true);

    // Deducciones: salud y pensión calculada + las escritas a mano.
    final dedTitle = XStyle(bold: true, fill: FinanceModule.deduction.hex, color: 'FFFFFF', center: true);
    sheet
      ..set(row, 0, s.moduleDeductions.toUpperCase(), dedTitle)
      ..set(row, 1, null, dedTitle)
      ..merge(row, 0, 1);
    row++;
    sheet
      ..set(row, 0, s.concept, headStyle)
      ..set(row, 1, s.value, headStyle);
    row++;
    sheet
      ..set(row, 0, s.healthPension(_pct(m.healthPercent)))
      ..set(row, 1, m.health, moneyStyle);
    row++;
    for (final e in entries.where((e) => e.module == FinanceModule.deduction)) {
      sheet
        ..set(row, 0, e.concept)
        ..set(row, 1, e.amount, moneyStyle);
      row++;
    }
    sheet
      ..set(row, 0, s.totalDeductions.toUpperCase(), totalLabel)
      ..set(row, 1, m.totalDeductions, totalMoney);
    row++;
    final green = XStyle(bold: true, fill: 'A5D6A7');
    sheet
      ..set(row, 0, s.netIncome.toUpperCase(), green)
      ..set(row, 1, m.netIncome, XStyle(bold: true, fill: 'A5D6A7', numberFormat: money));
    row += 2;

    // Resumen final.
    final sumTitle = XStyle(bold: true, fill: summaryColor.toARGB32().toRadixString(16).substring(2).toUpperCase(), color: 'FFFFFF', center: true);
    sheet
      ..set(row, 0, s.finalSummary.toUpperCase(), sumTitle)
      ..set(row, 1, null, sumTitle)
      ..merge(row, 0, 1);
    row++;
    for (final (label, value) in [
      (s.summaryNet, m.netIncome),
      (s.summaryMinusFixed, m.fixed),
      (s.summaryMinusVariable, m.variable),
    ]) {
      sheet
        ..set(row, 0, label)
        ..set(row, 1, value, moneyStyle);
      row++;
    }
    final balanceFill = m.balance < 0 ? 'C62828' : '2E7D32';
    sheet
      ..set(row, 0, s.balanceTitle, XStyle(bold: true, fill: balanceFill, color: 'FFFFFF', size: 12))
      ..set(row, 1, m.balance, XStyle(bold: true, fill: balanceFill, color: 'FFFFFF', size: 12, numberFormat: money));
  }

  static String _pct(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  // ---------- Copia de seguridad (JSON) ----------

  Future<Uint8List> buildBackup() async {
    final dump = await store.db.dump();
    final json = {
      'format': backupFormat,
      'version': backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'months': dump['months'],
      'entries': dump['entries'],
    };
    return Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(json)));
  }

  /// Lee una copia de seguridad. Devuelve cuántos meses y renglones trae, o null si no es válida.
  static ({List<Map<String, Object?>> months, List<Map<String, Object?>> entries})? parseBackup(Uint8List bytes) {
    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (json['format'] != backupFormat) return null;
      List<Map<String, Object?>> list(String key) =>
          [for (final m in (json[key] as List? ?? const [])) if (m is Map) Map<String, Object?>.from(m)];
      return (months: list('months'), entries: list('entries'));
    } catch (e) {
      debugPrint('Copia no válida: $e');
      return null;
    }
  }

  // ---------- Guardar, compartir y abrir archivos ----------

  /// Abre el selector de Android para guardar (Descargas, Drive, etc.). True si se guardó.
  static Future<bool> saveAs(String fileName, String mime, Uint8List bytes) async {
    try {
      return await _channel.invokeMethod<bool>('save', {'name': fileName, 'mime': mime, 'bytes': bytes}) ?? false;
    } catch (e) {
      debugPrint('Guardar: $e');
      return false;
    }
  }

  /// Comparte el archivo (WhatsApp, correo, Drive…).
  static Future<void> share(String fileName, String mime, Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: mime)], subject: fileName));
  }

  /// Abre el selector de Android para elegir un archivo. Null si se canceló.
  static Future<Uint8List?> pickFile() async {
    try {
      return await _channel.invokeMethod<Uint8List>('open');
    } catch (e) {
      debugPrint('Abrir: $e');
      return null;
    }
  }
}
