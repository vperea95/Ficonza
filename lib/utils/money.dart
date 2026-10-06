import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Monedas disponibles. El peso colombiano no usa decimales.
enum Currency {
  cop(r'$', 0),
  usd(r'US$', 2),
  eur('€', 2),
  mxn(r'MX$', 2);

  const Currency(this.symbol, this.decimals);
  final String symbol;
  final int decimals;

  String get code => name.toUpperCase();
}

/// Formato de dinero de toda la app: "$ 1.234.567".
class Money {
  static Currency currency = Currency.cop;

  static NumberFormat get _format =>
      NumberFormat.currency(locale: 'es_CO', symbol: currency.symbol, decimalDigits: currency.decimals);

  /// Con [dashZero], el cero se muestra como "-" (igual que en la hoja de cálculo).
  static String format(double value, {bool dashZero = false}) {
    if (dashZero && value == 0) return '-';
    return _format.format(value);
  }

  /// "1.234.567,5" -> 1234567.5
  static double parse(String text) {
    final clean = text.replaceAll('.', '').replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(clean) ?? 0;
  }

  /// Texto para editar un valor existente: 1234567 -> "1.234.567".
  static String toInput(double value) {
    if (value == 0) return '';
    return NumberFormat.decimalPatternDigits(locale: 'es_CO', decimalDigits: currency.decimals)
        .format(value)
        .replaceAll(RegExp(r',0+$'), '');
  }
}

/// Mientras se escribe, agrupa los miles con punto ("1234567" -> "1.234.567").
/// Con decimales, la coma es el separador decimal.
class MoneyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final decimals = Money.currency.decimals;
    var text = newValue.text.replaceAll('.', '');
    if (decimals == 0) text = text.replaceAll(',', '');
    text = text.replaceAll(RegExp(r'[^0-9,]'), '');

    final parts = text.split(',');
    var intPart = parts.first.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (intPart.length > 13) intPart = intPart.substring(0, 13);
    final grouped = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) grouped.write('.');
      grouped.write(intPart[i]);
    }
    var result = grouped.toString();
    if (decimals > 0 && parts.length > 1) {
      final dec = parts[1];
      result = '${result.isEmpty ? '0' : result},${dec.length > decimals ? dec.substring(0, decimals) : dec}';
    }
    return TextEditingValue(text: result, selection: TextSelection.collapsed(offset: result.length));
  }
}
