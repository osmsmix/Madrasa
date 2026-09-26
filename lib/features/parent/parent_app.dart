import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/parent_repository.dart';
import '../../data/school_repository.dart';
import '../../l10n/strings.dart';
import '../../widgets/account_menu.dart';
import '../../widgets/language_menu.dart';
import '../../widgets/madrasa_logo.dart';
import '../bulletin/bulletin_screen.dart';
import 'parent_attendance_view.dart';
import 'parent_grades_view.dart';

/// The parent's app: view each child's grades and attendance, scoped to the
/// school picked at login. If the parent has several children, a switcher in the
/// app bar chooses which one.
class ParentApp extends StatefulWidget {
  const ParentApp({super.key, required this.schoolId});
  final String schoolId;
  @override
  State<ParentApp> createState() => _ParentAppState();
}

class _ParentAppState extends State<ParentApp> {
  ParentRepository get _repo => context.read<ParentRepository>();

  bool _loading = true;
  Object? _error;
  List<Student> _children = const [];
  String? _childId;
  School? _school;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final schoolRepo = context.read<SchoolRepository>();
    try {
      final children = await _repo.children(widget.schoolId);
      final school = await schoolRepo.schoolById(widget.schoolId);
      if (!mounted) return;
      setState(() {
        _children = children;
        _childId = children.isEmpty ? null : children.first.id;
        _school = school;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Student? get _child => _children.where((c) => c.id == _childId).firstOrNull;

  PreferredSizeWidget _appBar(BuildContext context) {
    final s = context.s;
    final child = _child;
    return AppBar(
      title: _children.length > 1
          ? _childSwitcher(context)
          : Text(child?.fullName ?? s.roleParent),
      actions: [
        if (child != null && _school != null)
          IconButton(
            tooltip: s.bulletin,
            icon: const Icon(Icons.description_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => BulletinScreen(student: child, school: _school!),
            )),
          ),
        const LanguageMenu(),
        const AccountMenu(),
      ],
    );
  }

  Widget _childSwitcher(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (id) => setState(() => _childId = id),
      itemBuilder: (context) => [
        for (final c in _children)
          CheckedPopupMenuItem(
            value: c.id,
            checked: c.id == _childId,
            child: Text(c.fullName),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(_child?.fullName ?? '',
                overflow: TextOverflow.ellipsis),
          ),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: Text(s.retry)),
            ],
          ),
        ),
      );
    }
    final child = _child;
    if (child == null) {
      return Scaffold(
        appBar: AppBar(actions: const [LanguageMenu(), AccountMenu()]),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MadrasaLogo(size: 64),
                const SizedBox(height: 16),
                Text(s.noChildren, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: _appBar(context),
      body: _index == 0
          ? ParentGradesView(studentId: child.id, key: ValueKey('g${child.id}'))
          : ParentAttendanceView(
              studentId: child.id, key: ValueKey('a${child.id}')),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.grade_outlined), label: s.gradesTab),
          NavigationDestination(
              icon: const Icon(Icons.event_available_outlined),
              label: s.attendanceTab),
        ],
      ),
    );
  }
}
