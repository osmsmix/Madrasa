import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../data/bulletin_repository.dart';
import '../../data/models.dart';
import '../../l10n/strings.dart';
import 'bulletin_pdf.dart';

String _num(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// A report card holding the computed data + the student's rank in class.
class _BulletinResult {
  _BulletinResult(this.data, this.rank);
  final BulletinData data;
  final ({int rank, int total})? rank;
}

/// Report card for one student. Pick a term (or the whole year), see the computed
/// averages + rank, and print/download a PDF. Used by the director and parents.
class BulletinScreen extends StatefulWidget {
  const BulletinScreen({super.key, required this.student, required this.school});
  final Student student;
  final School school;

  @override
  State<BulletinScreen> createState() => _BulletinScreenState();
}

class _BulletinScreenState extends State<BulletinScreen> {
  static const _allYear = '__all__';

  BulletinRepository get _repo => context.read<BulletinRepository>();

  bool _loading = true;
  String _className = '';
  List<Term> _terms = const [];
  String? _termId;
  Future<_BulletinResult>? _future;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final className = await _repo.className(widget.student.classId);
    final terms = await _repo.termsForStudent(widget.student);
    if (!mounted) return;
    setState(() {
      _className = className;
      _terms = terms;
      _termId = _defaultTerm(terms);
      _loading = false;
    });
    _recompute();
  }

  String? _defaultTerm(List<Term> terms) {
    if (terms.isEmpty) return _allYear;
    final now = DateTime.now();
    for (final t in terms) {
      if (t.startsOn != null &&
          t.endsOn != null &&
          !now.isBefore(t.startsOn!) &&
          !now.isAfter(t.endsOn!)) {
        return t.id;
      }
    }
    return terms.first.id;
  }

  String? get _termArg => _termId == _allYear ? null : _termId;

  Future<_BulletinResult> _load(String? term) async {
    final data = await _repo.compute(
      studentId: widget.student.id,
      termId: term,
      gradeMax: widget.school.gradeMax,
    );
    final rank = await _repo.rank(studentId: widget.student.id, termId: term);
    return _BulletinResult(data, rank);
  }

  void _recompute() {
    if (_termId == null) return;
    setState(() {
      _future = _load(_termArg);
    });
  }

  String _termName(String termId) {
    if (termId == _allYear) return context.s.wholeYear;
    final t = _terms.firstWhere((x) => x.id == termId);
    return context.s.termName(widget.school.termType, t.idx);
  }

  Future<void> _export() async {
    if (_termId == null) return;
    setState(() => _exporting = true);
    final s = context.s;
    final termName = _termName(_termId!);
    try {
      final res = await _load(_termArg);
      await Printing.layoutPdf(
        onLayout: (format) => buildBulletinPdf(
          s: s,
          schoolName: widget.school.name,
          studentName: widget.student.fullName,
          className: _className,
          termName: termName,
          yearLabel: '',
          gradeMax: widget.school.gradeMax,
          data: res.data,
          rank: res.rank,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final maxStr = _num(widget.school.gradeMax);
    return Scaffold(
      appBar: AppBar(title: Text('${s.bulletin} · ${widget.student.fullName}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text('${s.term}:',
                                style: Theme.of(context).textTheme.labelLarge),
                            const SizedBox(width: 12),
                            DropdownButton<String>(
                              value: _termId,
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => _termId = v);
                                _recompute();
                              },
                              items: [
                                DropdownMenuItem(
                                    value: _allYear, child: Text(s.wholeYear)),
                                for (final t in _terms)
                                  DropdownMenuItem(
                                    value: t.id,
                                    child: Text(s.termName(
                                        widget.school.termType, t.idx)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _bulletinCard(context, maxStr),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _exporting ? null : _export,
              icon: _exporting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white))
                  : const Icon(Icons.picture_as_pdf),
              label: Text(s.downloadPdf),
            ),
    );
  }

  Widget _bulletinCard(BuildContext context, String maxStr) {
    final s = context.s;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<_BulletinResult>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final res = snap.data;
            if (res == null || res.data.lines.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text(s.noGradesTerm)),
              );
            }
            final data = res.data;
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        flex: 4,
                        child: Text(s.subjectCol,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(
                        flex: 2,
                        child: Text(s.coefficientLabel,
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(
                        flex: 2,
                        child: Text('${s.averageLabel} /$maxStr',
                            textAlign: TextAlign.end,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                const Divider(),
                for (final line in data.lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(line.subjectName),
                              if (line.types.isNotEmpty)
                                Text(
                                  line.types
                                      .map((t) => s.assessmentTypeName(t))
                                      .join(' · '),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                            flex: 2,
                            child: Text(_num(line.coefficient),
                                textAlign: TextAlign.center)),
                        Expanded(
                          flex: 2,
                          child: Text('${_num(line.average)}/$maxStr',
                              textAlign: TextAlign.end,
                              textDirection: TextDirection.ltr),
                        ),
                      ],
                    ),
                  ),
                const Divider(),
                if (res.rank != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(s.rankLabel),
                        Text('${res.rank!.rank} / ${res.rank!.total}',
                            textDirection: TextDirection.ltr,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.seed.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(s.overallAverage,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        data.overall == null
                            ? '—'
                            : '${_num(data.overall!)}/$maxStr',
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.seed),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
