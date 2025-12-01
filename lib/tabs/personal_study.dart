// personal_study.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

/// Notion Mixed Accent - PersonalStudyPage
/// - Replace your existing personal_study.dart with this file
/// - Constructor requires uid (keeps compatibility)
/// - Accent colors: blue (default), red (high), orange (medium), green (done)

class PersonalStudyPage extends StatefulWidget {
  final String uid;
  final VoidCallback? onCalendarTap;

  const PersonalStudyPage({super.key, required this.uid, this.onCalendarTap});

  @override
  State<PersonalStudyPage> createState() => _PersonalStudyPageState();
}

class _PersonalStudyPageState extends State<PersonalStudyPage> {
  bool _searching = false;
  final TextEditingController _searchController = TextEditingController();
  GoalFilterState _filter = const GoalFilterState();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color get accent => const Color(0xFF4F46E5); // indigo-violet accent

  @override
  Widget build(BuildContext context) {
    if (widget.uid.isEmpty) {
      return const Scaffold(body: _EmptyState(isSignedOut: true));
    }

    return Scaffold(
      appBar: _buildAppBar(context),
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Column(
        children: [
          _NotionFilterBar(
            filter: _filter,
            onChange: (f) => setState(() => _filter = f),
            accent: accent,
          ),
          Expanded(
            child: _GoalsList(
              uid: widget.uid,
              filter: _filter,
              searchQuery: _searchController.text.trim().toLowerCase(),
              accent: accent,
            ),
          ),
        ],
      ),
      floatingActionButton: _AddGoalFab(
        uid: widget.uid,
        accent: accent,
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      elevation: 0,
      centerTitle: false,
      backgroundColor: Theme.of(context).colorScheme.background,
      title: _searching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration.collapsed(
                hintText: 'Search goals & tasks...',
              ),
              onChanged: (v) {
                setState(() {});
              },
              style: TextStyle(color: Theme.of(context).colorScheme.onBackground),
            )
          : Text('Personal Study', style: TextStyle(color: Theme.of(context).colorScheme.onBackground)),
      actions: [
        IconButton(
          icon: Icon(_searching ? Icons.close : Icons.search, color: Theme.of(context).colorScheme.onBackground),
          onPressed: () {
            setState(() {
              if (_searching) {
                _searchController.clear();
              }
              _searching = !_searching;
            });
          },
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onBackground),
          onSelected: (v) {
            if (v == 'completed') {
              setState(() => _filter = _filter.copyWith(showCompleted: true));
            } else if (v == 'active') {
              setState(() => _filter = _filter.copyWith(showCompleted: false));
            } else if (v == 'reset') {
              setState(() => _filter = const GoalFilterState());
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'active', child: Text('Active')),
            PopupMenuItem(value: 'completed', child: Text('Completed')),
            PopupMenuItem(value: 'reset', child: Text('Reset filters')),
          ],
        ),
      ],
    );
  }
}

// -------------------------------
// MODELS
// -------------------------------

@immutable
class GoalFilterState {
  final String priority; // 'All'|'High'|'Medium'|'Low'
  final String sortBy; // 'createdAt'|'priority'|'targetDate'
  final bool showCompleted;

  const GoalFilterState({
    this.priority = 'All',
    this.sortBy = 'createdAt',
    this.showCompleted = false,
  });

  GoalFilterState copyWith({String? priority, String? sortBy, bool? showCompleted}) {
    return GoalFilterState(
      priority: priority ?? this.priority,
      sortBy: sortBy ?? this.sortBy,
      showCompleted: showCompleted ?? this.showCompleted,
    );
  }
}

class StudyGoal {
  final String id;
  final String title;
  final String description;
  final String priority; // 'High','Medium','Low'
  final DateTime? targetDate;
  final bool completed;
  final int taskCount;
  final int completedTaskCount;
  final double progress;
  final DateTime? createdAt;
  final List<String> tags;

  StudyGoal({
    required this.id,
    required this.title,
    this.description = '',
    this.priority = 'Medium',
    this.targetDate,
    this.completed = false,
    this.taskCount = 0,
    this.completedTaskCount = 0,
    this.progress = 0.0,
    this.createdAt,
    this.tags = const [],
  });

