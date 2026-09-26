import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../data/models.dart';
import '../../data/parent_repository.dart';
import '../../l10n/strings.dart';

String _fmt(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// A child's grades, grouped by subject, each subject showing a weighted average.
class ParentGradesView extends StatefulWidget {
  const ParentGradesView({super.key, required this.studentId});
  final String studentId;
  @override
  State<ParentGradesView> createState() => _ParentGradesViewState();
}

class _ParentGradesViewState extends State<ParentGradesView> {
  late Future<List<ParentSubjectGrades>> _future =
      context.read<ParentRepository>().grades(widget.studentId);

  void _reload() {
    setState(() {
      _future = context.read<ParentRepository>().grades(widget.studentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: FutureBuilder<List<ParentSubjectGrades>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final subjects = snap.data ?? const [];
          if (subjects.isEmpty) {
            return ListView(children: [
              const SizedBox(height: 80),
              Center(
                  child:
                      Text(s.noGrades, style: Theme.of(context).textTheme.bodyLarge)),
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
                    children: [
                      for (final subj in subjects) _subjectCard(context, subj),
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

  Widget _subjectCard(BuildContext context, ParentSubjectGrades subj) {
    final s = context.s;
    final lang = Localizations.localeOf(context).languageCode;
    final avg = subj.average;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(subj.subjectName,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                if (avg != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.seed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${s.averageLabel} ${_fmt(avg)}/20',
                        style: const TextStyle(
                            color: AppTheme.seed,
                            fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const Divider(height: 20),
            for (final e in subj.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.title),
                          Text(
                            '${s.assessmentTypeName(e.type)} · ${DateFormat.yMMMd(lang).format(e.date)} · ${s.coefficientLabel} ${_fmt(e.coefficient)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      e.value == null ? '—' : '${_fmt(e.value!)}/${_fmt(e.maxGrade)}',
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
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
