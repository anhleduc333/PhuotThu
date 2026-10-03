class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static void validate() {
    if (supabaseUrl.isEmpty) {
      throw StateError(
        'Missing SUPABASE_URL. '
        'Run the app with --dart-define=SUPABASE_URL=...',
      );
    }

    if (supabasePublishableKey.isEmpty) {
      throw StateError(
        'Missing SUPABASE_PUBLISHABLE_KEY. '
        'Run the app with --dart-define=SUPABASE_PUBLISHABLE_KEY=...',
      );
    }
  }
}
