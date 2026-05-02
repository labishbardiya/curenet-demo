import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'core/app_router.dart';
import 'core/data_mode.dart';

import 'package:provider/provider.dart';
import 'core/auth_provider.dart';
import 'services/consent_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DataMode.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ConsentManager()),
      ],
      child: const CureNetApp(),
    ),
  );
}

class CureNetApp extends StatelessWidget {
  const CureNetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CureNet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRouter.splash,
      routes: AppRouter.routes,
    );
  }
}
