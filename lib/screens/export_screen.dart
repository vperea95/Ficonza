import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/finance.dart';
import '../theme.dart';
import '../services/export_service.dart';
import '../services/finance_store.dart';
import '../utils/money.dart';

enum _Scope { month, year, all }

/// Exportar a Excel, guardar o compartir la copia de seguridad, y restaurarla.
class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key, required this.store});

  final FinanceStore store;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  _Scope _scope = _Scope.year;
  bool _busy = false;

  late final ExportService _export = ExportService(widget.store);

  String get _month => widget.store.month;
  int get _year => MonthId.year(_month);

  (String?, String?, String) _range(S s) => switch (_scope) {
        _Scope.month => (_month, _month, 'Ficonza_$_month'),
        _Scope.year => (MonthId.of(_year, 1), MonthId.of(_year, 12), 'Ficonza_$_year'),
        _Scope.all => (null, null, 'Ficonza_${s.fileAll}'),
      };

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _snack(S.of(context).somethingWrong('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<Uint8List> _excel() {
    final (from, to, _) = _range(S.of(context));
    return _export.buildExcel(from: from, to: to, decimals: Money.currency.decimals);
  }

  Future<void> _saveExcel() => _run(() async {
        final s = S.of(context);
        final name = '${_range(s).$3}.xlsx';
        final ok = await ExportService.saveAs(name, xlsxMime, await _excel());
        if (ok) _snack(s.savedFile(name));
      });

  Future<void> _shareExcel() => _run(() async {
        final name = '${_range(S.of(context)).$3}.xlsx';
        await ExportService.share(name, xlsxMime, await _excel());
      });

  String _backupName() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Ficonza_copia_${now.year}-${two(now.month)}-${two(now.day)}.json';
  }

  Future<void> _saveBackup() => _run(() async {
        final s = S.of(context);
        final name = _backupName();
        final ok = await ExportService.saveAs(name, jsonMime, await _export.buildBackup());
        if (ok) _snack(s.savedFile(name));
      });

  Future<void> _shareBackup() => _run(() async {
        await ExportService.share(_backupName(), jsonMime, await _export.buildBackup());
      });

  Future<void> _restore() async {
    final s = S.of(context);
    final bytes = await ExportService.pickFile();
    if (bytes == null || !mounted) return;
    final backup = ExportService.parseBackup(bytes);
    if (backup == null) {
      _snack(s.invalidBackup);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: Text(s.restoreQuestion),
        content: Text(s.restoreWarning(backup.months.length, backup.entries.length)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(s.restore)),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await widget.store.restore(backup.months, backup.entries, backup.funds, backup.settings);
      _snack(s.restored);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.exportAndBackup),
        bottom: _busy ? const PreferredSize(preferredSize: Size.fromHeight(3), child: LinearProgressIndicator()) : null,
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ----- Excel -----
            _SectionCard(
              icon: Icons.grid_on_rounded,
              color: AppColors.blue,
              title: s.excelTitle,
              body: s.excelHint,
              children: [
                SegmentedButton<_Scope>(
                  segments: [
                    ButtonSegment(value: _Scope.month, label: Text(s.monthLabel(_month), overflow: TextOverflow.ellipsis)),
                    ButtonSegment(value: _Scope.year, label: Text('$_year')),
                    ButtonSegment(value: _Scope.all, label: Text(s.everything)),
                  ],
                  selected: {_scope},
                  onSelectionChanged: (v) => setState(() => _scope = v.first),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saveExcel,
                        icon: const Icon(Icons.save_alt_rounded),
                        label: Text(s.saveFile),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _shareExcel,
                        icon: const Icon(Icons.share_rounded),
                        label: Text(s.share),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ----- Copia de seguridad -----
            _SectionCard(
              icon: Icons.backup_rounded,
              color: AppColors.blue,
              title: s.backupTitle,
              body: s.backupHint,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saveBackup,
                        icon: const Icon(Icons.save_alt_rounded),
                        label: Text(s.saveFile),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _shareBackup,
                        icon: const Icon(Icons.share_rounded),
                        label: Text(s.share),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _restore,
                  icon: const Icon(Icons.settings_backup_restore_rounded),
                  label: Text(s.restoreBackup),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(s.dataStaysHint, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.children,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: color, foregroundColor: Colors.white, child: Icon(icon)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(body),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}
