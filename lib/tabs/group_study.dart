import 'package:flutter/material.dart';

class GroupStudyPage extends StatelessWidget {
  const GroupStudyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: const [
        Icon(Icons.group, size: 48),
        SizedBox(height: 8),
        Text('Group Study area'),
      ]),
    );
  }
}