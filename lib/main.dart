import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/router/app_router.dart';
import 'core/config/app_config.dart';
import 'features/auth/data/auth_refresh_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppConfig.validate();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );

  final supabase = Supabase.instance.client;

  final authRefreshNotifier = AuthRefreshNotifier(supabase);

  final router = createAppRouter(
    isAuthenticated: () => supabase.auth.currentSession != null,
    refreshListenable: authRefreshNotifier,
  );

  runApp(ProviderScope(child: PhuotThuApp(router: router)));
}
