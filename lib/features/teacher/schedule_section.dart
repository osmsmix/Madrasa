import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/teacher_repository.dart';
import '../../l10n/strings.dart';

/// The teacher's full weekly timetable (all days), grouped by weekday with
/// today highlighted. Read-only overview; attendance is taken from the Today tab.
class ScheduleSection extends StatefulWidget {
  const ScheduleSection({super.key, required this.schoolId});
  final String schoolId;
  @override
  State<ScheduleSection> createState() => _ScheduleSectionState();
}

class _ScheduleSectionState extends State<ScheduleSection> {
  late Future<List<TeacherSlot>> _future =
      context.read<TeacherRepository>().mySlots(schoolId: widget.schoolId);

  void _reload() {
    setState(() {
      _future =
          context.read<TeacherRepository>().mySlots(schoolId: widget.schoolId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final todayWeekday = DateTime.now().weekday;

    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: FutureBuilder<List<TeacherSlot>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final slots = snap.data ?? const [];
          if (slots.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                Center(
                    child: Text(s.noSessions,
                        style: Theme.of(context).textTheme.bodyLarge)),
              ],
            );
          }

          final byDay = <int, List<TeacherSlot>>{};
          for (final slot in slots) {
            byDay.putIfAbsent(slot.weekday, () => []).add(slot);
          }
          for (final list in byDay.values) {
            list.sort((a, b) => a.startTime.compareTo(b.startTime));
          }
          final days = byDay.keys.toList()..sort();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final day in days)
                        _dayGroup(context, day, byDay[day]!,
                            isToday: day == todayWeekday),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _dayGroup(BuildContext context, int day, List<TeacherSlot> slots,
      {required bool isToday}) {
    final s = context.s;
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Row(
            children: [
              Text(s.dayName(day),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: primary, fontWeight: FontWeight.bold)),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(s.todayTab,
                      style: TextStyle(
                          color: primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ),
        for (final slot in slots) _slotTile(context, slot),
      ],
    );
  }

  Widget _slotTile(BuildContext context, TeacherSlot slot) {
    final s = context.s;
    final time = '${timeLabel(slot.start)} – ${timeLabel(slot.end)}';
    final sub = [
      slot.className,
      if (slot.room != null && slot.room!.isNotEmpty) '${s.roomLabel}: ${slot.room}',
    ].join('  ·  ');
    return Card(
      child: ListTile(
        leading: SizedBox(
          width: 88,
          child: Text(time,
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.labelLarge),
        ),
        title: Text(slot.subjectName),
        subtitle: Text(sub),
      ),
    );
  }
}
