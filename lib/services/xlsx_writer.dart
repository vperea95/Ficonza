import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Formato de una celda de Excel.
class XStyle {
  const XStyle({
    this.bold = false,
    this.fill,
    this.color,
    this.numberFormat,
    this.border = true,
    this.center = false,
    this.size,
  });

  final bool bold;

  /// Color de fondo, hex sin "#" (por ejemplo "2E7D32").
  final String? fill;

  /// Color del texto, hex sin "#".
  final String? color;

  /// Formato numérico, por ejemplo "#,##0" o "dd/mm/yyyy".
  final String? numberFormat;
  final bool border;
  final bool center;
  final double? size;

  String get _key => '$bold|$fill|$color|$numberFormat|$border|$center|$size';
}

class _Cell {
  const _Cell(this.value, this.style);
  final Object? value;
  final XStyle style;
}

/// Una hoja del libro.
class XSheet {
  XSheet(this.name);

  final String name;
  final Map<int, Map<int, _Cell>> _rows = {};
  final Map<int, double> _widths = {};
  final List<String> _merges = [];

  /// [row] y [col] empiezan en 0. [value] puede ser String, num o DateTime.
  void set(int row, int col, Object? value, [XStyle style = const XStyle()]) {
    _rows.putIfAbsent(row, () => {})[col] = _Cell(value, style);
  }

  void width(int col, double chars) => _widths[col] = chars;

  /// Une celdas de la misma fila (para los títulos de cada tabla).
  void merge(int row, int fromCol, int toCol) => _merges.add('${_ref(row, fromCol)}:${_ref(row, toCol)}');
}

/// Libro de Excel (.xlsx) mínimo: varias hojas, estilos, celdas unidas y anchos.
/// Se escribe a mano (es un ZIP con XML) para no depender del paquete `excel`,
/// que choca con la versión de `archive` que usa flutter_launcher_icons.
class XlsxWorkbook {
  final List<XSheet> sheets = [];

  XSheet addSheet(String name) {
    final clean = name.replaceAll(RegExp(r'[\[\]:*?/\\]'), '-');
    var unique = clean.length > 31 ? clean.substring(0, 31) : clean;
    var n = 2;
    while (sheets.any((s) => s.name == unique)) {
      unique = '${clean.length > 27 ? clean.substring(0, 27) : clean} ($n)';
      n++;
    }
    final sheet = XSheet(unique);
    sheets.add(sheet);
    return sheet;
  }

  Uint8List encode() {
    final styles = <String, int>{};
    final styleList = <XStyle>[const XStyle(border: false)];
    styles[styleList.first._key] = 0;
    int styleId(XStyle s) => styles.putIfAbsent(s._key, () {
          styleList.add(s);
          return styleList.length - 1;
        });

    final sheetXml = <String>[];
    for (final sheet in sheets) {
      final b = StringBuffer()
        ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
        ..write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
            'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">');
      if (sheet._widths.isNotEmpty) {
        b.write('<cols>');
        final cols = sheet._widths.keys.toList()..sort();
        for (final c in cols) {
          b.write('<col min="${c + 1}" max="${c + 1}" width="${sheet._widths[c]}" customWidth="1"/>');
        }
        b.write('</cols>');
      }
      b.write('<sheetData>');
      final rows = sheet._rows.keys.toList()..sort();
      for (final r in rows) {
        b.write('<row r="${r + 1}">');
        final cells = sheet._rows[r]!;
        final cols = cells.keys.toList()..sort();
        for (final c in cols) {
          final cell = cells[c]!;
          final s = styleId(cell.style);
          final ref = _ref(r, c);
          final v = cell.value;
          if (v == null) {
            b.write('<c r="$ref" s="$s"/>');
          } else if (v is num) {
            b.write('<c r="$ref" s="$s"><v>${v.isFinite ? v : 0}</v></c>');
          } else if (v is DateTime) {
            b.write('<c r="$ref" s="$s"><v>${_excelDate(v)}</v></c>');
          } else {
            b.write('<c r="$ref" s="$s" t="inlineStr"><is><t xml:space="preserve">${_esc('$v')}</t></is></c>');
          }
        }
        b.write('</row>');
      }
      b.write('</sheetData>');
      if (sheet._merges.isNotEmpty) {
        b.write('<mergeCells count="${sheet._merges.length}">');
        for (final m in sheet._merges) {
          b.write('<mergeCell ref="$m"/>');
        }
        b.write('</mergeCells>');
      }
      b.write('</worksheet>');
      sheetXml.add(b.toString());
    }

    final archive = Archive();
    void add(String name, String content) => archive.addFile(ArchiveFile.bytes(name, utf8.encode(content)));

