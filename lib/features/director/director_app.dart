import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/academic_repository.dart';
import '../../data/models.dart';
import '../../data/school_repository.dart';
import '../../l10n/strings.dart';
import '../../widgets/account_menu.dart';
import '../../widgets/language_menu.dart';
import '../../widgets/madrasa_logo.dart';
import '../../widgets/responsive.dart';
import 'onboarding_screen.dart';
import 'sections/announcements_section.dart';
import 'sections/classes_section.dart';
import 'sections/school_settings_section.dart';
import 'sections/students_section.dart';
import 'sections/subjects_section.dart';
import 'sections/teachers_section.dart';
import 'sections/timetable_section.dart';
import 'widgets.dart';

/// Entry point for a director. Owns the list of the director's schools and the
/// currently-selected one, and hosts the responsive dashboard shell.
class DirectorApp extends StatefulWidget {
  const DirectorApp({super.key, this.initialSchoolId});

  /// The school picked at login; the app opens on it when provided.
  final String? initialSchoolId;

  @override
  State<DirectorApp> createState() => _DirectorAppState();
}

class _DirectorAppState extends State<DirectorApp> {
  SchoolRepository get _repo => context.read<SchoolRepository>();

  List<School> _schools = const [];
  String? _currentId;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _currentId = widget.initialSchoolId;
    _load();
  }

  Future<void> _load({String? selectId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final schools = await _repo.mySchools();
      setState(() {
        _schools = schools;
        // keep current selection if still present, else the requested/first one
        final ids = schools.map((s) => s.id).toSet();
        _currentId = selectId ??
            (ids.contains(_currentId) ? _currentId : schools.firstOrNull?.id);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  School? get _current =>
      _schools.where((s) => s.id == _currentId).firstOrNull;

  Future<void> _createSchool() async {
    final created = await showDialog<School>(
      context: context,
      builder: (_) => const CreateSchoolDialog(),
    );
    if (created != null) await _load(selectId: created.id);
  }

  void _onSchoolUpdated(School s) {
    setState(() {
      _schools = [
        for (final x in _schools) if (x.id == s.id) s else x,
      ];
    });
  }

  Future<void> _onSchoolDeleted() => _load();

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: () => _load(), child: Text(context.s.retry)),
            ],
          ),
        ),
      );
    }
    final current = _current;
    if (current == null) {
      return OnboardingScreen(onSchoolCreated: _load);
    }
    if (!current.isActive) {
      return _PendingActivationScreen(
        school: current,
        onRefresh: () => _load(selectId: current.id),
      );
    }
    return _DirectorShell(
      key: ValueKey(current.id),
      school: current,
      schools: _schools,
      onSwitch: (s) => setState(() => _currentId = s.id),
      onCreateSchool: _createSchool,
      onSchoolUpdated: _onSchoolUpdated,
      onSchoolDeleted: _onSchoolDeleted,
    );
  }
}

