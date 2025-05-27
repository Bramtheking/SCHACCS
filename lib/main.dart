import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:schaccs/firebase_options.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'screens/splash_screen.dart';
import 'screens/school_code_screen.dart';
import 'screens/login_screen.dart';
import 'screens/verification_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/statement_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/super_admin_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Pre-open the box for recent school codes
  await Hive.openBox<String>('recent_school_codes');

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(SchaccsApp());
}

class SchaccsApp extends StatelessWidget {
  const SchaccsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SCHACCS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: StadiumBorder(),
            minimumSize: Size(0, 50),
          ),
        ),
        primarySwatch: MaterialColor(
          0xFFB8692E,
          <int, Color>{
            50: Color(0xFFF8EDE5),
            100: Color(0xFFF1D4C4),
            200: Color(0xFFE7B19D),
            300: Color(0xFFDD8E76),
            400: Color(0xFFD86F55),
            500: Color(0xFFCF5D3F),
            600: Color(0xFFB8692E),
            700: Color(0xFF9C5725),
            800: Color(0xFF7F431D),
            900: Color(0xFF613115),
          },
        ),
        scaffoldBackgroundColor: Colors.white,
      ),
      initialRoute: SplashScreen.routeName,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case SplashScreen.routeName:
            return MaterialPageRoute(builder: (_) => SplashScreen());
          case SchoolCodeScreen.routeName:
            return MaterialPageRoute(builder: (_) => SchoolCodeScreen());
          case LoginScreen.routeName:
            final code = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => LoginScreen(schoolCode: code),
            );
          case VerificationScreen.routeName:
            final code = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => VerificationScreen(schoolCode: code),
            );
          case RegistrationScreen.routeName:
            final code = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => RegistrationScreen(schoolCode: code),
            );
          case StatementScreen.routeName:
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => StatementScreen(
                schoolCode: args['school'],
                parentDocId: args['parentDocId'],
              ),
            );
          case AdminDashboard.routeName:
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => AdminDashboard(
                schoolCode: args['school'],
                adminDocId: args['adminDocId'],
              ),
            );
          case SuperAdminDashboard.routeName:
            return MaterialPageRoute(builder: (_) => SuperAdminDashboard());
          default:
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                body: Center(child: Text('Unknown route: ${settings.name}')),
              ),
            );
        }
      },
    );
  }
}