    add('[Content_Types].xml', _contentTypes());
    add('_rels/.rels', _rootRels);
    add('xl/workbook.xml', _workbook());
    add('xl/_rels/workbook.xml.rels', _workbookRels());
    add('xl/styles.xml', _styles(styleList));
    for (var i = 0; i < sheetXml.length; i++) {
      add('xl/worksheets/sheet${i + 1}.xml', sheetXml[i]);
    }
    return ZipEncoder().encodeBytes(archive);
  }

  String _contentTypes() {
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">')
      ..write('<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>')
      ..write('<Default Extension="xml" ContentType="application/xml"/>')
      ..write('<Override PartName="/xl/workbook.xml" '
          'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>')
      ..write('<Override PartName="/xl/styles.xml" '
          'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>');
    for (var i = 0; i < sheets.length; i++) {
      b.write('<Override PartName="/xl/worksheets/sheet${i + 1}.xml" '
          'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>');
    }
    b.write('</Types>');
    return b.toString();
  }

  static const _rootRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
      'Target="xl/workbook.xml"/></Relationships>';

  String _workbook() {
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
          'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>');
    for (var i = 0; i < sheets.length; i++) {
      b.write('<sheet name="${_esc(sheets[i].name)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>');
    }
    b.write('</sheets></workbook>');
    return b.toString();
  }

  String _workbookRels() {
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
    for (var i = 0; i < sheets.length; i++) {
      b.write('<Relationship Id="rId${i + 1}" '
          'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
          'Target="worksheets/sheet${i + 1}.xml"/>');
    }
    b.write('<Relationship Id="rId${sheets.length + 1}" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>');
    b.write('</Relationships>');
    return b.toString();
  }

  /// styles.xml: los formatos numéricos, fuentes, rellenos y bordes que usan las celdas.
  static String _styles(List<XStyle> list) {
    final numFmts = <String, int>{};
    final fonts = <String>['<font><sz val="11"/><name val="Calibri"/></font>'];
    final fills = <String>[
      '<fill><patternFill patternType="none"/></fill>',
      '<fill><patternFill patternType="gray125"/></fill>',
    ];
    const borders = [
      '<border><left/><right/><top/><bottom/><diagonal/></border>',
      '<border><left style="thin"><color rgb="FFBDBDBD"/></left><right style="thin"><color rgb="FFBDBDBD"/></right>'
          '<top style="thin"><color rgb="FFBDBDBD"/></top><bottom style="thin"><color rgb="FFBDBDBD"/></bottom><diagonal/></border>',
    ];
    final xfs = <String>[];
    for (final s in list) {
      var numId = 0;
      final fmt = s.numberFormat;
      if (fmt != null) numId = numFmts.putIfAbsent(fmt, () => 164 + numFmts.length);

      final font = '<font>${s.bold ? '<b/>' : ''}<sz val="${s.size ?? 11}"/>'
          '${s.color != null ? '<color rgb="FF${s.color}"/>' : ''}<name val="Calibri"/></font>';
      var fontId = fonts.indexOf(font);
      if (fontId < 0) {
        fonts.add(font);
        fontId = fonts.length - 1;
      }

      var fillId = 0;
      if (s.fill != null) {
        final fill = '<fill><patternFill patternType="solid"><fgColor rgb="FF${s.fill}"/><bgColor indexed="64"/></patternFill></fill>';
        fillId = fills.indexOf(fill);
        if (fillId < 0) {
          fills.add(fill);
          fillId = fills.length - 1;
        }
      }

      final align = s.center ? '<alignment horizontal="center" vertical="center"/>' : '<alignment vertical="center"/>';
      xfs.add('<xf numFmtId="$numId" fontId="$fontId" fillId="$fillId" borderId="${s.border ? 1 : 0}" xfId="0" '
          'applyNumberFormat="1" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">$align</xf>');
    }

    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
    if (numFmts.isNotEmpty) {
      b.write('<numFmts count="${numFmts.length}">');
      numFmts.forEach((code, id) => b.write('<numFmt numFmtId="$id" formatCode="${_esc(code)}"/>'));
      b.write('</numFmts>');
    }
    b
      ..write('<fonts count="${fonts.length}">${fonts.join()}</fonts>')
      ..write('<fills count="${fills.length}">${fills.join()}</fills>')
      ..write('<borders count="${borders.length}">${borders.join()}</borders>')
      ..write('<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>')
      ..write('<cellXfs count="${xfs.length}">${xfs.join()}</cellXfs>')
      ..write('<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>')
      ..write('</styleSheet>');
    return b.toString();
  }

  /// Excel cuenta los días desde el 30/12/1899.
  static double _excelDate(DateTime d) {
    final base = DateTime.utc(1899, 12, 30);
    final utc = DateTime.utc(d.year, d.month, d.day, d.hour, d.minute);
    return utc.difference(base).inMinutes / (24 * 60);
  }
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

/// (0,0) -> "A1", (4,27) -> "AB5".
String _ref(int row, int col) {
  var c = col;
  var letters = '';
  do {
    letters = String.fromCharCode(65 + c % 26) + letters;
    c = c ~/ 26 - 1;
  } while (c >= 0);
  return '$letters${row + 1}';
}
