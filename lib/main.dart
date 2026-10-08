import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/database_helper.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize local SQLite database for offline operations
  final dbHelper = DatabaseHelper.instance;
  await dbHelper.database;

  // Initialize Better Auth service & restore saved token
  final authService = AuthService(
    defaultBaseUrl: 'https://new-chat-ms8iyb8qq-redaniums-projects.vercel.app',
  );
  await authService.initialize();

  // Initialize API service wired with Better Auth bearer interceptor
  final apiService = ApiService(
    customBaseUrl: authService.baseUrl,
    authService: authService,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: authService),
        Provider<ApiService>.value(value: apiService),
        Provider<DatabaseHelper>.value(value: dbHelper),
      ],
      child: const PharmaCrmApp(),
    ),
  );
}

class PharmaCrmApp extends StatelessWidget {
  const PharmaCrmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pharma CRM DZ - Délégué Médical',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E), // Teal 700
          primary: const Color(0xFF0F766E),
          secondary: const Color(0xFF0284C7), // Sky 600
          surface: const Color(0xFFF8FAFC),
        ),
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          color: Colors.white,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    if (!authService.isInitialized) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0F766E)),
        ),
      );
    }

    if (authService.isAuthenticated) {
      return const DashboardScreen();
    }

    return const LoginScreen();
  }
}