  factory StudyGoal.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return StudyGoal(
      id: doc.id,
      title: (data['title'] ?? 'Untitled') as String,
      description: (data['description'] ?? '') as String,
      priority: (data['priority'] ?? 'Medium') as String,
      targetDate: (data['targetDate'] as Timestamp?)?.toDate(),
      completed: data['completed'] ?? false,
      taskCount: data['taskCount'] ?? 0,
      completedTaskCount: data['completedTaskCount'] ?? 0,
      progress: (data['progress'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      tags: (data['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'priority': priority,
      'targetDate': targetDate != null ? Timestamp.fromDate(targetDate!) : null,
      'completed': completed,
      'taskCount': taskCount,
      'completedTaskCount': completedTaskCount,
      'progress': progress,
      'tags': tags,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  bool get isOverdue => targetDate != null && targetDate!.isBefore(DateTime.now()) && !completed;
}

// Task model
class StudyTask {
  final String id;
  final String title;
  final String description;
  final bool completed;
  final DateTime? dueDate;
  final int order;
  final String priority;
  final List<String> tags;

  StudyTask({
    required this.id,
    required this.title,
    this.description = '',
    this.completed = false,
    this.dueDate,
    this.order = 0,
    this.priority = 'Medium',
    this.tags = const [],
  });

  factory StudyTask.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return StudyTask(
      id: doc.id,
      title: (data['title'] ?? 'Untitled') as String,
      description: (data['description'] ?? '') as String,
      completed: data['completed'] ?? false,
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      order: data['order'] ?? 0,
      priority: (data['priority'] ?? 'Medium') as String,
      tags: (data['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'completed': completed,
        'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
        'order': order,
        'priority': priority,
        'tags': tags,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };
}

// -------------------------------
// FILTER BAR (Notion style minimal)
// -------------------------------

class _NotionFilterBar extends StatelessWidget {
  final GoalFilterState filter;
  final ValueChanged<GoalFilterState> onChange;
  final Color accent;

  const _NotionFilterBar({required this.filter, required this.onChange, required this.accent});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.03);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.background,
      child: Row(
        children: [
          // Left: priority chips
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip(context, 'All', filter.priority == 'All'),
                  const SizedBox(width: 8),
                  _filterChip(context, 'High', filter.priority == 'High', color: Colors.red),
                  const SizedBox(width: 8),
                  _filterChip(context, 'Medium', filter.priority == 'Medium', color: Colors.orange),
                  const SizedBox(width: 8),
                  _filterChip(context, 'Low', filter.priority == 'Low', color: Colors.blue),
                ],
              ),
            ),
          ),

          // Right: completed toggle
          const SizedBox(width: 8),
          IconButton(
            tooltip: filter.showCompleted ? 'Showing completed' : 'Show completed',
            icon: Icon(filter.showCompleted ? Icons.check_circle : Icons.check_circle_outline),
            onPressed: () => onChange(filter.copyWith(showCompleted: !filter.showCompleted)),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(BuildContext context, String label, bool selected, {Color? color}) {
    final textColor = selected ? Colors.white : Theme.of(context).colorScheme.onBackground;
    final bg = selected ? (color ?? accent) : Colors.transparent;
    final border = selected ? Colors.transparent : Colors.transparent;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChange(filter.copyWith(priority: label)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// -------------------------------
// GOALS LIST (core list; stream + processing)
// -------------------------------

class _GoalsList extends StatelessWidget {
  final String uid;
  final GoalFilterState filter;
  final String searchQuery;
  final Color accent;

  const _GoalsList({required this.uid, required this.filter, required this.searchQuery, required this.accent});

  Query<Map<String, dynamic>> _baseQuery() {
    final col = FirebaseFirestore.instance.collection('users').doc(uid).collection('goals');
    return col.orderBy(filter.sortBy == 'createdAt' ? 'createdAt' : filter.sortBy, descending: filter.sortBy == 'createdAt');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _baseQuery().snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _ErrorView(message: snapshot.error.toString());
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        // map and filter client-side: stable, and allows flexible searching + priority filter
        var goals = docs.map((d) => StudyGoal.fromDoc(d)).toList();

        if (filter.priority != 'All') {
          goals = goals.where((g) => g.priority == filter.priority).toList();
        }
        if (!filter.showCompleted) {
          goals = goals.where((g) => g.completed == false).toList();
        }
        if (searchQuery.isNotEmpty) {
          final q = searchQuery.toLowerCase();
          goals = goals.where((g) => g.title.toLowerCase().contains(q) || g.description.toLowerCase().contains(q) || g.tags.any((t) => t.toLowerCase().contains(q))).toList();
        }

        // final sort by chosen property
        goals.sort((a, b) => _compare(a, b, filter.sortBy));

        if (goals.isEmpty) {
          return const _EmptyState();
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          itemCount: goals.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final g = goals[i];
            return _GoalBlock(goal: g, uid: uid, accent: accent);
          },
        );
      },
    );
  }

  int _compare(StudyGoal a, StudyGoal b, String sortBy) {
    switch (sortBy) {
      case 'priority':
        const order = {'High': 0, 'Medium': 1, 'Low': 2};
        return (order[a.priority] ?? 3).compareTo(order[b.priority] ?? 3);
      case 'targetDate':
        if (a.targetDate == null && b.targetDate == null) return 0;
        if (a.targetDate == null) return 1;
        if (b.targetDate == null) return -1;
        return a.targetDate!.compareTo(b.targetDate!);
      default:
        if (a.createdAt == null || b.createdAt == null) return 0;
        return b.createdAt!.compareTo(a.createdAt!);
    }
  }
}

// -------------------------------
// GOAL BLOCK (Notion-like block)
// -------------------------------

class _GoalBlock extends StatelessWidget {
  final StudyGoal goal;
  final String uid;
  final Color accent;

  const _GoalBlock({required this.goal, required this.uid, required this.accent});

  Color _priorityColor() {
    switch (goal.priority) {
      case 'High':
        return Colors.redAccent;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final prColor = _priorityColor();
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(10),
      elevation: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // top row: title + actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GoalLeadingCheckbox(
                  completed: goal.completed,
                  onToggle: () => _toggleGoal(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(goal.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                      if (goal.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(goal.description, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.75), fontSize: 13)),
                        ),
                      const SizedBox(height: 10),
                      // tags & meta
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (goal.targetDate != null)
                            _MetaPill(icon: Icons.calendar_today_outlined, label: _shortDate(goal.targetDate!), color: Colors.grey.shade600),
                          _MetaPill(icon: Icons.flag, label: goal.priority, color: prColor),
                          _MetaPill(icon: Icons.task_alt, label: '${(goal.progress * 100).round()}% • ${goal.completedTaskCount}/${goal.taskCount}', color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                          for (final t in goal.tags) _MetaPill(icon: Icons.label, label: t, color: accent.withOpacity(0.9)),
                        ],
                      ),
                    ],
                  ),
                ),
                // menu
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') _openEdit(context);
                    if (v == 'delete') _delete(context);
                    if (v == 'open') _openDetails(context);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'open', child: Text('Open')),
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // subtle divider + progress bar
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: (goal.progress.clamp(0.0, 1.0)),
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                    color: accent,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(width: 10),
                Text('${(goal.progress * 100).round()}%', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
              ],
            ),
            // open details button
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _openDetails(context),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _startPomodoro(context),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Start Session'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _shortDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dOnly = DateTime(d.year, d.month, d.day);
    if (dOnly == today) return 'Today';
    if (dOnly == today.add(const Duration(days: 1))) return 'Tomorrow';
    return DateFormat('MMM d').format(d);
  }

