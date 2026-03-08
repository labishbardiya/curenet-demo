import 'package:curenet/screens/login_options_screen.dart';
import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'screens/splash_screen.dart';
import 'screens/language_select_screen.dart';
import 'screens/login_options_screen.dart';
import 'screens/login_mobile_screen.dart';
import 'screens/login_otp_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/health_locker_screen.dart';
import 'screens/edge_cases_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/records_screen.dart';
import 'screens/qr_share_screen.dart';
import 'screens/access_request_screen.dart';
import 'screens/access_granted_screen.dart';
import 'screens/doc_scan_screen.dart';
import 'core/voice_helper.dart';


void main() {
  runApp(const CureNetApp());
}

class CureNetApp extends StatelessWidget {
  const CureNetApp({super.key});

  @override
  Widget build(BuildContext context) {
    VoiceHelper.init();
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
        '/profile': (context) => const ProfileScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/health-locker': (context) => const HealthLockerScreen(),
        '/edge': (context) => const EdgeCasesScreen(),
        '/chat': (context) => const ChatScreen(),
        '/records': (context) => const RecordsScreen(),
        '/qr-share': (context) => const QrShareScreen(),
        '/access-req': (context) => const AccessRequestScreen(),
        '/access-ok': (context) => const AccessGrantedScreen(),
        '/doc-scan': (context) => const DocScanScreen(),
      },
    );
  }
}
