import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'services/fcm_service.dart';
import 'screens/agency_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Init FCM listeners only — do NOT request permission here.
  // Permission is requested after splash so the user sees the app first.
  await FcmService.init();

  await Supabase.initialize(
    url: 'https://mwsalkbgpfhchocjkxay.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im13c2Fsa2JncGZoY2hvY2preGF5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2NjExOTcsImV4cCI6MjA5NzIzNzE5N30.pSUb9YzYfT3hFO3wga1ltpBwUZF44iXfsxCPRyiErd8',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PH Global',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      navigatorKey: FcmService.navigatorKey,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 4), () async {
      if (!mounted) return;

      // Request notification permission after splash — user sees the app
      // context first, making the permission prompt feel natural.
      await FcmService.requestPermission();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AgencyListScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 247, 242, 242),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/applogo.png',
              width: 180,
              height: 180,
            ),
            const SizedBox(height: 20),
            const Text(
              "PH GLOBAL",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const Text(
              "APPOINTMENT NOTIFIER",
              style: TextStyle(
                fontSize: 14,
                letterSpacing: 3,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 50),
            const SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 6,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "LOADING...",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}