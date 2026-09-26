import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/parent_repository.dart';
import '../../l10n/strings.dart';

/// A child's attendance history. For an absence or late, the parent can mark it
/// excused (with an optional reason) or unmark it.
class ParentAttendanceView extends StatefulWidget {
  const ParentAttendanceView({super.key, required this.studentId});
  final String studentId;
  @override
  State<ParentAttendanceView> createState() => _ParentAttendanceViewState();
}

class _ParentAttendanceViewState extends State<ParentAttendanceView> {
  ParentRepository get _repo => context.read<ParentRepository>();
  late Future<List<ParentAttendanceEntry>> _future =
      _repo.attendance(widget.studentId);

  void _reload() {
    setState(() {
      _future = _repo.attendance(widget.studentId);
    });
  }

  Color _statusColor(BuildContext context, AttendanceStatus st) {
    switch (st) {
      case AttendanceStatus.present:
        return Colors.green.shade600;
      case AttendanceStatus.absent:
        return Theme.of(context).colorScheme.error;
      case AttendanceStatus.late:
        return Colors.orange.shade700;
    }
  }

  Future<void> _toggleExcuse(ParentAttendanceEntry e) async {
    if (e.excused) {
      await _repo.setExcused(e.id, false);
      _reload();
      return;
    }
    final reason = await showDialog<String?>(
      context: context,
      builder: (_) => _ExcuseDialog(),
    );
    if (reason == null) return; // cancelled
    await _repo.setExcused(e.id, true,
        reason: reason.isEmpty ? null : reason);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: FutureBuilder<List<ParentAttendanceEntry>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return ListView(children: [
              const SizedBox(height: 80),
              Center(
                  child: Text(s.noAttendanceRecords,
                      style: Theme.of(context).textTheme.bodyLarge)),
            ]);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [for (final e in items) _tile(context, e)],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, ParentAttendanceEntry e) {
    final s = context.s;
    final lang = Localizations.localeOf(context).languageCode;
    final color = _statusColor(context, e.status);
    final canExcuse = e.status != AttendanceStatus.present;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(width: 6, height: 40, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.subjectName,
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    '${DateFormat.yMMMd(lang).format(e.date)} · ${s.attendanceStatusName(e.status)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: color),
                  ),
                  if (e.excused && e.reason != null && e.reason!.isNotEmpty)
                    Text('${s.excusedLabel}: ${e.reason}',
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (canExcuse)
              e.excused
                  ? ActionChip(
                      avatar: const Icon(Icons.check_circle, size: 18),
                      label: Text(s.excusedLabel),
                      onPressed: () => _toggleExcuse(e),
                    )
                  : OutlinedButton(
                      onPressed: () => _toggleExcuse(e),
                      child: Text(s.markExcused),
                    ),
          ],
        ),
      ),
    );
  }
}

class _ExcuseDialog extends StatefulWidget {
  @override
  State<_ExcuseDialog> createState() => _ExcuseDialogState();
}

class _ExcuseDialogState extends State<_ExcuseDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AlertDialog(
      scrollable: true,
      title: Text(s.markExcused),
      content: SizedBox(
        width: double.maxFinite,
        child: TextField(
          controller: _ctrl,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
              labelText: s.excuseReasonLabel, alignLabelWithHint: true),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(s.cancel)),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_ctrl.text.trim()),
          child: Text(s.save),
        ),
      ],
    );
  }
}
