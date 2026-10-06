import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/finance.dart';
import '../services/finance_store.dart';
import '../theme.dart';
import '../utils/money.dart';
import 'export_screen.dart';

/// Consolidado de un año: totales, gráfico de ingresos contra gastos y tabla mes a mes.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, required this.store});

  final FinanceStore store;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late int _year = MonthId.year(widget.store.month);
  late Future<List<MonthSummary>> _future = _load();

  Future<List<MonthSummary>> _load() =>
      widget.store.summaries(from: MonthId.of(_year, 1), to: MonthId.of(_year, 12));

  void _changeYear(int delta) => setState(() {
        _year += delta;
        _future = _load();
      });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.report),
        actions: [
          IconButton(
            tooltip: s.exportAndBackup,
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => ExportScreen(store: widget.store)),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<MonthSummary>>(
        future: _future,
        builder: (context, snap) {
          final data = snap.data;
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            children: [
              Row(
                children: [
                  IconButton(onPressed: () => _changeYear(-1), icon: const Icon(Icons.chevron_left_rounded)),
                  Expanded(
                    child: Text('$_year',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  IconButton(onPressed: () => _changeYear(1), icon: const Icon(Icons.chevron_right_rounded)),
                ],
              ),
              if (data == null)
                const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
              else if (data.isEmpty)
                Padding(padding: const EdgeInsets.all(32), child: Text(s.noDataYear, textAlign: TextAlign.center))
              else ...[
                _Totals(data: data),
                const SizedBox(height: 12),
                _Chart(data: data),
                const SizedBox(height: 12),
                _MonthsTable(
                  data: data,
                  onOpen: (month) {
                    widget.store.openMonth(month);
                    Navigator.popUntil(context, (r) => r.isFirst);
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.data});

  final List<MonthSummary> data;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    double sum(double Function(MonthSummary) f) => data.fold(0.0, (a, m) => a + f(m));
    final net = sum((m) => m.netIncome);
    final expenses = sum((m) => m.totalExpenses);
    final balance = sum((m) => m.balance);
    final tiles = [
      (s.netIncome, net, FinanceModule.income.color),
      (s.totalExpensesLabel, expenses, FinanceModule.variable.color),
      (s.balanceShort, balance, balance < 0 ? const Color(0xFFC62828) : AppColors.blue),
      (s.monthlyAverage, balance / data.length, const Color(0xFF00897B)),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.1,
      children: [
        for (final (label, value, color) in tiles)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(Money.format(value),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Barras por mes: ingresos netos (verde) contra gastos (morado).
class _Chart extends StatelessWidget {
  const _Chart({required this.data});

  final List<MonthSummary> data;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final maxValue = data.fold<double>(1, (a, m) => math.max(a, math.max(m.netIncome, m.totalExpenses)));
    const height = 160.0;
    final incomeColor = FinanceModule.income.color;
    final expenseColor = FinanceModule.variable.color;
    Widget legend(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(t, style: Theme.of(context).textTheme.bodySmall),
        ]);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          children: [
            SizedBox(
              height: height + 20,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final m in data)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _bar(m.netIncome / maxValue * height, incomeColor),
                              const SizedBox(width: 2),
                              _bar(m.totalExpenses / maxValue * height, expenseColor),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(s.monthShort(MonthId.month(m.month)), style: const TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 16, children: [legend(incomeColor, s.netIncome), legend(expenseColor, s.totalExpensesLabel)]),
          ],
        ),
      ),
    );
  }

  Widget _bar(double h, Color color) => Container(
        width: 8,
        height: h.clamp(1.0, 1000.0),
        decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
      );
}

/// Tabla mes a mes (se desliza de lado). Tocar un mes lo abre en el inicio.
class _MonthsTable extends StatelessWidget {
  const _MonthsTable({required this.data, required this.onOpen});

  final List<MonthSummary> data;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    double sum(double Function(MonthSummary) f) => data.fold(0.0, (a, m) => a + f(m));
    DataCell money(double v, {bool bold = false, Color? color}) => DataCell(Text(
          Money.format(v, dashZero: true),
          style: TextStyle(fontWeight: bold ? FontWeight.w800 : null, color: color),
        ));
    Color? balanceColor(double v) => v < 0 ? const Color(0xFFC62828) : const Color(0xFF2E7D32);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFF424242)),
          headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          showCheckboxColumn: false,
          columns: [
            DataColumn(label: Text(s.month)),
            DataColumn(label: Text(s.moduleIncome), numeric: true),
            DataColumn(label: Text(s.moduleOccasional), numeric: true),
            DataColumn(label: Text(s.totalDeductions), numeric: true),
            DataColumn(label: Text(s.netIncome), numeric: true),
            DataColumn(label: Text(s.moduleFixed), numeric: true),
            DataColumn(label: Text(s.moduleVariable), numeric: true),
            DataColumn(label: Text(s.balance), numeric: true),
          ],
          rows: [
            for (final m in data)
              DataRow(
                onSelectChanged: (_) => onOpen(m.month),
                cells: [
                  DataCell(Text(s.monthLabel(m.month))),
                  money(m.income),
                  money(m.occasional),
                  money(m.totalDeductions),
                  money(m.netIncome),
                  money(m.fixed),
                  money(m.variable),
                  money(m.balance, bold: true, color: balanceColor(m.balance)),
                ],
              ),
            DataRow(
              color: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainerHighest),
              cells: [
                DataCell(Text(s.total, style: const TextStyle(fontWeight: FontWeight.w800))),
                money(sum((m) => m.income), bold: true),
                money(sum((m) => m.occasional), bold: true),
                money(sum((m) => m.totalDeductions), bold: true),
                money(sum((m) => m.netIncome), bold: true),
                money(sum((m) => m.fixed), bold: true),
                money(sum((m) => m.variable), bold: true),
                money(sum((m) => m.balance), bold: true, color: balanceColor(sum((m) => m.balance))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
