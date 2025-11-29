import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

/// Full, advanced PersonalStudyPage with parent goals + child tasks (single file)
/// - Keep this file in place of your existing personal_study.dart
/// - Constructor requires uid (keeps compatibility with your homepage.dart)

class PersonalStudyPage extends StatefulWidget {
  final String uid;
  final VoidCallback? onCalendarTap;

  const PersonalStudyPage({super.key, required this.uid, this.onCalendarTap});

  @override
  State<PersonalStudyPage> createState() => _PersonalStudyPageState();
}

class _PersonalStudyPageState extends State<PersonalStudyPage> {
  GoalFilterState _filterState = const GoalFilterState();
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    if (widget.uid.isEmpty) {
      return const Scaffold(body: _EmptyStateView(isSignedOut: true));
    }

    return Scaffold(
      // AppBar now minimal like Google Tasks
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search tasks...',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _filterState = _filterState.copyWith(
                      searchQuery: value.toLowerCase(),
                    );
                  });
                },
              )
            : const Text('Study Tasks'),
        elevation: 0,
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  _filterState = _filterState.copyWith(searchQuery: "");
                });
              },
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'completed') {
                setState(
                  () =>
                      _filterState = _filterState.copyWith(showCompleted: true),
                );
              } else if (v == 'active') {
                setState(
                  () => _filterState = _filterState.copyWith(
                    showCompleted: false,
                  ),
                );
              } else if (v == 'priority') {
                _showPriorityMenu(context);
              } else if (v == 'sort') {
                _showSortMenu(context);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'active', child: Text('Active')),
              PopupMenuItem(value: 'completed', child: Text('Completed')),
              PopupMenuItem(value: 'priority', child: Text('Priority')),
              PopupMenuItem(value: 'sort', child: Text('Sort')),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          // Top chips that behave like Google Tasks lists
          _FilterBar(
            filterState: _filterState,
            onFilterChanged: (newState) =>
                setState(() => _filterState = newState),
          ),
          Expanded(
            child: _GoalsListView(uid: widget.uid, filterState: _filterState),
          ),
        ],
      ),
      floatingActionButton: _AddGoalFAB(uid: widget.uid),
    );
  }

  void _showPriorityMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPriorityOption(context, 'All', Icons.all_inclusive, null),
            _buildPriorityOption(context, 'High', Icons.flag, Colors.red),
            _buildPriorityOption(context, 'Medium', Icons.flag, Colors.orange),
            _buildPriorityOption(
              context,
              'Low',
              Icons.flag_outlined,
              Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityOption(
    BuildContext context,
    String priority,
    IconData icon,
    Color? color,
  ) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text('$priority Priority${priority == 'All' ? 'ies' : ''}'),
      onTap: () {
        setState(
          () => _filterState = _filterState.copyWith(priority: priority),
        );
        Navigator.pop(context);
      },
    );
  }

  void _showSortMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSortOption(
              context,
              'createdAt',
              'Date Created',
              Icons.date_range,
            ),
            _buildSortOption(context, 'priority', 'Priority', Icons.flag),
            _buildSortOption(
              context,
              'targetDate',
              'Due Date',
              Icons.calendar_today,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(
    BuildContext context,
    String sortBy,
    String label,
    IconData icon,
  ) {
    final isSelected = _filterState.sortBy == sortBy;
    return ListTile(
      leading: Icon(icon),
      title: Text('Sort by $label'),
      trailing: isSelected ? const Icon(Icons.check) : null,
      onTap: () {
        setState(() => _filterState = _filterState.copyWith(sortBy: sortBy));
        Navigator.pop(context);
      },
    );
  }
}

// ============================================================================
// MODELS
// ============================================================================

@immutable
class GoalFilterState {
  final String priority;
  final String sortBy;
  final bool showCompleted;
  final String searchQuery;

  const GoalFilterState({
    this.priority = 'All',
    this.sortBy = 'createdAt',
    this.showCompleted = false,
    this.searchQuery = '',
  });

