import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart';
import 'homepage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyDGrMXGEzeDF5gyrtA-2dlL7W2JnTi10mk",
          authDomain: "study-planner-sync.firebaseapp.com",
          projectId: "study-planner-sync",
          storageBucket: "study-planner-sync.appspot.com",
          messagingSenderId: "371621892269",
          appId: "1:371621892269:web:d5468add0a0644213df624",
          measurementId: "G-WJEHY32X05",
        ),
      );
    } else {
      // For Android/iOS
      await Firebase.initializeApp();
    }
    print("Firebase initialized successfully");
  } catch (e) {
    print("Firebase initialization error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Study Sync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AuthWrapper(), // Use AuthWrapper instead of directly going to LoginPage
      routes: {
        '/home': (context) => const HomePage(),
        '/login': (context) => const LoginPage(),
      },
    );
  }
}

// Auth wrapper to handle initial authentication state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading StudySync...'),
                ],
              ),
            ),
          );
        }
        
        // Check for errors
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Restart the app
                      Navigator.of(context).pushReplacementNamed('/login');
                    },
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          );
        }
        
        // Check if user is signed in
        if (snapshot.hasData && snapshot.data != null) {
          // User is signed in, go to home page
          return const HomePage();
        } else {
          // User is not signed in, go to login page
          return const LoginPage();
        }
      },
    );
  }
}