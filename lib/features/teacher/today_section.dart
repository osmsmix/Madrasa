import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/teacher_repository.dart';
import '../../l10n/strings.dart';
import 'attendance_screen.dart';

/// Today's sessions for the signed-in teacher, taken from the timetable and
/// filtered to today's weekday. Tapping one opens attendance for that session.
class TodaySection extends StatefulWidget {
  const TodaySection({super.key, required this.schoolId});
  final String schoolId;
  @override
  State<TodaySection> createState() => _TodaySectionState();
}

class _TodaySectionState extends State<TodaySection> {
  late Future<List<TeacherSlot>> _future =
      context.read<TeacherRepository>().mySlots(schoolId: widget.schoolId);

  final DateTime _today = DateTime.now();

  void _reload() {
    setState(() {
      _future =
          context.read<TeacherRepository>().mySlots(schoolId: widget.schoolId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final lang = Localizations.localeOf(context).languageCode;
    final weekday = _today.weekday; // 1 = Mon … 7 = Sun

    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: FutureBuilder<List<TeacherSlot>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final todays = (snap.data ?? const [])
              .where((slot) => slot.weekday == weekday)
              .toList()
            ..sort((a, b) => a.startTime.compareTo(b.startTime));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${s.dayName(weekday)} · ${DateFormat.yMMMMd(lang).format(_today)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      if (todays.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                              child: Text(s.noSessionsToday,
                                  style:
                                      Theme.of(context).textTheme.bodyLarge)),
                        )
                      else
                        for (final slot in todays) _sessionCard(context, slot),
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

  Widget _sessionCard(BuildContext context, TeacherSlot slot) {
    final s = context.s;
    final time = '${timeLabel(slot.start)} – ${timeLabel(slot.end)}';
    final sub = [
      slot.className,
      if (slot.room != null && slot.room!.isNotEmpty) '${s.roomLabel}: ${slot.room}',
    ].join('  ·  ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: SizedBox(
          width: 88,
          child: Text(time,
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.labelLarge),
        ),
        title: Text(slot.subjectName),
        subtitle: Text(sub),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AttendanceScreen(slot: slot, date: _today),
          ),
        ),
      ),
    );
  }
}