  GoalFilterState copyWith({
    String? priority,
    String? sortBy,
    bool? showCompleted,
    String? searchQuery,
  }) {
    return GoalFilterState(
      priority: priority ?? this.priority,
      sortBy: sortBy ?? this.sortBy,
      showCompleted: showCompleted ?? this.showCompleted,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class StudyGoal {
  final String id;
  final String title;
  final String description;
  final String priority;
  final int estimatedMinutes;
  final DateTime? targetDate;
  final List<String> tags;
  final bool completed;
  final int studySessions;
  final int totalStudyMinutes;
  final DateTime? createdAt;
  final int taskCount;
  final int completedTaskCount;
  final double progress;

  StudyGoal({
    required this.id,
    required this.title,
    this.description = '',
    this.priority = 'Medium',
    this.estimatedMinutes = 0,
    this.targetDate,
    this.tags = const [],
    this.completed = false,
    this.studySessions = 0,
    this.totalStudyMinutes = 0,
    this.createdAt,
    this.taskCount = 0,
    this.completedTaskCount = 0,
    this.progress = 0.0,
  });

  factory StudyGoal.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return StudyGoal(
      id: doc.id,
      title: data['title'] ?? 'Untitled',
      description: data['description'] ?? '',
      priority: data['priority'] ?? 'Medium',
      estimatedMinutes: data['estimatedMinutes'] ?? 0,
      targetDate: (data['targetDate'] as Timestamp?)?.toDate(),
      tags: (data['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      completed: data['completed'] ?? false,
      studySessions: data['studySessions'] ?? 0,
      totalStudyMinutes: data['totalStudyMinutes'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      taskCount: data['taskCount'] ?? 0,
      completedTaskCount: data['completedTaskCount'] ?? 0,
      progress: (data['progress'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'priority': priority,
      'estimatedMinutes': estimatedMinutes,
      'targetDate': targetDate != null ? Timestamp.fromDate(targetDate!) : null,
      'tags': tags,
      'completed': completed,
      'studySessions': studySessions,
      'totalStudyMinutes': totalStudyMinutes,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'taskCount': taskCount,
      'completedTaskCount': completedTaskCount,
      'progress': progress,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  bool get isOverdue =>
      targetDate != null && targetDate!.isBefore(DateTime.now()) && !completed;

  Color get priorityColor {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData get priorityIcon {
    return priority == 'Low' ? Icons.flag_outlined : Icons.flag;
  }
}

/// Child Task model
class StudyTask {
  final String id;
  final String title;
  final String description;
  final DateTime? dueDate;
  final bool completed;
  final DateTime? createdAt;
  final int order;
  final List<String> tags; // <--- add this
  final String priority;

  StudyTask({
    required this.id,
    required this.title,
    this.description = '',
    this.dueDate,
    this.completed = false,
    this.createdAt,
    this.order = 0,
    this.tags = const [],
    this.priority = 'Medium',
  });

  factory StudyTask.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return StudyTask(
      id: doc.id,
      title: data['title'] ?? 'Untitled',
      description: data['description'] ?? '',
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      completed: data['completed'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      order: data['order'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
    'completed': completed,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'order': order,
  };
}

// ============================================================================
// FILTER BAR (unchanged logic)
// ============================================================================

class _FilterBar extends StatelessWidget {
  final GoalFilterState filterState;
  final ValueChanged<GoalFilterState> onFilterChanged;

  const _FilterBar({required this.filterState, required this.onFilterChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.03),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Active'),
                    selected: !filterState.showCompleted,
                    onSelected: (_) => onFilterChanged(
                      filterState.copyWith(showCompleted: false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Completed'),
                    selected: filterState.showCompleted,
                    onSelected: (_) => onFilterChanged(
                      filterState.copyWith(showCompleted: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(filterState.priority),
                    selected: filterState.priority != 'All',
                    onSelected: (_) => _showPriorityMenu(context),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () => _showSortMenu(context),
            tooltip: 'Sort',
          ),
        ],
      ),
    );
  }

  void _showPriorityMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPriorityOption(context, 'All', Icons.all_inclusive, null),
            _buildPriorityOption(context, 'High', Icons.flag, Colors.red),
            _buildPriorityOption(context, 'Medium', Icons.flag, Colors.orange),
            _buildPriorityOption(
              context,
              'Low',
              Icons.flag_outlined,
              Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityOption(
    BuildContext context,
    String priority,
    IconData icon,
    Color? color,
  ) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text('$priority Priority${priority == 'All' ? 'ies' : ''}'),
      onTap: () {
        onFilterChanged(filterState.copyWith(priority: priority));
        Navigator.pop(context);
      },
    );
  }

  void _showSortMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSortOption(
              context,
              'createdAt',
              'Date Created',
              Icons.date_range,
            ),
            _buildSortOption(context, 'priority', 'Priority', Icons.flag),
            _buildSortOption(
              context,
              'targetDate',
              'Due Date',
              Icons.calendar_today,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(
    BuildContext context,
    String sortBy,
    String label,
    IconData icon,
  ) {
    final isSelected = filterState.sortBy == sortBy;
    return ListTile(
      leading: Icon(icon),
      title: Text('Sort by $label'),
      trailing: isSelected ? const Icon(Icons.check) : null,
      onTap: () {
        onFilterChanged(filterState.copyWith(sortBy: sortBy));
        Navigator.pop(context);
      },
    );
  }
}

// ============================================================================
// GOALS LIST VIEW + PROCESSING (preserves your logic)
// ============================================================================

class _GoalsListView extends StatelessWidget {
  final String uid;
  final GoalFilterState filterState;

  const _GoalsListView({required this.uid, required this.filterState});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('goals')
          .where('completed', isEqualTo: filterState.showCompleted)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorView(error: snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final goals = _processGoals(snapshot.data?.docs ?? []);

        if (goals.isEmpty) {
          return _EmptyStateView(
            isSignedOut: false,
            isCompleted: filterState.showCompleted,
          );
        }

        // Google Tasks style: a single-column list with subtle dividers
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: goals.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) =>
              _GoalCard(goal: goals[index], uid: uid),
        );
      },
    );
  }

  List<StudyGoal> _processGoals(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    var goals = docs.map((doc) => StudyGoal.fromFirestore(doc)).toList();

    if (filterState.priority != 'All') {
      goals = goals.where((g) => g.priority == filterState.priority).toList();
    }

    if (filterState.searchQuery.isNotEmpty) {
      goals = goals.where((g) {
        final titleMatch = g.title.toLowerCase().contains(
          filterState.searchQuery,
        );
        final descMatch = g.description.toLowerCase().contains(
          filterState.searchQuery,
        );
        return titleMatch || descMatch;
      }).toList();
    }

    goals.sort((a, b) => _compareGoals(a, b, filterState.sortBy));

    return goals;
  }

  int _compareGoals(StudyGoal a, StudyGoal b, String sortBy) {
    switch (sortBy) {
      case 'priority':
        const priorityOrder = {'High': 0, 'Medium': 1, 'Low': 2};
        final aPriority = priorityOrder[a.priority] ?? 3;
        final bPriority = priorityOrder[b.priority] ?? 3;
        return aPriority.compareTo(bPriority);

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

// ============================================================================
// GOAL CARD (Google Tasks style)
// ============================================================================

class _GoalCard extends StatelessWidget {
  final StudyGoal goal;
  final String uid;

  const _GoalCard({required this.goal, required this.uid});

  @override
  Widget build(BuildContext context) {
    // Use ListTile style like Google Tasks: simple, compact, with checkbox and subtle subtitle
    return InkWell(
      onTap: () => _showGoalDetails(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Leading checkbox circle
            GestureDetector(
              onTap: () => _toggleCompletion(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: goal.completed ? Colors.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: goal.completed ? Colors.green : Colors.grey.shade400,
                    width: 1.8,
                  ),
                ),
                child: Icon(
                  goal.completed ? Icons.check : Icons.radio_button_unchecked,
                  color: goal.completed ? Colors.white : Colors.grey,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Title & metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      decoration: goal.completed
                          ? TextDecoration.lineThrough
                          : null,
                      color: goal.completed ? Colors.grey : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (goal.targetDate != null) ...[
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: goal.isOverdue
                              ? Colors.red
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatTargetDateShort(goal.targetDate!),
                          style: TextStyle(
                            fontSize: 13,
                            color: goal.isOverdue
                                ? Colors.red
                                : Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Icon(
                        goal.priorityIcon,
                        size: 14,
                        color: goal.priorityColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${(goal.progress * 100).round()}% • ${goal.completedTaskCount}/${goal.taskCount}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // trailing menu like Google Tasks' three-dot actions
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'edit') {
                  _editGoal(context);
                } else if (v == 'delete') {
                  _deleteGoal(context);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTargetDateShort(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == today.add(const Duration(days: 1))) return 'Tomorrow';
    return DateFormat('MMM d').format(date);
  }

  void _showGoalDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GoalDetailsSheet(goal: goal, uid: uid),
    );
  }

  Future<void> _toggleCompletion(BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('goals')
          .doc(goal.id)
          .update({
            'completed': !goal.completed,
            'completedAt': !goal.completed
                ? FieldValue.serverTimestamp()
                : null,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      // If toggled to completed, optionally mark tasks completed? Keep manual control.
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating goal: $e')));
      }
    }
  }

  void _editGoal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _GoalFormDialog(uid: uid, existingGoal: goal),
    );
  }

  Future<void> _deleteGoal(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal?'),
        content: const Text(
          'This action cannot be undone. Delete goal and its tasks?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Delete all tasks first (batch)
      final tasksColl = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('goals')
          .doc(goal.id)
          .collection('tasks');

      final tasksSnapshot = await tasksColl.get();
      final batch = FirebaseFirestore.instance.batch();
      for (var t in tasksSnapshot.docs) {
        batch.delete(t.reference);
      }
      // delete the goal
      final goalRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('goals')
          .doc(goal.id);
      batch.delete(goalRef);
      await batch.commit();

      if (context.mounted) {
        Navigator.pop(context); // pop loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Goal deleted')));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // pop loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting goal: $e')));
      }
    }
  }
}

// ============================================================================
// GOAL DETAILS SHEET (Google Tasks-style detail sheet)
// ============================================================================

class _GoalDetailsSheet extends StatelessWidget {
  final StudyGoal goal;
  final String uid;

  const _GoalDetailsSheet({required this.goal, required this.uid});

  @override
  Widget build(BuildContext context) {
    // Google Tasks style: clean header, list of tasks below, quick add at bottom
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    goal.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    Navigator.pop(context);
                    _editGoal(context);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    Navigator.pop(context);
                    _deleteGoal(context);
                  },
                ),
              ],
            ),
          ),
          if (goal.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                goal.description,
                style: const TextStyle(color: Colors.black87),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                if (goal.targetDate != null)
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text(_formatFullDateShort(goal.targetDate!)),
                      const SizedBox(width: 12),
                    ],
                  ),
                Icon(goal.priorityIcon, size: 16, color: goal.priorityColor),
                const SizedBox(width: 6),
                Text(
                  '${(goal.progress * 100).round()}% • ${goal.completedTaskCount}/${goal.taskCount} tasks',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Expanded(
                    child: _TaskListView(uid: uid, goalId: goal.id),
                  ),
                ],
              ),
            ),
          ),
          // quick add field like Google Tasks
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) =>
                            _TaskFormDialog(uid: uid, goalId: goal.id),
                      );
                    },
                    child: const Text('Add task'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Go to Pomodoro tab to start studying!'),
                      ),
                    );
                  },
                  child: const Icon(Icons.play_arrow),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatFullDateShort(DateTime date) {
    final hasTime = date.hour != 0 || date.minute != 0;
    if (hasTime) {
      return '${DateFormat('MMM d').format(date)} ${DateFormat('h:mm a').format(date)}';
    }
    return DateFormat('MMM d, y').format(date);
  }

