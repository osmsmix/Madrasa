import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../widgets/account_menu.dart';
import '../../widgets/language_menu.dart';
import '../../widgets/madrasa_logo.dart';
import '../../widgets/responsive.dart';
import 'grades_section.dart';
import 'schedule_section.dart';
import 'today_section.dart';

/// The teacher's app: today's schedule → attendance, and (next) grades.
/// Scoped to the school the teacher picked at login.
class TeacherApp extends StatefulWidget {
  const TeacherApp({super.key, required this.schoolId});
  final String schoolId;
  @override
  State<TeacherApp> createState() => _TeacherAppState();
}

class _TeacherAppState extends State<TeacherApp> {
  int _index = 0;

  String _title(BuildContext c) => switch (_index) {
        0 => c.s.todayTab,
        1 => c.s.navTimetable,
        _ => c.s.gradesTab,
      };

  Widget _body() => switch (_index) {
        0 => TodaySection(schoolId: widget.schoolId),
        1 => ScheduleSection(schoolId: widget.schoolId),
        _ => GradesSection(schoolId: widget.schoolId),
      };

  PreferredSizeWidget _appBar(BuildContext context, {bool showLeading = false}) {
    return AppBar(
      automaticallyImplyLeading: showLeading,
      title: Text(_title(context)),
      actions: [
        const LanguageMenu(),
        const AccountMenu(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final destinations = [
      (Icons.today_outlined, s.todayTab),
      (Icons.calendar_month_outlined, s.navTimetable),
      (Icons.grade_outlined, s.gradesTab),
    ];

    if (context.isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: context.isExpanded,
              minExtendedWidth: 180,
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: MadrasaLogo(size: 40),
              ),
              destinations: [
                for (final (icon, label) in destinations)
                  NavigationRailDestination(
                      icon: Icon(icon), label: Text(label)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Scaffold(appBar: _appBar(context), body: _body()),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: _appBar(context),
      body: _body(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final (icon, label) in destinations)
            NavigationDestination(icon: Icon(icon), label: label),
        ],
      ),
    );
  }
}