/// Shown to a director whose school has not been activated by the vendor yet.
class _PendingActivationScreen extends StatelessWidget {
  const _PendingActivationScreen(
      {required this.school, required this.onRefresh});
  final School school;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      appBar: AppBar(
        actions: [
          const LanguageMenu(),
          const AccountMenu(),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hourglass_top,
                    size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(school.name,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(s.pendingActivationTitle,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Text(s.pendingActivationBody,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: Text(s.refresh),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _Section { dashboard, classes, subjects, teachers, students, timetable, announcements, settings }

class _DirectorShell extends StatefulWidget {
  const _DirectorShell({
    super.key,
    required this.school,
    required this.schools,
    required this.onSwitch,
    required this.onCreateSchool,
    required this.onSchoolUpdated,
    required this.onSchoolDeleted,
  });

  final School school;
  final List<School> schools;
  final ValueChanged<School> onSwitch;
  final VoidCallback onCreateSchool;
  final ValueChanged<School> onSchoolUpdated;
  final VoidCallback onSchoolDeleted;

  @override
  State<_DirectorShell> createState() => _DirectorShellState();
}

class _DirectorShellState extends State<_DirectorShell> {
  _Section _current = _Section.dashboard;

  IconData _icon(_Section s) => switch (s) {
        _Section.dashboard => Icons.dashboard_outlined,
        _Section.classes => Icons.groups_outlined,
        _Section.subjects => Icons.menu_book_outlined,
        _Section.teachers => Icons.co_present_outlined,
        _Section.students => Icons.school_outlined,
        _Section.timetable => Icons.calendar_month_outlined,
        _Section.announcements => Icons.campaign_outlined,
        _Section.settings => Icons.settings_outlined,
      };

  String _label(BuildContext c, _Section s) {
    final t = c.s;
    return switch (s) {
      _Section.dashboard => t.navDashboard,
      _Section.classes => t.navClasses,
      _Section.subjects => t.navSubjects,
      _Section.teachers => t.navTeachers,
      _Section.students => t.navStudents,
      _Section.timetable => t.navTimetable,
      _Section.announcements => t.navAnnouncements,
      _Section.settings => t.navSettings,
    };
  }

  Widget _body() {
    switch (_current) {
      case _Section.settings:
        return SchoolSettingsSection(
          school: widget.school,
          onSchoolUpdated: widget.onSchoolUpdated,
          onSchoolDeleted: widget.onSchoolDeleted,
        );
      case _Section.dashboard:
        return _DashboardSection(
          school: widget.school,
          onOpen: (sec) => setState(() => _current = sec),
        );
      case _Section.announcements:
        return AnnouncementsSection(school: widget.school);
      case _Section.classes:
        return ClassesSection(school: widget.school);
      case _Section.subjects:
        return SubjectsSection(school: widget.school);
      case _Section.teachers:
        return TeachersSection(school: widget.school);
      case _Section.students:
        return StudentsSection(school: widget.school);
      case _Section.timetable:
        return TimetableSection(school: widget.school);
    }
  }

  @override
  Widget build(BuildContext context) {
    return context.isWide ? _wide(context) : _narrow(context);
  }

  Widget _wide(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: context.isExpanded,
            minExtendedWidth: 200,
            selectedIndex: _current.index,
            onDestinationSelected: (i) =>
                setState(() => _current = _Section.values[i]),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: MadrasaLogo(size: context.isExpanded ? 48 : 36),
            ),
            destinations: [
              for (final s in _Section.values)
                NavigationRailDestination(
                  icon: Icon(_icon(s)),
                  label: Text(_label(context, s)),
                ),
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

  Widget _narrow(BuildContext context) {
    return Scaffold(
      appBar: _appBar(context, showMenu: true),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Row(
                  children: [
                    const MadrasaLogo(size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SchoolSwitcher(
                        current: widget.school,
                        schools: widget.schools,
                        onSwitch: widget.onSwitch,
                        onCreate: widget.onCreateSchool,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              for (final s in _Section.values)
                ListTile(
                  leading: Icon(_icon(s)),
                  title: Text(_label(context, s)),
                  selected: s == _current,
                  onTap: () {
                    setState(() => _current = s);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
      body: _body(),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context, {bool showMenu = false}) {
    return AppBar(
      automaticallyImplyLeading: showMenu,
      title: Text(_label(context, _current)),
      actions: [
        // On wide screens the switcher sits in the app bar; on phones it moves
        // to the drawer header so the top bar stays clean like teacher/parent.
        if (!showMenu)
          _SchoolSwitcher(
            current: widget.school,
            schools: widget.schools,
            onSwitch: widget.onSwitch,
            onCreate: widget.onCreateSchool,
          ),
        const LanguageMenu(),
        const AccountMenu(),
      ],
    );
  }
}

/// App-bar dropdown to switch between the director's schools, or create a new one.
class _SchoolSwitcher extends StatelessWidget {
  const _SchoolSwitcher({
    required this.current,
    required this.schools,
    required this.onSwitch,
    required this.onCreate,
  });

  final School current;
  final List<School> schools;
  final ValueChanged<School> onSwitch;
  final VoidCallback onCreate;

  static const _createValue = '__create__';

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return PopupMenuButton<String>(
      tooltip: s.switchSchool,
      onSelected: (v) {
        if (v == _createValue) {
          onCreate();
        } else {
          final target = schools.where((x) => x.id == v).firstOrNull;
          if (target != null) onSwitch(target);
        }
      },
      itemBuilder: (context) => [
        for (final school in schools)
          PopupMenuItem(
            value: school.id,
            child: Row(
              children: [
                Icon(
                  school.id == current.id
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(school.name)),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _createValue,
          child: Row(
            children: [
              const Icon(Icons.add, size: 18),
              const SizedBox(width: 10),
              Text(s.createSchoolCta),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                current.name,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

class _DashboardSection extends StatefulWidget {
  const _DashboardSection({required this.school, required this.onOpen});
  final School school;
  final void Function(_Section) onOpen;

  @override
  State<_DashboardSection> createState() => _DashboardSectionState();
}

class _DashboardSectionState extends State<_DashboardSection> {
  late final Future<(_YearInfo, DashboardStats)> _future = _load();

  Future<(_YearInfo, DashboardStats)> _load() async {
    final schoolRepo = context.read<SchoolRepository>();
    final academicRepo = context.read<AcademicRepository>();
    final years = await schoolRepo.years(widget.school.id);
    SchoolYear? active;
    for (final y in years) {
      if (y.isActive) active = y;
    }
    final stats =
        await academicRepo.stats(widget.school.id, activeYearId: active?.id);
    return (_YearInfo(active?.label), stats);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return FutureBuilder<(_YearInfo, DashboardStats)>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final yearLabel = snap.data?.$1.label;
        final st = snap.data?.$2;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(context, yearLabel),
                    const SizedBox(height: 20),
                    Text(s.overview,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, c) {
                        const spacing = 12.0;
                        final cols = c.maxWidth < 520 ? 2 : 4;
                        final cardW =
                            (c.maxWidth - spacing * (cols - 1)) / cols;
                        final cards = <Widget>[
                          _StatCard(
                            icon: Icons.groups_outlined,
                            label: s.statClasses,
                            value: st?.classes,
                            onTap: () => widget.onOpen(_Section.classes),
                          ),
                          _StatCard(
                            icon: Icons.school_outlined,
                            label: s.statStudents,
                            value: st?.students,
                            onTap: () => widget.onOpen(_Section.students),
                          ),
                          _StatCard(
                            icon: Icons.co_present_outlined,
                            label: s.statTeachers,
                            value: st?.teachers,
                            onTap: () => widget.onOpen(_Section.teachers),
                          ),
                          _StatCard(
                            icon: Icons.menu_book_outlined,
                            label: s.statSubjects,
                            value: st?.subjects,
                            onTap: () => widget.onOpen(_Section.subjects),
                          ),
                        ];
                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            for (final card in cards)
                              SizedBox(width: cardW, child: card),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _QuickAction(
                          icon: Icons.calendar_month_outlined,
                          label: s.navTimetable,
                          onTap: () => widget.onOpen(_Section.timetable),
                        ),
                        _QuickAction(
                          icon: Icons.campaign_outlined,
                          label: s.navAnnouncements,
                          onTap: () => widget.onOpen(_Section.announcements),
                        ),
                        _QuickAction(
                          icon: Icons.settings_outlined,
                          label: s.navSettings,
                          onTap: () => widget.onOpen(_Section.settings),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _header(BuildContext context, String? yearLabel) {
    final s = context.s;
    final school = widget.school;
    final scale = school.gradeMax % 1 == 0
        ? school.gradeMax.toStringAsFixed(0)
        : '${school.gradeMax}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const MadrasaLogo(size: 56),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(school.name,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(
                    '${yearLabel ?? s.noActiveYear}'
                    '  ·  ${school.termType == TermType.trimester ? s.trimester : s.semester}'
                    '  ·  /$scale',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YearInfo {
  _YearInfo(this.label);
  final String? label;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final int? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: scheme.primary, size: 20),
                  ),
                  const Spacer(),
                  Text(value?.toString() ?? '—',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