  void _openDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => _GoalDetailsSheet(goal: goal, uid: uid),
    );
  }

  void _openEdit(BuildContext context) {
    showDialog(context: context, builder: (_) => _GoalFormDialog(uid: uid, existingGoal: goal));
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Goal?'),
        content: const Text('This will delete the goal and its tasks. Proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    final snackC = ScaffoldMessenger.of(context);
    final loading = showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final tasksColl = FirebaseFirestore.instance.collection('users').doc(uid).collection('goals').doc(goal.id).collection('tasks');
      final tasksSnap = await tasksColl.get();
      final batch = FirebaseFirestore.instance.batch();
      for (final t in tasksSnap.docs) batch.delete(t.reference);
      batch.delete(FirebaseFirestore.instance.collection('users').doc(uid).collection('goals').doc(goal.id));
      await batch.commit();
      if (context.mounted) {
        Navigator.pop(context); // pop loading
        snackC.showSnackBar(const SnackBar(content: Text('Goal deleted')));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        snackC.showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Future<void> _toggleGoal(BuildContext context) async {
    try {
      final goalRef = FirebaseFirestore.instance.collection('users').doc(uid).collection('goals').doc(goal.id);
      await goalRef.update({
        'completed': !goal.completed,
        'completedAt': !goal.completed ? FieldValue.serverTimestamp() : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // (Optional) If marking completed you might want to update tasks too — keep manual for user control.
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  void _startPomodoro(BuildContext context) {
    // Simply show a snackbar as placeholder. In your app integrate with Pomodoro tab.
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Start Pomodoro for "${goal.title}" (open Pomodoro tab)')));
  }
}

class _GoalLeadingCheckbox extends StatelessWidget {
  final bool completed;
  final VoidCallback onToggle;
  const _GoalLeadingCheckbox({required this.completed, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: completed ? Colors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: completed ? Colors.green : Colors.grey.shade300, width: 1.6),
        ),
        child: Icon(completed ? Icons.check : Icons.circle_outlined, size: 18, color: completed ? Colors.white : Colors.grey),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaPill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: color.withOpacity(0.06)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color.withOpacity(0.9)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9))),
      ]),
    );
  }
}

