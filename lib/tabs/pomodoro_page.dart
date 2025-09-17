import 'package:flutter/material.dart';

class PomodoroPage extends StatelessWidget {
  const PomodoroPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: const [
        Icon(Icons.timer, size: 48),
        SizedBox(height: 8),
        Text('Pomodoro Timer coming soon'),
      ]),
    );
  }
}