import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ============================================================================
// MAIN SCREEN
// ============================================================================

/// Screen for managing personal study goals with filtering, sorting, and CRUD operations
class PersonalStudyPage extends StatefulWidget {
  final String uid;

  const PersonalStudyPage({super.key, required this.uid});

  @override
  State<PersonalStudyPage> createState() => _PersonalStudyPageState();
}

class _PersonalStudyPageState extends State<PersonalStudyPage> {
  // Filter and sort state
  GoalFilterState _filterState = const GoalFilterState();

  @override
  Widget build(BuildContext context) {
    if (widget.uid.isEmpty) {
      return const Scaffold(body: _EmptyStateView(isSignedOut: true));
    }

    return Scaffold(
      body: Column(
        children: [
          _StudyGoalsHeader(
            onSearchChanged: (query) => setState(() {
              _filterState = _filterState.copyWith(searchQuery: query);
            }),
          ),
          _FilterBar(
            filterState: _filterState,
            onFilterChanged: (newState) => setState(() => _filterState = newState),
          ),
          Expanded(
            child: _GoalsListView(
              uid: widget.uid,
              filterState: _filterState,
            ),
          ),
        ],
      ),
      floatingActionButton: _AddGoalFAB(uid: widget.uid),
    );
  }
}

// ============================================================================
// DATA MODELS
// ============================================================================

/// Immutable filter state for goals
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

/// Data model for a study goal
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
    );
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

// ============================================================================
// HEADER SECTION
// ============================================================================

class _StudyGoalsHeader extends StatelessWidget {
  final ValueChanged<String> onSearchChanged;