// -------------------------------
// DETAILS SHEET (shows tasks, quick add)
// -------------------------------

class _GoalDetailsSheet extends StatefulWidget {
  final StudyGoal goal;
  final String uid;
  const _GoalDetailsSheet({required this.goal, required this.uid});

  @override
  State<_GoalDetailsSheet> createState() => _GoalDetailsSheetState();
}

class _GoalDetailsSheetState extends State<_GoalDetailsSheet> {
  final TextEditingController _quickController = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _quickController.dispose();
    super.dispose();
  }

  Future<void> _addQuickTask() async {
    final text = _quickController.text.trim();
    if (text.isEmpty) return;
    setState(() => _adding = true);
    try {
      final tasksColl = FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('goals').doc(widget.goal.id).collection('tasks');
      final newDoc = await tasksColl.add({
        'title': text,
        'completed': false,
        'createdAt': FieldValue.serverTimestamp(),
        'order': 9999
      });
      // increment counts atomically
      final goalRef = FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('goals').doc(widget.goal.id);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(goalRef);
        final prevCount = snap.data()?['taskCount'] ?? 0;
        tx.update(goalRef, {'taskCount': (prevCount as int) + 1, 'updatedAt': FieldValue.serverTimestamp()});
      });
      _quickController.clear();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Add failed: $e')));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surface;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(width: 48, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: Text(widget.goal.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _onEdit),
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: _onDelete),
            ]),
          ),
          if (widget.goal.description.isNotEmpty)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text(widget.goal.description)),
          const Divider(height: 1),
          Expanded(child: _TaskList(uid: widget.uid, goalId: widget.goal.id)),
          Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 12, left: 16, right: 16, top: 10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _quickController,
                  decoration: InputDecoration(hintText: 'Add a quick task', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  onSubmitted: (_) => _addQuickTask(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _adding ? null : _addQuickTask, child: _adding ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add)),
            ]),
          ),
        ],
      ),
    );
  }

  void _onEdit() {
    showDialog(context: context, builder: (_) => _GoalFormDialog(uid: widget.uid, existingGoal: widget.goal));
  }

  void _onDelete() async {
    final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Delete goal?'), content: const Text('Delete goal and its tasks?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))]));
    if (confirmed != true) return;
    final snack = ScaffoldMessenger.of(context);
    final loading = showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final batch = FirebaseFirestore.instance.batch();
      final tasks = await FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('goals').doc(widget.goal.id).collection('tasks').get();
      for (final t in tasks.docs) batch.delete(t.reference);
      batch.delete(FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('goals').doc(widget.goal.id));
      await batch.commit();
      if (context.mounted) {
        Navigator.pop(context);
        snack.showSnackBar(const SnackBar(content: Text('Goal deleted')));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        snack.showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }
}

