import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/listing_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const RozRidesApp());
}

class RozRidesApp extends StatelessWidget {
  const RozRidesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ListingProvider()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        title: 'RozRides',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        // The splash plays once. Its nextScreen is the AuthWrapper which
        // routes to Home or Login based on persisted Firebase auth state.
        home: const SplashScreen(nextScreen: AuthWrapper()),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // While Firebase is restoring the persisted session
    if (authProvider.status == AuthStatus.loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0B1E),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
          ),
        ),
      );
    }

    // Already logged in (Firebase persisted the session) → go straight to Home
    if (authProvider.currentUser != null) {
      return const HomeScreen();
    }

    // Not logged in → show Login
    return const LoginScreen();
  }
}
