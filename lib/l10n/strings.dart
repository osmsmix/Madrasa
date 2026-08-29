import 'package:flutter/material.dart';

import '../data/models.dart';

/// Lightweight localization for ar / fr / en. Backed by plain maps so the app is
/// trilingual immediately; can be migrated to Flutter's gen-l10n (.arb) later
/// without changing call sites much (usage is `context.s.someKey`).
class AppStrings {
  AppStrings(this.locale);
  final Locale locale;

  static const supportedLocales = [
    Locale('ar'),
    Locale('fr'),
    Locale('en'),
  ];

  static const delegate = _AppStringsDelegate();

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings)!;

  String get _lang => locale.languageCode;
  String _t(String key) => _values[key]?[_lang] ?? _values[key]?['en'] ?? key;

  // Generic
  String get appName => _t('appName');
  String get loading => _t('loading');
  String get retry => _t('retry');
  String get refresh => _t('refresh');
  String get pendingActivationTitle => _t('pendingActivationTitle');
  String get pendingActivationBody => _t('pendingActivationBody');
  String get signOut => _t('signOut');
  String get continueLabel => _t('continue');

  // Auth — phone
  String get signInTitle => _t('signInTitle');
  String get phoneLabel => _t('phoneLabel');
  String get phoneHint => _t('phoneHint');
  String get phoneRequired => _t('phoneRequired');
  String get sendCode => _t('sendCode');

  // Auth — otp
  String get otpTitle => _t('otpTitle');
  String otpSentTo(String phone) => _t('otpSentTo').replaceFirst('{phone}', phone);
  String get otpLabel => _t('otpLabel');
  String get otpRequired => _t('otpRequired');
  String get verify => _t('verify');
  String get resendCode => _t('resendCode');
  String get changeNumber => _t('changeNumber');
  String get invalidCode => _t('invalidCode');
  String get genericError => _t('genericError');

  // Role routing
  String get chooseRole => _t('chooseRole');
  String get chooseAccess => _t('chooseAccess');
  String get roleDirector => _t('roleDirector');
  String get roleTeacher => _t('roleTeacher');
  String get roleParent => _t('roleParent');
  String get notLinkedTitle => _t('notLinkedTitle');
  String get notLinkedBody => _t('notLinkedBody');

  // Common actions
  String get save => _t('save');
  String get cancel => _t('cancel');
  String get add => _t('add');
  String get create => _t('create');
  String get edit => _t('edit');
  String get delete => _t('delete');
  String get comingSoon => _t('comingSoon');

  // Director onboarding
  String get welcomeTitle => _t('welcomeTitle');
  String get welcomeBody => _t('welcomeBody');
  String get createSchoolCta => _t('createSchoolCta');
  String get schoolName => _t('schoolName');
  String get termTypeLabel => _t('termTypeLabel');
  String get trimester => _t('trimester');
  String get semester => _t('semester');
  String get gradeMaxLabel => _t('gradeMaxLabel');
  String get waitingNote => _t('waitingNote');

  // Director navigation
  String get navDashboard => _t('navDashboard');
  String get navClasses => _t('navClasses');
  String get navSubjects => _t('navSubjects');
  String get navTeachers => _t('navTeachers');
  String get navStudents => _t('navStudents');
  String get navTimetable => _t('navTimetable');
  String get navAnnouncements => _t('navAnnouncements');
  String get navSettings => _t('navSettings');

  // School settings / years / terms
  String get schoolSettings => _t('schoolSettings');
  String get schoolYears => _t('schoolYears');
  String get addYear => _t('addYear');
  String get yearLabel => _t('yearLabel');
  String get startDate => _t('startDate');
  String get endDate => _t('endDate');
  String get activeYear => _t('activeYear');
  String get setActive => _t('setActive');
  String get noYears => _t('noYears');
  String get termsWord => _t('termsWord');
  String get sectionComingSoon => _t('sectionComingSoon');

  // Classes & subjects
  String get academicYear => _t('academicYear');
  String get addClass => _t('addClass');
  String get className => _t('className');
  String get classNameHint => _t('classNameHint');
  String get noClasses => _t('noClasses');
  String get needYearFirst => _t('needYearFirst');
  String get addSubject => _t('addSubject');
  String get subjectName => _t('subjectName');
  String get noSubjects => _t('noSubjects');

  // Teachers
  String get fullNameLabel => _t('fullNameLabel');
  String get addTeacher => _t('addTeacher');
  String get noTeachers => _t('noTeachers');
  String get pendingTeacher => _t('pendingTeacher');

  // Class ↔ subject assignment
  String get classSubjectsTitle => _t('classSubjectsTitle');
  String get assignSubject => _t('assignSubject');
  String get coefficientLabel => _t('coefficientLabel');
  String get selectSubject => _t('selectSubject');
  String get teacherLabel => _t('teacherLabel');
  String get unassignedTeacher => _t('unassignedTeacher');
  String get noAssignedSubjects => _t('noAssignedSubjects');
  String get allSubjectsAssigned => _t('allSubjectsAssigned');
  String get needSubjectsFirst => _t('needSubjectsFirst');

  // Announcements
  String get newAnnouncement => _t('newAnnouncement');
  String get announcementTitle => _t('announcementTitle');
  String get announcementBody => _t('announcementBody');
  String get audienceLabel => _t('audienceLabel');
  String get audienceTeachers => _t('audienceTeachers');
  String get audienceParents => _t('audienceParents');
  String get audienceBoth => _t('audienceBoth');
  String get scopeLabel => _t('scopeLabel');
  String get wholeSchool => _t('wholeSchool');
  String get noAnnouncements => _t('noAnnouncements');

  // Dashboard
  String get overview => _t('overview');
  String get statClasses => _t('statClasses');
  String get statStudents => _t('statStudents');
  String get statTeachers => _t('statTeachers');
  String get statSubjects => _t('statSubjects');
  String get noActiveYear => _t('noActiveYear');

  // Students
  String get addStudent => _t('addStudent');
  String get studentName => _t('studentName');
  String get noStudents => _t('noStudents');
  String get parentPhone1 => _t('parentPhone1');
  String get parentPhone2 => _t('parentPhone2');

  // Teacher app
  String get todayTab => _t('todayTab');
  String get gradesTab => _t('gradesTab');
  String get noSessionsToday => _t('noSessionsToday');
  String get present => _t('present');
  String get absent => _t('absent');
  String get late => _t('late');
  String get markAllPresent => _t('markAllPresent');
  String get noStudentsInClass => _t('noStudentsInClass');
  String get selectAssignment => _t('selectAssignment');
  String get newAssessment => _t('newAssessment');
  String get typeLabel => _t('typeLabel');
  String get typeExam => _t('typeExam');
  String get typeHomework => _t('typeHomework');
  String get typeTest => _t('typeTest');
  String get dateLabel => _t('dateLabel');
  String get term => _t('term');
  String get outOf => _t('outOf');
  String get noAssessments => _t('noAssessments');
  String get saveGrades => _t('saveGrades');
  String get gradesSaved => _t('gradesSaved');
  String get gradeOutOfRange => _t('gradeOutOfRange');

  String assessmentTypeName(AssessmentType t) => switch (t) {
        AssessmentType.exam => _t('typeExam'),
        AssessmentType.homework => _t('typeHomework'),
        AssessmentType.test => _t('typeTest'),
      };

  // Timetable
  String get selectClass => _t('selectClass');
  String get addSession => _t('addSession');
  String get sessionLabel => _t('sessionLabel');
  String get dayLabel => _t('dayLabel');
  String get roomLabel => _t('roomLabel');
  String get startTimeLabel => _t('startTimeLabel');
  String get endTimeLabel => _t('endTimeLabel');
  String get endAfterStart => _t('endAfterStart');
  String get noSessions => _t('noSessions');
  String get needClassSubjectsFirst => _t('needClassSubjectsFirst');

  /// Localized weekday name. [weekday] is ISO: 1 = Monday … 7 = Sunday.
  String dayName(int weekday) {
    final names = _days[_lang] ?? _days['en']!;
    return names[(weekday - 1).clamp(0, 6)];
  }

  static const Map<String, List<String>> _days = {
    'ar': ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'],
    'fr': ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'],
    'en': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
  };

  // Multi-school + delete
  String get switchSchool => _t('switchSchool');
  String get dangerZone => _t('dangerZone');
  String get deleteSchool => _t('deleteSchool');
  String get deleteSchoolWarning => _t('deleteSchoolWarning');
  String get typeNameToConfirm => _t('typeNameToConfirm');

  /// Localized term name, e.g. "Trimestre 2" / "الفصل 2" / "Semester 1".
  String termName(TermType type, int idx) {
    final prefix = type == TermType.trimester ? _t('trimester') : _t('semester');
    return '$prefix $idx';
  }

  static const Map<String, Map<String, String>> _values = {
    'appName': {'ar': 'مدرسة', 'fr': 'Madrasa', 'en': 'Madrasa'},
    'loading': {'ar': 'جارٍ التحميل…', 'fr': 'Chargement…', 'en': 'Loading…'},
    'retry': {'ar': 'إعادة المحاولة', 'fr': 'Réessayer', 'en': 'Retry'},
    'refresh': {'ar': 'تحديث', 'fr': 'Actualiser', 'en': 'Refresh'},
    'pendingActivationTitle': {
      'ar': 'بانتظار التفعيل',
      'fr': 'En attente d’activation',
      'en': 'Pending activation',
    },
    'pendingActivationBody': {
      'ar': 'تم إنشاء مدرستك لكنها غير مفعّلة بعد. يرجى التواصل معنا لتفعيلها.',
      'fr': "Votre école est créée mais pas encore activée. Contactez-nous pour l'activer.",
      'en': 'Your school is created but not activated yet. Please contact us to activate it.',
    },
    'signOut': {'ar': 'تسجيل الخروج', 'fr': 'Se déconnecter', 'en': 'Sign out'},
    'continue': {'ar': 'متابعة', 'fr': 'Continuer', 'en': 'Continue'},

    'signInTitle': {'ar': 'تسجيل الدخول', 'fr': 'Connexion', 'en': 'Sign in'},
    'phoneLabel': {'ar': 'رقم الهاتف', 'fr': 'Numéro de téléphone', 'en': 'Phone number'},
    'phoneHint': {'ar': 'XXXXXXXX', 'fr': 'XXXXXXXX', 'en': 'XXXXXXXX'},
    'phoneRequired': {
      'ar': 'يرجى إدخال رقم الهاتف',
      'fr': 'Veuillez saisir le numéro',
      'en': 'Please enter your phone number',
    },
    'sendCode': {'ar': 'إرسال الرمز', 'fr': 'Envoyer le code', 'en': 'Send code'},

    'otpTitle': {'ar': 'إدخال الرمز', 'fr': 'Saisir le code', 'en': 'Enter code'},
    'otpSentTo': {
      'ar': 'تم إرسال رمز التحقق إلى {phone}',
      'fr': 'Un code a été envoyé au {phone}',
      'en': 'A code was sent to {phone}',
    },
    'otpLabel': {'ar': 'رمز التحقق', 'fr': 'Code de vérification', 'en': 'Verification code'},
    'otpRequired': {'ar': 'يرجى إدخال الرمز', 'fr': 'Veuillez saisir le code', 'en': 'Please enter the code'},
    'verify': {'ar': 'تحقق', 'fr': 'Vérifier', 'en': 'Verify'},
    'resendCode': {'ar': 'إعادة إرسال الرمز', 'fr': 'Renvoyer le code', 'en': 'Resend code'},
    'changeNumber': {'ar': 'تغيير الرقم', 'fr': 'Changer de numéro', 'en': 'Change number'},
    'invalidCode': {
      'ar': 'الرمز خاطئ أو منتهي الصلاحية',
      'fr': 'Code invalide ou expiré',
      'en': 'Invalid or expired code',
    },
    'genericError': {
      'ar': 'حدث خطأ، حاول مرة أخرى',
      'fr': 'Une erreur est survenue, réessayez',
      'en': 'Something went wrong, please try again',
    },

    'chooseRole': {'ar': 'اختر الحساب', 'fr': 'Choisir le profil', 'en': 'Choose profile'},
    'chooseAccess': {
      'ar': 'اختر المدرسة والدور',
      'fr': "Choisissez l'école et le rôle",
      'en': 'Choose school and role',
    },
    'roleDirector': {'ar': 'مدير', 'fr': 'Directeur', 'en': 'Director'},
    'roleTeacher': {'ar': 'أستاذ', 'fr': 'Enseignant', 'en': 'Teacher'},
    'roleParent': {'ar': 'ولي أمر', 'fr': 'Parent', 'en': 'Parent'},
    'notLinkedTitle': {
      'ar': 'الحساب غير مرتبط',
      'fr': 'Compte non associé',
      'en': 'Account not linked',
    },
    'notLinkedBody': {
      'ar': 'رقمك غير مسجّل في أي مدرسة بعد. يرجى التواصل مع إدارة مدرستك.',
      'fr': "Votre numéro n'est encore associé à aucune école. Contactez l'administration.",
      'en': 'Your number is not linked to any school yet. Please contact your school administration.',
    },

    'save': {'ar': 'حفظ', 'fr': 'Enregistrer', 'en': 'Save'},
    'cancel': {'ar': 'إلغاء', 'fr': 'Annuler', 'en': 'Cancel'},
    'add': {'ar': 'إضافة', 'fr': 'Ajouter', 'en': 'Add'},
    'create': {'ar': 'إنشاء', 'fr': 'Créer', 'en': 'Create'},
    'edit': {'ar': 'تعديل', 'fr': 'Modifier', 'en': 'Edit'},
    'delete': {'ar': 'حذف', 'fr': 'Supprimer', 'en': 'Delete'},
    'comingSoon': {'ar': 'قريباً', 'fr': 'Bientôt', 'en': 'Coming soon'},

    'welcomeTitle': {'ar': 'مرحباً بك', 'fr': 'Bienvenue', 'en': 'Welcome'},
    'welcomeBody': {
      'ar': 'أنشئ مدرستك للبدء كمدير، أو انتظر أن تضيفك مدرستك.',
      'fr': "Créez votre école pour commencer en tant que directeur, ou attendez que votre école vous ajoute.",
      'en': 'Create your school to start as a director, or wait for your school to add you.',
    },
    'createSchoolCta': {'ar': 'إنشاء مدرسة', 'fr': 'Créer une école', 'en': 'Create a school'},
    'schoolName': {'ar': 'اسم المدرسة', 'fr': "Nom de l'école", 'en': 'School name'},
    'termTypeLabel': {'ar': 'نظام الفصول', 'fr': 'Découpage', 'en': 'Term structure'},
    'trimester': {'ar': 'الفصل', 'fr': 'Trimestre', 'en': 'Term'},
    'semester': {'ar': 'السداسي', 'fr': 'Semestre', 'en': 'Semester'},
    'gradeMaxLabel': {'ar': 'العلامة القصوى', 'fr': 'Note maximale', 'en': 'Grade scale (max)'},
    'waitingNote': {
      'ar': 'إذا أضافتك مدرستك، تأكد أن رقمك صحيح لديهم.',
      'fr': "Si votre école vous a ajouté, vérifiez que votre numéro est correct chez eux.",
      'en': 'If your school added you, make sure they have your correct number.',
    },

    'navDashboard': {'ar': 'الرئيسية', 'fr': 'Accueil', 'en': 'Dashboard'},
    'navClasses': {'ar': 'الأقسام', 'fr': 'Classes', 'en': 'Classes'},
    'navSubjects': {'ar': 'المواد', 'fr': 'Matières', 'en': 'Subjects'},
    'navTeachers': {'ar': 'الأساتذة', 'fr': 'Enseignants', 'en': 'Teachers'},
    'navStudents': {'ar': 'التلاميذ', 'fr': 'Élèves', 'en': 'Students'},
    'navTimetable': {'ar': 'الجدول', 'fr': 'Emploi du temps', 'en': 'Timetable'},
    'navAnnouncements': {'ar': 'الإعلانات', 'fr': 'Annonces', 'en': 'Announcements'},
    'navSettings': {'ar': 'الإعدادات', 'fr': 'Paramètres', 'en': 'Settings'},

    'schoolSettings': {'ar': 'إعدادات المدرسة', 'fr': "Paramètres de l'école", 'en': 'School settings'},
    'schoolYears': {'ar': 'السنوات الدراسية', 'fr': 'Années scolaires', 'en': 'School years'},
    'addYear': {'ar': 'إضافة سنة', 'fr': 'Ajouter une année', 'en': 'Add year'},
    'yearLabel': {'ar': 'السنة (مثال 2026-2027)', 'fr': 'Année (ex. 2026-2027)', 'en': 'Year (e.g. 2026-2027)'},
    'startDate': {'ar': 'تاريخ البداية', 'fr': 'Date de début', 'en': 'Start date'},
    'endDate': {'ar': 'تاريخ النهاية', 'fr': 'Date de fin', 'en': 'End date'},
    'activeYear': {'ar': 'نشطة', 'fr': 'Active', 'en': 'Active'},
    'setActive': {'ar': 'تعيين كنشطة', 'fr': 'Rendre active', 'en': 'Set active'},
    'noYears': {'ar': 'لا توجد سنوات بعد.', 'fr': 'Aucune année pour le moment.', 'en': 'No years yet.'},
    'termsWord': {'ar': 'الفصول', 'fr': 'Périodes', 'en': 'Terms'},
    'sectionComingSoon': {
      'ar': 'هذا القسم قيد الإنشاء.',
      'fr': 'Cette section est en cours de construction.',
      'en': 'This section is under construction.',
    },

    'academicYear': {'ar': 'السنة الدراسية', 'fr': 'Année scolaire', 'en': 'Academic year'},
    'addClass': {'ar': 'إضافة قسم', 'fr': 'Ajouter une classe', 'en': 'Add class'},
    'className': {'ar': 'اسم القسم', 'fr': 'Nom de la classe', 'en': 'Class name'},
    'classNameHint': {
      'ar': 'مثال: السنة الأولى أ',
      'fr': 'ex. 1ère année A',
      'en': 'e.g. 1st year A',
    },
    'noClasses': {'ar': 'لا توجد أقسام بعد.', 'fr': 'Aucune classe pour le moment.', 'en': 'No classes yet.'},
    'needYearFirst': {
      'ar': 'أنشئ سنة دراسية أولاً من الإعدادات.',
      'fr': "Créez d'abord une année scolaire dans les Paramètres.",
      'en': 'Create a school year first, in Settings.',
    },
    'addSubject': {'ar': 'إضافة مادة', 'fr': 'Ajouter une matière', 'en': 'Add subject'},
    'subjectName': {'ar': 'اسم المادة', 'fr': 'Nom de la matière', 'en': 'Subject name'},
    'noSubjects': {'ar': 'لا توجد مواد بعد.', 'fr': 'Aucune matière pour le moment.', 'en': 'No subjects yet.'},

    'fullNameLabel': {'ar': 'الاسم الكامل', 'fr': 'Nom complet', 'en': 'Full name'},
    'addTeacher': {'ar': 'إضافة أستاذ', 'fr': 'Ajouter un enseignant', 'en': 'Add teacher'},
    'noTeachers': {'ar': 'لا يوجد أساتذة بعد.', 'fr': 'Aucun enseignant pour le moment.', 'en': 'No teachers yet.'},
    'pendingTeacher': {
      'ar': 'لم يسجّل الدخول بعد',
      'fr': "Pas encore connecté",
      'en': 'Has not signed in yet',
    },

    'classSubjectsTitle': {
      'ar': 'المواد والمعاملات',
      'fr': 'Matières & coefficients',
      'en': 'Subjects & coefficients',
    },
    'assignSubject': {'ar': 'إضافة مادة', 'fr': 'Ajouter une matière', 'en': 'Add subject'},
    'coefficientLabel': {'ar': 'المعامل', 'fr': 'Coefficient', 'en': 'Coefficient'},
    'selectSubject': {'ar': 'اختر المادة', 'fr': 'Choisir la matière', 'en': 'Select subject'},
    'teacherLabel': {'ar': 'الأستاذ', 'fr': 'Enseignant', 'en': 'Teacher'},
    'unassignedTeacher': {'ar': '— بدون أستاذ —', 'fr': '— Aucun —', 'en': '— None —'},
    'noAssignedSubjects': {
      'ar': 'لم تُضف مواد لهذا القسم بعد.',
      'fr': 'Aucune matière assignée à cette classe.',
      'en': 'No subjects assigned to this class yet.',
    },
    'allSubjectsAssigned': {
      'ar': 'كل المواد مُضافة.',
      'fr': 'Toutes les matières sont assignées.',
      'en': 'All subjects are already assigned.',
    },
    'needSubjectsFirst': {
      'ar': 'أنشئ مواد أولاً من قسم المواد.',
      'fr': "Créez d'abord des matières dans la section Matières.",
      'en': 'Create subjects first, in the Subjects section.',
    },

    'newAnnouncement': {'ar': 'إعلان جديد', 'fr': 'Nouvelle annonce', 'en': 'New announcement'},
    'announcementTitle': {'ar': 'العنوان', 'fr': 'Titre', 'en': 'Title'},
    'announcementBody': {'ar': 'النص', 'fr': 'Message', 'en': 'Message'},
    'audienceLabel': {'ar': 'الجمهور', 'fr': 'Destinataires', 'en': 'Audience'},
    'audienceTeachers': {'ar': 'الأساتذة', 'fr': 'Enseignants', 'en': 'Teachers'},
    'audienceParents': {'ar': 'أولياء الأمور', 'fr': 'Parents', 'en': 'Parents'},
    'audienceBoth': {'ar': 'الجميع', 'fr': 'Tous', 'en': 'Both'},
    'scopeLabel': {'ar': 'النطاق', 'fr': 'Portée', 'en': 'Scope'},
    'wholeSchool': {'ar': 'كل المدرسة', 'fr': "Toute l'école", 'en': 'Whole school'},
    'noAnnouncements': {'ar': 'لا توجد إعلانات بعد.', 'fr': 'Aucune annonce pour le moment.', 'en': 'No announcements yet.'},

    'overview': {'ar': 'نظرة عامة', 'fr': "Vue d'ensemble", 'en': 'Overview'},
    'statClasses': {'ar': 'الأقسام', 'fr': 'Classes', 'en': 'Classes'},
    'statStudents': {'ar': 'التلاميذ', 'fr': 'Élèves', 'en': 'Students'},
    'statTeachers': {'ar': 'الأساتذة', 'fr': 'Enseignants', 'en': 'Teachers'},
    'statSubjects': {'ar': 'المواد', 'fr': 'Matières', 'en': 'Subjects'},
    'noActiveYear': {
      'ar': 'لا توجد سنة نشطة. أنشئ سنة دراسية من الإعدادات.',
      'fr': "Aucune année active. Créez une année scolaire dans les Paramètres.",
      'en': 'No active year. Create a school year in Settings.',
    },

    'addStudent': {'ar': 'إضافة تلميذ', 'fr': 'Ajouter un élève', 'en': 'Add student'},
    'studentName': {'ar': 'اسم التلميذ', 'fr': "Nom de l'élève", 'en': 'Student name'},
    'noStudents': {'ar': 'لا يوجد تلاميذ بعد.', 'fr': 'Aucun élève pour le moment.', 'en': 'No students yet.'},
    'parentPhone1': {'ar': 'هاتف ولي الأمر 1', 'fr': 'Téléphone parent 1', 'en': 'Parent phone 1'},
    'parentPhone2': {'ar': 'هاتف ولي الأمر 2', 'fr': 'Téléphone parent 2', 'en': 'Parent phone 2'},

    'todayTab': {'ar': 'اليوم', 'fr': "Aujourd'hui", 'en': 'Today'},
    'gradesTab': {'ar': 'العلامات', 'fr': 'Notes', 'en': 'Grades'},
    'noSessionsToday': {'ar': 'لا توجد حصص اليوم.', 'fr': "Aucun cours aujourd'hui.", 'en': 'No sessions today.'},
    'present': {'ar': 'حاضر', 'fr': 'Présent', 'en': 'Present'},
    'absent': {'ar': 'غائب', 'fr': 'Absent', 'en': 'Absent'},
    'late': {'ar': 'متأخر', 'fr': 'Retard', 'en': 'Late'},
    'markAllPresent': {'ar': 'الكل حاضر', 'fr': 'Tous présents', 'en': 'All present'},
    'noStudentsInClass': {'ar': 'لا يوجد تلاميذ في هذا القسم.', 'fr': 'Aucun élève dans cette classe.', 'en': 'No students in this class.'},
    'selectAssignment': {'ar': 'القسم / المادة', 'fr': 'Classe / matière', 'en': 'Class / subject'},
    'newAssessment': {'ar': 'تقييم جديد', 'fr': 'Nouvelle évaluation', 'en': 'New assessment'},
    'typeLabel': {'ar': 'النوع', 'fr': 'Type', 'en': 'Type'},
    'typeExam': {'ar': 'امتحان', 'fr': 'Examen', 'en': 'Exam'},
    'typeHomework': {'ar': 'واجب', 'fr': 'Devoir', 'en': 'Homework'},
    'typeTest': {'ar': 'اختبار', 'fr': 'Test', 'en': 'Test'},
    'dateLabel': {'ar': 'التاريخ', 'fr': 'Date', 'en': 'Date'},
    'term': {'ar': 'الفصل', 'fr': 'Période', 'en': 'Term'},
    'outOf': {'ar': 'من', 'fr': 'sur', 'en': 'out of'},
    'noAssessments': {'ar': 'لا توجد تقييمات بعد.', 'fr': 'Aucune évaluation pour le moment.', 'en': 'No assessments yet.'},
    'saveGrades': {'ar': 'حفظ العلامات', 'fr': 'Enregistrer les notes', 'en': 'Save grades'},
    'gradesSaved': {'ar': 'تم حفظ العلامات', 'fr': 'Notes enregistrées', 'en': 'Grades saved'},
    'gradeOutOfRange': {
      'ar': 'بعض العلامات تتجاوز الحد الأقصى.',
      'fr': 'Certaines notes dépassent le maximum.',
      'en': 'Some grades exceed the maximum.',
    },

    'selectClass': {'ar': 'اختر القسم', 'fr': 'Choisir la classe', 'en': 'Select class'},
    'addSession': {'ar': 'إضافة حصة', 'fr': 'Ajouter un cours', 'en': 'Add session'},
    'sessionLabel': {'ar': 'المادة', 'fr': 'Matière', 'en': 'Subject'},
    'dayLabel': {'ar': 'اليوم', 'fr': 'Jour', 'en': 'Day'},
    'roomLabel': {'ar': 'القاعة', 'fr': 'Salle', 'en': 'Room'},
    'startTimeLabel': {'ar': 'وقت البداية', 'fr': 'Heure de début', 'en': 'Start time'},
    'endTimeLabel': {'ar': 'وقت النهاية', 'fr': 'Heure de fin', 'en': 'End time'},
    'endAfterStart': {
      'ar': 'يجب أن يكون وقت النهاية بعد البداية.',
      'fr': "L'heure de fin doit être après le début.",
      'en': 'End time must be after the start.',
    },
    'noSessions': {'ar': 'لا توجد حصص بعد.', 'fr': 'Aucun cours pour le moment.', 'en': 'No sessions yet.'},
    'needClassSubjectsFirst': {
      'ar': 'أضف مواداً لهذا القسم أولاً (من قسم الأقسام).',
      'fr': "Assignez d'abord des matières à cette classe (section Classes).",
      'en': 'Assign subjects to this class first (in Classes).',
    },

    'switchSchool': {'ar': 'تبديل المدرسة', 'fr': "Changer d'école", 'en': 'Switch school'},
    'dangerZone': {'ar': 'منطقة الخطر', 'fr': 'Zone sensible', 'en': 'Danger zone'},
    'deleteSchool': {'ar': 'حذف المدرسة', 'fr': "Supprimer l'école", 'en': 'Delete school'},
    'deleteSchoolWarning': {
      'ar': 'سيؤدي هذا إلى حذف المدرسة وكل بياناتها نهائياً (الأقسام، التلاميذ، العلامات، الحضور…). لا يمكن التراجع.',
      'fr': "Ceci supprime définitivement l'école et toutes ses données (classes, élèves, notes, présences…). Irréversible.",
      'en': 'This permanently deletes the school and all its data (classes, students, grades, attendance…). This cannot be undone.',
    },
    'typeNameToConfirm': {
      'ar': 'اكتب اسم المدرسة للتأكيد',
      'fr': "Tapez le nom de l'école pour confirmer",
      'en': 'Type the school name to confirm',
    },
  };
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['ar', 'fr', 'en'].contains(locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) async => AppStrings(locale);

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}

extension AppStringsX on BuildContext {
  AppStrings get s => AppStrings.of(this);
}