// -------------------------------
// TASK LIST inside details (streamed)
// -------------------------------

class _TaskList extends StatelessWidget {
  final String uid;
  final String goalId;
  const _TaskList({required this.uid, required this.goalId});

  Future<void> _recalc(String uid, String goalId) async {
    final tasksSnap = await FirebaseFirestore.instance.collection('users').doc(uid).collection('goals').doc(goalId).collection('tasks').get();
    final total = tasksSnap.docs.length;
    final completed = tasksSnap.docs.where((d) => (d.data()['completed'] ?? false) == true).length;
    final progress = total == 0 ? 0.0 : (completed / total);
    await FirebaseFirestore.instance.collection('users').doc(uid).collection('goals').doc(goalId).update({
      'taskCount': total,
      'completedTaskCount': completed,
      'progress': progress,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final tasksQuery = FirebaseFirestore.instance.collection('users').doc(uid).collection('goals').doc(goalId).collection('tasks').orderBy('order').orderBy('createdAt');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: tasksQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(12), child: Text('No tasks yet — add your first task.')));
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, i) {
            final d = docs[i];
            final task = StudyTask.fromDoc(d);
            return Slidable(
              key: ValueKey(d.id),
              endActionPane: ActionPane(motion: const DrawerMotion(), children: [
                SlidableAction(onPressed: (_) => _editTask(context, d.id, task), backgroundColor: Colors.blue, icon: Icons.edit, label: 'Edit'),
                SlidableAction(onPressed: (_) async {
                  await d.reference.delete();
                  await _recalc(uid, goalId);
                }, backgroundColor: Colors.red, icon: Icons.delete, label: 'Delete'),
              ]),
              child: ListTile(
                onTap: () => _editTask(context, d.id, task),
                leading: GestureDetector(
                  onTap: () async {
                    await d.reference.update({'completed': !task.completed, 'updatedAt': FieldValue.serverTimestamp()});
                    await _recalc(uid, goalId);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: task.completed ? Colors.green : Colors.grey.shade300), color: task.completed ? Colors.green : Colors.transparent),
                    child: Icon(task.completed ? Icons.check : Icons.circle_outlined, color: task.completed ? Colors.white : Colors.grey),
                  ),
                ),
                title: Text(task.title, style: task.completed ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey) : null),
                subtitle: _taskSubtitle(task),
                trailing: task.priority.isNotEmpty ? Text(task.priority, style: const TextStyle(fontSize: 12)) : null,
              ),
            );
          },
        );
      },
    );
  }

  Widget _taskSubtitle(StudyTask task) {
    final List<String> parts = [];
    if (task.dueDate != null) parts.add(DateFormat('MMM d').format(task.dueDate!));
    if (task.description.isNotEmpty) parts.add(task.description);
    if (task.tags.isNotEmpty) parts.add(task.tags.join(', '));
    return parts.isEmpty ? const SizedBox.shrink() : Text(parts.join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis);
  }

  void _editTask(BuildContext context, String id, StudyTask task) {
    showDialog(context: context, builder: (_) => _TaskFormDialog(uid: uid, goalId: goalId, taskId: id, existingTask: task));
  }
}

// -------------------------------
// GOAL FORM DIALOG (Add / Edit)
// -------------------------------

class _GoalFormDialog extends StatefulWidget {
  final String uid;
  final StudyGoal? existingGoal;
  const _GoalFormDialog({required this.uid, this.existingGoal});

  @override
  State<_GoalFormDialog> createState() => _GoalFormDialogState();
}

