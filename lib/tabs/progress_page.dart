import 'package:flutter/material.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: const [
        Icon(Icons.bar_chart, size: 48),
        SizedBox(height: 8),
        Text('Progress & Stats'),
      ]),
    );
  }
}