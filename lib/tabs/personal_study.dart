import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PersonalStudyPage extends StatelessWidget {
  final String uid;
  const PersonalStudyPage({super.key, required this.uid});

  // helper to open add-goal form and write to Firestore
  Future<void> _showAddGoalDialog(BuildContext context) async {
    if (uid.isEmpty) return;

    String title = '';
    String description = '';
    String priority = 'Medium';
    String tags = '';
    String estimated = '';
    bool recurring = false;
    DateTime? targetDate;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Add New Goal'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: 'Title *'),
                    onChanged: (v) => title = v,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                    onChanged: (v) => description = v,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(labelText: 'Estimated minutes'),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => estimated = v,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: priority,
                          items: const [
                            DropdownMenuItem(value: 'Low', child: Text('Low')),
                            DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                            DropdownMenuItem(value: 'High', child: Text('High')),
                          ],
                          onChanged: (v) => setState(() => priority = v ?? 'Medium'),
                          decoration: const InputDecoration(labelText: 'Priority'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Tags (comma separated)'),
                    onChanged: (v) => tags = v,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(targetDate == null ? 'No target date' : 'Target: ${targetDate!.toLocal().toString().split(' ')[0]}'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                          );
                          if (picked != null) setState(() => targetDate = picked);
                        },
                        child: const Text('Pick date'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Recurring'),
                      const Spacer(),
                      Switch(value: recurring, onChanged: (v) => setState(() => recurring = v)),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (title.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title is required')));
                    return;
                  }

                  final goalsRef = FirebaseFirestore.instance.collection('users').doc(uid).collection('goals');
                  await goalsRef.add({
                    'title': title.trim(),
                    'description': description.trim(),
                    'priority': priority,
                    'tags': tags.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
                    'estimatedMinutes': int.tryParse(estimated) ?? 0,
                    'recurring': recurring,
                    'targetDate': targetDate != null ? Timestamp.fromDate(targetDate!) : null,
                    'completed': false,
                    'createdAt': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  if (context.mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Goal added')));
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) {
      return const Center(child: Text('Sign in to see your tasks.'));
    }

    // Build combined UI: Add Goal button, goals list and tasks list
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Personal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddGoalDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Goal'),
            ),
          ],
        ),

        // Goals stream
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('goals')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
            }
            final goals = snap.data?.docs ?? [];
            if (goals.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: Text('No goals yet.')),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: goals.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, i) {
                final g = goals[i].data();
                final completed = g['completed'] == true;
                final target = g['targetDate'] is Timestamp ? (g['targetDate'] as Timestamp).toDate() : null;
                return ListTile(
                  title: Text(
                    g['title'] ?? 'Untitled',
                    style: TextStyle(decoration: completed ? TextDecoration.lineThrough : TextDecoration.none),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((g['description'] ?? '').toString().isNotEmpty) Text(g['description'] ?? ''),
                      if (target != null) Text('Target: ${target.toLocal().toString().split(' ')[0]}'),
                      if ((g['priority'] ?? '').toString().isNotEmpty) Text('Priority: ${g['priority']}'),
                    ],
                  ),
                  trailing: IconButton(
                    icon: Icon(completed ? Icons.check_circle : Icons.check_circle_outline, color: completed ? Colors.green : null),
                    onPressed: () async {
                      await FirebaseFirestore.instance.collection('users').doc(uid).collection('goals').doc(goals[i].id).update({
                        'completed': !completed,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                    },
                  ),
                );
              },
            );
          },
        ),

        const SizedBox(height: 12),

        const Divider(),
        // Existing tasks list (kept for reference)
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('tasks')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
            }
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No personal tasks found.')),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final d = docs[index].data();
                final completed = d['completed'] == true;
                return ListTile(
                  title: Text(
                    d['title'] ?? 'Untitled',
                    style: TextStyle(
                      decoration: completed ? TextDecoration.lineThrough : TextDecoration.none,
                    ),
                  ),
                  subtitle: Text(d['meta'] ?? ''),
                );
              },
            );
          },
        ),
      ],
    );
  }
}