import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/home/presentation/pages/home_page.dart';

class PhuotThuApp extends StatelessWidget {
  const PhuotThuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PhuotThu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomePage(),
    );
  }
}