class _GoalFormDialogState extends State<_GoalFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _tagController = TextEditingController();

  late String _title;
  late String _description;
  String _priority = 'Medium';
  DateTime? _targetDate;
  List<String> _tags = [];
  bool _saving = false;

  bool get _isEditing => widget.existingGoal != null;

  @override
  void initState() {
    super.initState();
    final g = widget.existingGoal;
    _title = g?.title ?? '';
    _description = g?.description ?? '';
    _priority = g?.priority ?? 'Medium';
    _targetDate = g?.targetDate;
    _tags = List.from(g?.tags ?? []);
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _saving = true);
    final goalsRef = FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('goals');
    try {
      if (_isEditing) {
        await goalsRef.doc(widget.existingGoal!.id).update({
          'title': _title,
          'description': _description,
          'priority': _priority,
          'targetDate': _targetDate != null ? Timestamp.fromDate(_targetDate!) : null,
          'tags': _tags,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await goalsRef.add({
          'title': _title,
          'description': _description,
          'priority': _priority,
          'targetDate': _targetDate != null ? Timestamp.fromDate(_targetDate!) : null,
          'tags': _tags,
          'completed': false,
          'taskCount': 0,
          'completedTaskCount': 0,
          'progress': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEditing ? 'Goal updated' : 'Goal created')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: _targetDate ?? now, firstDate: now.subtract(const Duration(days: 365)), lastDate: DateTime(now.year + 5));
    if (picked != null) setState(() => _targetDate = picked);
  }

  void _addTag() {
    final t = _tagController.text.trim();
    if (t.isEmpty) return;
    if (!_tags.contains(t)) setState(() => _tags.add(t));
    _tagController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Goal' : 'New Goal'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(initialValue: _title, decoration: const InputDecoration(labelText: 'Title'), validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null, onSaved: (v) => _title = v!.trim()),
            const SizedBox(height: 12),
            TextFormField(initialValue: _description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3, onSaved: (v) => _description = v ?? ''),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(value: _priority, items: const [DropdownMenuItem(value: 'High', child: Text('High')), DropdownMenuItem(value: 'Medium', child: Text('Medium')), DropdownMenuItem(value: 'Low', child: Text('Low'))], onChanged: (v) => setState(() => _priority = v ?? 'Medium'), decoration: const InputDecoration(labelText: 'Priority'))),
              const SizedBox(width: 12),
              Expanded(child: ListTile(contentPadding: EdgeInsets.zero, title: Text(_targetDate == null ? 'No due' : DateFormat('MMM d, y').format(_targetDate!)), leading: const Icon(Icons.calendar_today), trailing: IconButton(icon: const Icon(Icons.edit), onPressed: _pickDate))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _tagController, decoration: const InputDecoration(labelText: 'Add tag', hintText: 'e.g., Math'), onSubmitted: (_) => _addTag())),
              IconButton(icon: const Icon(Icons.add_circle), onPressed: _addTag),
            ]),
            const SizedBox(height: 8),
            if (_tags.isNotEmpty)
              Wrap(spacing: 8, children: _tags.map((t) => Chip(label: Text(t), onDeleted: () => setState(() => _tags.remove(t)))).toList()),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_isEditing ? 'Save' : 'Create')),
      ],
    );
  }
}

// -------------------------------
// TASK FORM DIALOG
// -------------------------------

class _TaskFormDialog extends StatefulWidget {
  final String uid;
  final String goalId;
  final String? taskId;
  final StudyTask? existingTask;

  const _TaskFormDialog({required this.uid, required this.goalId, this.taskId, this.existingTask});

  @override
  State<_TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<_TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _tagController = TextEditingController();
  late String _title;
  late String _description;
  DateTime? _dueDate;
  String _priority = 'Medium';
  List<String> _tags = [];
  bool _saving = false;

  bool get _isEditing => widget.existingTask != null;