  void _editGoal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _GoalFormDialog(uid: uid, existingGoal: goal),
    );
  }

  Future<void> _deleteGoal(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal?'),
        content: const Text(
          'This action cannot be undone. Delete goal and its tasks?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Delete all tasks first (batch)
      final tasksColl = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('goals')
          .doc(goal.id)
          .collection('tasks');

      final tasksSnapshot = await tasksColl.get();
      final batch = FirebaseFirestore.instance.batch();
      for (var t in tasksSnapshot.docs) {
        batch.delete(t.reference);
      }
      // delete the goal
      final goalRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('goals')
          .doc(goal.id);
      batch.delete(goalRef);
      await batch.commit();

      if (context.mounted) {
        Navigator.pop(context); // pop loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Goal deleted')));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // pop loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting goal: $e')));
      }
    }
  }
}

// ============================================================================
// REUSABLE COMPONENTS (unchanged)
// ============================================================================

class _CompletionCheckbox extends StatelessWidget {
  final bool completed;
  final VoidCallback onToggle;

  const _CompletionCheckbox({required this.completed, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: completed ? Colors.green : Colors.grey,
            width: 2,
          ),
          color: completed ? Colors.green : Colors.transparent,
        ),
        child: Icon(
          completed ? Icons.check : Icons.circle,
          size: 20,
          color: completed ? Colors.white : Colors.transparent,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// GOAL FORM DIALOG (keeps your original fields + tags/time)
// ============================================================================

class _GoalFormDialog extends StatefulWidget {
  final String uid;
  final StudyGoal? existingGoal;

  const _GoalFormDialog({required this.uid, this.existingGoal});

  @override
  State<_GoalFormDialog> createState() => _GoalFormDialogState();
}

class _GoalFormDialogState extends State<_GoalFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tagController = TextEditingController();

  late String _title;
  late String _description;
  late String _priority;
  late String _estimatedMinutes;
  DateTime? _targetDate;
  TimeOfDay? _targetTime;
  late List<String> _tags;

  bool get _isEditing => widget.existingGoal != null;

  @override
  void initState() {
    super.initState();
    final goal = widget.existingGoal;
    _title = goal?.title ?? '';
    _description = goal?.description ?? '';
    _priority = goal?.priority ?? 'Medium';
    _estimatedMinutes = goal?.estimatedMinutes.toString() ?? '';
    _targetDate = goal?.targetDate;
    _tags = List.from(goal?.tags ?? []);

    if (_targetDate != null &&
        (_targetDate!.hour != 0 || _targetDate!.minute != 0)) {
      _targetTime = TimeOfDay(
        hour: _targetDate!.hour,
        minute: _targetDate!.minute,
      );
    }
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Goal' : 'Add New Goal'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTitleField(),
                const SizedBox(height: 16),
                _buildDescriptionField(),
                const SizedBox(height: 16),
                _buildTimeAndPriorityRow(),
                const SizedBox(height: 16),
                _buildDatePicker(),
                const SizedBox(height: 8),
                _buildTimePicker(),
                const SizedBox(height: 16),
                _buildTagInput(),
                if (_tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildTagChips(),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitForm,
          child: Text(_isEditing ? 'Save Changes' : 'Create Goal'),
        ),
      ],
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      initialValue: _title,
      decoration: const InputDecoration(
        labelText: 'Goal Title *',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.title),
      ),
      validator: (v) => v?.trim().isEmpty == true ? 'Title is required' : null,
      onSaved: (v) => _title = v?.trim() ?? '',
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      initialValue: _description,
      decoration: const InputDecoration(
        labelText: 'Description',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.description),
      ),
      maxLines: 3,
      onSaved: (v) => _description = v?.trim() ?? '',
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget _buildTimeAndPriorityRow() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            initialValue: _estimatedMinutes,
            decoration: const InputDecoration(
              labelText: 'Est. Minutes',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.timer),
            ),
            keyboardType: TextInputType.number,
            onSaved: (v) => _estimatedMinutes = v ?? '',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _priority,
            decoration: const InputDecoration(
              labelText: 'Priority',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'Low', child: Text('Low')),
              DropdownMenuItem(value: 'Medium', child: Text('Medium')),
              DropdownMenuItem(value: 'High', child: Text('High')),
            ],
            onChanged: (v) => setState(() => _priority = v ?? 'Medium'),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.calendar_today),
      title: Text(
        _targetDate == null
            ? 'No due date'
            : DateFormat('MMM d, y').format(_targetDate!),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_targetDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() {
                _targetDate = null;
                _targetTime = null;
              }),
            ),
          IconButton(icon: const Icon(Icons.edit), onPressed: _pickDate),
        ],
      ),
    );
  }

  Widget _buildTimePicker() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.access_time),
      title: Text(
        _targetTime == null ? 'No target time' : _targetTime!.format(context),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_targetTime != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => _targetTime = null),
            ),
          IconButton(icon: const Icon(Icons.edit), onPressed: _pickTime),
        ],
      ),
    );
  }

  Widget _buildTagInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _tagController,
            decoration: const InputDecoration(
              labelText: 'Add Tags',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.label),
              hintText: 'e.g., Math',
            ),
            onSubmitted: _addTag,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle, color: Colors.blue),
          onPressed: () => _addTag(_tagController.text),
        ),
      ],
    );
  }

  Widget _buildTagChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _tags.map((tag) {
        return Chip(
          label: Text(tag),
          deleteIcon: const Icon(Icons.close, size: 18),
          onDeleted: () => setState(() => _tags.remove(tag)),
          backgroundColor: Colors.blue.shade50,
        );
      }).toList(),
    );
  }

  void _addTag(String value) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty && !_tags.contains(trimmed)) {
      setState(() {
        _tags.add(trimmed);
        _tagController.clear();
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _targetTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _targetTime = picked);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    DateTime? fullTargetDateTime;
    if (_targetDate != null) {
      if (_targetTime != null) {
        fullTargetDateTime = DateTime(
          _targetDate!.year,
          _targetDate!.month,
          _targetDate!.day,
          _targetTime!.hour,
          _targetTime!.minute,
        );
      } else {
        fullTargetDateTime = _targetDate;
      }
    }

    final goalData = {
      'title': _title,
      'description': _description,
      'priority': _priority,
      'estimatedMinutes': int.tryParse(_estimatedMinutes) ?? 0,
      'targetDate': fullTargetDateTime != null
          ? Timestamp.fromDate(fullTargetDateTime)
          : null,
      'tags': _tags,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      final goalsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('goals');

      if (_isEditing) {
        await goalsRef.doc(widget.existingGoal!.id).update(goalData);
      } else {
        await goalsRef.add({
          ...goalData,
          'completed': false,
          'studySessions': 0,
          'totalStudyMinutes': 0,
          'taskCount': 0,
          'completedTaskCount': 0,
          'progress': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Goal updated successfully!'
                  : 'Goal created successfully!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// ============================================================================
// TASK LIST VIEW
// ============================================================================

class _TaskListView extends StatelessWidget {
  final String uid;
  final String goalId;

  const _TaskListView({required this.uid, required this.goalId});

  Future<void> _recalculateProgress() async {
    final tasksSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('goals')
        .doc(goalId)
        .collection('tasks')
        .get();

    final total = tasksSnap.docs.length;
    final completed = tasksSnap.docs.where((d) {
      final m = d.data() as Map<String, dynamic>;
      return (m['completed'] ?? false) == true;
    }).length;
    final progress = total == 0 ? 0.0 : (completed / total);

    final goalRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('goals')
        .doc(goalId);

    await goalRef.update({
      'taskCount': total,
      'completedTaskCount': completed,
      'progress': progress,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('goals')
          .doc(goalId)
          .collection('tasks')
          .orderBy('order')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error loading tasks: ${snapshot.error}');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final tasksDocs = snapshot.data?.docs ?? [];
        if (tasksDocs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No tasks yet — add one below.'),
          );
        }
        // Google Tasks style: compact task rows with check and simple subtitle
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: tasksDocs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final doc = tasksDocs[i];
            final task = StudyTask.fromFirestore(doc);
            return Slidable(
              key: ValueKey(doc.id),
              endActionPane: ActionPane(
                motion: const DrawerMotion(),
                children: [
                  SlidableAction(
                    onPressed: (_) => showDialog(
                      context: context,
                      builder: (_) => _TaskFormDialog(
                        uid: uid,
                        goalId: goalId,
                        taskId: doc.id,
                        existingTask: task,
                      ),
                    ),
                    icon: Icons.edit,
                    backgroundColor: Colors.blue,
                  ),
                  SlidableAction(
                    onPressed: (_) async {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .collection('goals')
                          .doc(goalId)
                          .collection('tasks')
                          .doc(doc.id)
                          .delete();
                      await _recalculateProgress();
                    },
                    icon: Icons.delete,
                    backgroundColor: Colors.red,
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                leading: GestureDetector(
                  onTap: () async {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('goals')
                        .doc(goalId)
                        .collection('tasks')
                        .doc(doc.id)
                        .update({
                          'completed': !task.completed,
                          'completedAt': !task.completed
                              ? FieldValue.serverTimestamp()
                              : null,
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                    await _recalculateProgress();
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: task.completed ? Colors.green : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: task.completed
                            ? Colors.green
                            : Colors.grey.shade400,
                        width: 1.6,
                      ),
                    ),
                    child: Icon(
                      task.completed
                          ? Icons.check
                          : Icons.radio_button_unchecked,
                      color: task.completed ? Colors.white : Colors.grey,
                      size: 18,
                    ),
                  ),
                ),
                title: Text(
                  task.title,
                  style: task.completed
                      ? const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey,
                        )
                      : null,
                ),
                subtitle: _buildTaskSubtitle(task),
                onTap: () {
                  // open edit dialog
                  showDialog(
                    context: context,
                    builder: (_) => _TaskFormDialog(
                      uid: uid,
                      goalId: goalId,
                      taskId: doc.id,
                      existingTask: task,
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTaskSubtitle(StudyTask task) {
    final parts = <String>[];
    if (task.dueDate != null)
      parts.add(DateFormat('MMM d').format(task.dueDate!));
    if (task.description.isNotEmpty) parts.add(task.description);
    if (task.priority.isNotEmpty) parts.add('Priority: ${task.priority}');
    if (task.tags.isNotEmpty) parts.add(task.tags.join(', '));
    return Text(
      parts.join(' • '),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ============================================================================
// TASK FORM DIALOG (Add/Edit tasks)
// ============================================================================

class _TaskFormDialog extends StatefulWidget {
  final String uid;
  final String goalId;
  final String? taskId;
  final StudyTask? existingTask;

  const _TaskFormDialog({
    required this.uid,
    required this.goalId,
    this.taskId,
    this.existingTask,
  });

  @override
  State<_TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<_TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _title;
  late String _description;
  DateTime? _dueDate;
  int _order = 0;
  List<String> _selectedTags = [];
  String _priority = 'Normal';

  List<String> _tags = [];
  final TextEditingController _tagController = TextEditingController();

  bool get _isEditing => widget.existingTask != null;

  @override
  void initState() {
    super.initState();
    _title = widget.existingTask?.title ?? '';
    _description = widget.existingTask?.description ?? '';
    _dueDate = widget.existingTask?.dueDate;
    _order = widget.existingTask?.order ?? 0;
    _priority = widget.existingTask?.priority ?? 'Medium';
    _tags = List.from(widget.existingTask?.tags ?? []);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Task' : 'Add Task'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: _title,
                decoration: const InputDecoration(labelText: 'Task Title'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter title' : null,
                onSaved: (v) => _title = v!.trim(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _description,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
                onSaved: (v) => _description = v?.trim() ?? '',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: ['Low', 'Medium', 'High']
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setState(() => _priority = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tagController,
                decoration: InputDecoration(
                  labelText: 'Add Tag',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      if (_tagController.text.trim().isEmpty) return;
                      setState(() {
                        _tags.add(_tagController.text.trim());
                        _tagController.clear();
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                children: _tags
                    .map(
                      (tag) => Chip(
                        label: Text(tag),
                        onDeleted: () => setState(() => _tags.remove(tag)),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _dueDate == null
                          ? 'No due date'
                          : DateFormat('MMM d, y').format(_dueDate!),
                    ),
                  ),
                  TextButton(
                    onPressed: _pickDate,
                    child: const Text('Pick Date'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saveTask,
          child: Text(_isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDate: _dueDate ?? now,
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final tasksRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('goals')
        .doc(widget.goalId)
        .collection('tasks');

    final data = {
      'title': _title,
      'description': _description,
      'dueDate': _dueDate != null ? Timestamp.fromDate(_dueDate!) : null,
      'completed': widget.existingTask?.completed ?? false,
      'order': _order,
      'tags': _selectedTags,
      'priority': _priority,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    DocumentReference taskRef;

    if (_isEditing) {
      taskRef = tasksRef.doc(widget.taskId!);
      await taskRef.update(data);
    } else {
      taskRef = await tasksRef.add(data);
    }

    // ✅ Add task to calendar (just like goals)
    if (_dueDate != null) {
      final calendarRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('calendar');

      await calendarRef.doc(taskRef.id).set({
        'title': _title,
        'description': _description,
        'date': Timestamp.fromDate(_dueDate!),
        'type': 'task', // so you can differentiate goals and tasks
        'goalId': widget.goalId,
        'taskId': taskRef.id,
        'priority': _priority,
        'tags': _selectedTags,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // Recalculate parent progress
    await _recalculateParentProgress(widget.uid, widget.goalId);

    if (mounted) Navigator.pop(context);
  }

  Future<void> _recalculateParentProgress(String uid, String goalId) async {
    final tasksSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('goals')
        .doc(goalId)
        .collection('tasks')
        .get();
    final total = tasksSnap.docs.length;
    final completed = tasksSnap.docs
        .where((d) => (d.data()['completed'] ?? false) == true)
        .length;
    final progress = total == 0 ? 0.0 : (completed / total);

    final goalRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('goals')
        .doc(goalId);

    await goalRef.update({
      'taskCount': total,
      'completedTaskCount': completed,
      'progress': progress,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

// ============================================================================
// ADD GOAL FAB (unchanged visual but compact)
// ============================================================================

class _AddGoalFAB extends StatelessWidget {
  final String uid;

  const _AddGoalFAB({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showAddGoalDialog(context),
      tooltip: 'New goal',
      child: const Icon(Icons.add),
    );
  }

  void _showAddGoalDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _GoalFormDialog(uid: uid),
    );
  }
}

// ============================================================================
// EMPTY STATE & ERROR VIEWS (unchanged)
// ============================================================================

class _EmptyStateView extends StatelessWidget {
  final bool isSignedOut;
  final bool isCompleted;

  const _EmptyStateView({this.isSignedOut = false, this.isCompleted = false});

  @override
  Widget build(BuildContext context) {
    if (isSignedOut) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_outline, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Sign in to manage your study goals',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isCompleted ? Icons.check_circle_outline : Icons.lightbulb_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            isCompleted ? 'No completed goals yet' : 'No active goals',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            isCompleted
                ? 'Complete some goals to see them here'
                : 'Tap the + button to create your first goal',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;

  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading goals',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
