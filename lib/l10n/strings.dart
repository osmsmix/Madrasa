import 'package:flutter/material.dart';

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
  String get roleDirector => _t('roleDirector');
  String get roleTeacher => _t('roleTeacher');
  String get roleParent => _t('roleParent');
  String get notLinkedTitle => _t('notLinkedTitle');
  String get notLinkedBody => _t('notLinkedBody');

  static const Map<String, Map<String, String>> _values = {
    'appName': {'ar': 'مدرسة', 'fr': 'Madrasa', 'en': 'Madrasa'},
    'loading': {'ar': 'جارٍ التحميل…', 'fr': 'Chargement…', 'en': 'Loading…'},
    'retry': {'ar': 'إعادة المحاولة', 'fr': 'Réessayer', 'en': 'Retry'},
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
