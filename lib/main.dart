import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login.dart';
import 'homepage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: kIsWeb
        ? const FirebaseOptions(
             apiKey: "AIzaSyDGrMXGEzeDF5gyrtA-2dlL7W2JnTi10mk",
  authDomain: "study-planner-sync.firebaseapp.com",
  projectId: "study-planner-sync",
  storageBucket: "study-planner-sync.firebasestorage.app",
  messagingSenderId: "371621892269",
  appId: "1:371621892269:web:d5468add0a0644213df624",
  measurementId: "G-WJEHY32X05"
          )
        : null, // Let it auto-load native configs from android/ios
  );

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Study Sync',
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
      routes: {
        '/home': (context) => HomePage(),
        '/login': (context) => LoginPage(),
      },
    );
  }
}
