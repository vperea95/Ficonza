import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../utils/money.dart';

/// Pide un valor de dinero (con puntos de miles mientras se escribe). Null si se canceló.
Future<double?> askAmount(BuildContext context, {required String title, double initial = 0, String? hint}) {
  final s = S.of(context);
  final controller = TextEditingController(text: Money.toInput(initial));
  return showDialog<double>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hint != null) ...[Text(hint), const SizedBox(height: 12)],
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.numberWithOptions(decimal: Money.currency.decimals > 0),
            inputFormatters: [MoneyInputFormatter()],
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            decoration: InputDecoration(prefixText: '${Money.currency.symbol} ', border: const OutlineInputBorder()),
            onSubmitted: (v) => Navigator.pop(dialogContext, Money.parse(v)),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(s.cancel)),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, Money.parse(controller.text)), child: Text(s.save)),
      ],
    ),
  );
}
