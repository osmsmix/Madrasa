/// Runtime configuration. The defaults below let a bare `flutter run` work with
/// no flags. They can still be overridden per environment (staging/prod) with
/// `--dart-define=SUPABASE_URL=...`, which wins over the default.
///
/// The anon/publishable key is meant to live in client code — Row-Level Security
/// is what actually protects the data, so embedding it here is expected.
class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ldgbaoupsuzvyufzfeps.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_ZOfYr-x_5RhN5zJjK4WLPw_ht_JVZEO',
  );

  /// Default country dialing code (no '+'). Mauritania = 222.
  /// Phones are stored everywhere as E.164 WITHOUT '+', e.g. 222XXXXXXXX.
  static const defaultCountryCode = String.fromEnvironment(
    'DEFAULT_COUNTRY_CODE',
    defaultValue: '222',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
