import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Center(
        child: user == null
            ? Text('No user logged in.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Welcome!', style: TextStyle(fontSize: 24)),
                  SizedBox(height: 16),
                  Text('User ID:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(user.email ?? user.uid, style: TextStyle(fontSize: 18)),
                  SizedBox(height: 32),
                  ElevatedButton.icon(
                    icon: Icon(Icons.logout),
                    label: Text('Logout'),
                    onPressed: () => _logout(context),
                  ),
                ],
              ),
      ),
    );
  }
}