  @override
  void initState() {
    super.initState();
    final t = widget.existingTask;
    _title = t?.title ?? '';
    _description = t?.description ?? '';
    _priority = t?.priority ?? 'Medium';
    _dueDate = t?.dueDate;
    _tags = List.from(t?.tags ?? []);
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _saving = true);
    final tasksRef = FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('goals').doc(widget.goalId).collection('tasks');
    try {
      if (_isEditing) {
        await tasksRef.doc(widget.taskId!).update({
          'title': _title,
          'description': _description,
          'priority': _priority,
          'dueDate': _dueDate != null ? Timestamp.fromDate(_dueDate!) : null,
          'tags': _tags,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final newDoc = await tasksRef.add({
          'title': _title,
          'description': _description,
          'priority': _priority,
          'dueDate': _dueDate != null ? Timestamp.fromDate(_dueDate!) : null,
          'tags': _tags,
          'completed': false,
          'createdAt': FieldValue.serverTimestamp(),
          'order': 9999,
        });
        // optionally write to calendar collection (your original logic)
        if (_dueDate != null) {
          await FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('calendar').doc(newDoc.id).set({
            'title': _title,
            'description': _description,
            'date': Timestamp.fromDate(_dueDate!),
            'type': 'task',
            'goalId': widget.goalId,
            'taskId': newDoc.id,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
      // recalc parent progress
      await _recalcParent();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task saved')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _recalcParent() async {
    final tasksSnap = await FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('goals').doc(widget.goalId).collection('tasks').get();
    final total = tasksSnap.docs.length;
    final completed = tasksSnap.docs.where((d) => (d.data()['completed'] ?? false) == true).length;
    final progress = total == 0 ? 0.0 : (completed / total);
    await FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('goals').doc(widget.goalId).update({
      'taskCount': total,
      'completedTaskCount': completed,
      'progress': progress,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: _dueDate ?? now, firstDate: now.subtract(const Duration(days: 365)), lastDate: DateTime(now.year + 5));
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _addTag() {
    final t = _tagController.text.trim();
    if (t.isEmpty) return;
    if (!_tags.contains(t)) setState(() => _tags.add(t));
    _tagController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Task' : 'New Task'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(initialValue: _title, decoration: const InputDecoration(labelText: 'Title'), validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null, onSaved: (v) => _title = v!.trim()),
            const SizedBox(height: 12),
            TextFormField(initialValue: _description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2, onSaved: (v) => _description = v ?? ''),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(value: _priority, items: const [DropdownMenuItem(value: 'High', child: Text('High')), DropdownMenuItem(value: 'Medium', child: Text('Medium')), DropdownMenuItem(value: 'Low', child: Text('Low'))], onChanged: (v) => setState(() => _priority = v ?? 'Medium'), decoration: const InputDecoration(labelText: 'Priority'))),
              const SizedBox(width: 12),
              Expanded(child: ListTile(contentPadding: EdgeInsets.zero, title: Text(_dueDate == null ? 'No due' : DateFormat('MMM d, y').format(_dueDate!)), leading: const Icon(Icons.calendar_today), trailing: IconButton(icon: const Icon(Icons.edit), onPressed: _pickDate))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _tagController, decoration: const InputDecoration(labelText: 'Add tag'))),
              IconButton(icon: const Icon(Icons.add), onPressed: _addTag),
            ]),
            const SizedBox(height: 8),
            if (_tags.isNotEmpty) Wrap(spacing: 8, children: _tags.map((t) => Chip(label: Text(t), onDeleted: () => setState(() => _tags.remove(t)))).toList()),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_isEditing ? 'Save' : 'Add')),
      ],
    );
  }
}

// -------------------------------
// ADD GOAL FAB
// -------------------------------

class _AddGoalFab extends StatelessWidget {
  final String uid;
  final Color accent;
  const _AddGoalFab({required this.uid, required this.accent});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => showDialog(context: context, builder: (_) => _GoalFormDialog(uid: uid)),
      icon: Icon(Icons.add, color: Colors.white),
      label: const Text('New Goal'),
      backgroundColor: accent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

// -------------------------------
// Empty & Error Views
// -------------------------------

class _EmptyState extends StatelessWidget {
  final bool isSignedOut;
  const _EmptyState({this.isSignedOut = false});

  @override
  Widget build(BuildContext context) {
    if (isSignedOut) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.person_outline, size: 80, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text('Sign in to manage your study goals', style: TextStyle(color: Colors.grey.shade700)),
      ]));
    }

    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.lightbulb_outline, size: 72, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text('No goals yet', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text('Tap "New Goal" to create your first study block', style: TextStyle(color: Colors.grey.shade600)),
    ]));
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
      const SizedBox(height: 12),
      Text('Something went wrong', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
    ])));
  }
}
