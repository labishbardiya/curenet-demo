import 'package:curenet/screens/login_options_screen.dart';
import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'screens/splash_screen.dart';
import 'screens/language_select_screen.dart';
import 'screens/login_options_screen.dart';
import 'screens/login_mobile_screen.dart';
import 'screens/login_otp_screen.dart';
import 'screens/home_screen.dart';


void main() {
  runApp(const CureNetApp());
}

class CureNetApp extends StatelessWidget {
  const CureNetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CureNet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        // We will add more routes as we build each screen
        '/language-select': (context) => const LanguageSelectScreen(),
        '/login-options': (context) => const LoginOptionsScreen(),
        '/login-mobile': (context) => const LoginMobileScreen(),
        '/login-otp': (context) => const LoginOtpScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