  const _StudyGoalsHeader({required this.onSearchChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Study Goals',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Organize and track your learning objectives',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimary.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          SearchBar(
            hintText: 'Search goals...',
            leading: const Icon(Icons.search),
            backgroundColor: MaterialStateProperty.all(Colors.white),
            elevation: MaterialStateProperty.all(0),
            onChanged: (value) => onSearchChanged(value.toLowerCase()),
            padding: const MaterialStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FILTER BAR
// ============================================================================

class _FilterBar extends StatelessWidget {
  final GoalFilterState filterState;
  final ValueChanged<GoalFilterState> onFilterChanged;

  const _FilterBar({
    required this.filterState,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
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
            _buildPriorityOption(context, 'Low', Icons.flag_outlined, Colors.blue),
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
            _buildSortOption(context, 'createdAt', 'Date Created', Icons.date_range),
            _buildSortOption(context, 'priority', 'Priority', Icons.flag),
            _buildSortOption(context, 'targetDate', 'Due Date', Icons.calendar_today),
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
// GOALS LIST VIEW
// ============================================================================

class _GoalsListView extends StatelessWidget {
  final String uid;
  final GoalFilterState filterState;

  const _GoalsListView({
    required this.uid,
    required this.filterState,
  });

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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: goals.length,
          itemBuilder: (context, index) => _GoalCard(goal: goals[index], uid: uid),
        );
      },
    );
  }

  /// Apply filtering and sorting to goals
  List<StudyGoal> _processGoals(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    var goals = docs.map((doc) => StudyGoal.fromFirestore(doc)).toList();

    // Apply priority filter
    if (filterState.priority != 'All') {
      goals = goals.where((g) => g.priority == filterState.priority).toList();
    }

    // Apply search filter
    if (filterState.searchQuery.isNotEmpty) {
      goals = goals.where((g) {
        final titleMatch = g.title.toLowerCase().contains(filterState.searchQuery);
        final descMatch = g.description.toLowerCase().contains(filterState.searchQuery);
        return titleMatch || descMatch;
      }).toList();
    }

    // Apply sorting
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

      default: // createdAt
        if (a.createdAt == null || b.createdAt == null) return 0;
        return b.createdAt!.compareTo(a.createdAt!); // Descending
    }
  }
}

// ============================================================================
// GOAL CARD
// ============================================================================

class _GoalCard extends StatelessWidget {
  final StudyGoal goal;
  final String uid;

  const _GoalCard({required this.goal, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showGoalDetails(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 12),
              _buildMetadata(),
              if (goal.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildTags(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        _CompletionCheckbox(
          completed: goal.completed,
          onToggle: () => _toggleCompletion(context),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                goal.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      decoration: goal.completed ? TextDecoration.lineThrough : null,
                      color: goal.completed ? Colors.grey : null,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (goal.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  goal.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        Icon(goal.priorityIcon, color: goal.priorityColor, size: 24),
      ],
    );
  }

  Widget _buildMetadata() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        if (goal.targetDate != null)
          _InfoChip(
            icon: Icons.calendar_today,
            label: _formatTargetDate(goal.targetDate!),
            color: goal.isOverdue ? Colors.red : Colors.grey.shade700,
          ),
        if (goal.estimatedMinutes > 0)
          _InfoChip(
            icon: Icons.timer_outlined,
            label: '${goal.estimatedMinutes} min',
            color: Colors.grey.shade700,
          ),
        if (goal.totalStudyMinutes > 0)
          _InfoChip(
            icon: Icons.trending_up,
            label: '${goal.totalStudyMinutes} min done',
            color: Colors.green.shade700,
          ),
      ],
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: goal.tags.take(3).map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Text(
            tag,
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatTargetDate(DateTime date) {
    final hasTime = date.hour != 0 || date.minute != 0;
    if (hasTime) {
      return '${DateFormat('MMM d').format(date)} ${DateFormat('h:mm a').format(date)}';
    }
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
        'completedAt': !goal.completed ? FieldValue.serverTimestamp() : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating goal: $e')),
        );
      }
    }
  }
}

// ============================================================================
// REUSABLE COMPONENTS
// ============================================================================

class _CompletionCheckbox extends StatelessWidget {
  final bool completed;
  final VoidCallback onToggle;

  const _CompletionCheckbox({
    required this.completed,
    required this.onToggle,
  });

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
// GOAL DETAILS SHEET
// ============================================================================

class _GoalDetailsSheet extends StatelessWidget {
  final StudyGoal goal;
  final String uid;

  const _GoalDetailsSheet({required this.goal, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildDragHandle(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const Divider(height: 24),
                  if (goal.description.isNotEmpty) ...[
                    _buildSection('Description', goal.description),
                    const SizedBox(height: 20),
                  ],
                  _buildDetailsSection(),
                  if (goal.tags.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildTagsSection(context),
                  ],
                ],
              ),
            ),
          ),
          _buildActionButton(context),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            goal.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () {
            Navigator.pop(context);
            _editGoal(context);
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () {
            Navigator.pop(context);
            _deleteGoal(context);
          },
        ),
      ],
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(content, style: const TextStyle(fontSize: 15)),
      ],
    );
  }

  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        _DetailRow(
          icon: Icons.flag,
          label: 'Priority',
          value: goal.priority,
        ),
        if (goal.targetDate != null)
          _DetailRow(
            icon: Icons.calendar_today,
            label: 'Due Date',
            value: _formatFullDate(goal.targetDate!),
          ),
        if (goal.estimatedMinutes > 0)
          _DetailRow(
            icon: Icons.timer,
            label: 'Estimated Time',
            value: '${goal.estimatedMinutes} minutes',
          ),
        _DetailRow(
          icon: Icons.history,
          label: 'Time Studied',
          value: '${goal.totalStudyMinutes} minutes',
        ),
        _DetailRow(
          icon: Icons.replay,
          label: 'Study Sessions',
          value: '${goal.studySessions}',
        ),
      ],
    );
  }

  Widget _buildTagsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tags',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: goal.tags.map((tag) {
            return Chip(
              label: Text(tag),
              backgroundColor: Colors.blue.shade50,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Go to Pomodoro tab to start studying!'),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Study Session'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ),
    );
  }

  String _formatFullDate(DateTime date) {
    final hasTime = date.hour != 0 || date.minute != 0;
    if (hasTime) {
      return '${DateFormat('MMMM d, y').format(date)} at ${DateFormat('h:mm a').format(date)}';
    }
    return DateFormat('MMMM d, y').format(date);
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
        content: const Text('This action cannot be undone.'),
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

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('goals')
          .doc(goal.id)
          .delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting goal: $e')),
        );
      }
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.blue.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// GOAL FORM DIALOG
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

    // Extract time from existing targetDate if it has a time component
    if (_targetDate != null &&
        (_targetDate!.hour != 0 || _targetDate!.minute != 0)) {
      _targetTime = TimeOfDay(hour: _targetDate!.hour, minute: _targetDate!.minute);
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
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _pickDate,
          ),
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
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _pickTime,
          ),
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

    // Combine date and time if both are provided
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
      'targetDate':
          fullTargetDateTime != null ? Timestamp.fromDate(fullTargetDateTime) : null,
      'tags': _tags,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (_isEditing) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .collection('goals')
            .doc(widget.existingGoal!.id)
            .update(goalData);
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .collection('goals')
            .add({
          ...goalData,
          'completed': false,
          'studySessions': 0,
          'totalStudyMinutes': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'Goal updated successfully!' : 'Goal created successfully!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

// ============================================================================
// ADD GOAL FAB
// ============================================================================

class _AddGoalFAB extends StatelessWidget {
  final String uid;

  const _AddGoalFAB({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _showAddGoalDialog(context),
      icon: const Icon(Icons.add),
      label: const Text('New Goal'),
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
// EMPTY STATE VIEWS
// ============================================================================

class _EmptyStateView extends StatelessWidget {
  final bool isSignedOut;
  final bool isCompleted;

  const _EmptyStateView({
    this.isSignedOut = false,
    this.isCompleted = false,
  });

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