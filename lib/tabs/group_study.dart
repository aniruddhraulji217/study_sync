// lib/tabs/group_study.dart
// Simple, clean Group Study page: Tasks + Members inside one page (tab-like).
// Drop-in file for your project. No nested classes, Firestore-backed.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

/// -----------------------------
/// Top-level model class
/// -----------------------------
class GroupTask {
  final String id;
  final String title;
  final String description;
  final DateTime? dueDate;
  final bool completed;
  final DateTime? createdAt;
  final String? assignedTo;
  final String priority;
  final String? calendarEventId;

  GroupTask({
    required this.id,
    required this.title,
    this.description = '',
    this.dueDate,
    this.completed = false,
    this.createdAt,
    this.assignedTo,
    this.priority = 'Medium',
    this.calendarEventId,
  });

  factory GroupTask.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return GroupTask(
      id: doc.id,
      title: (d['title'] ?? '') as String,
      description: (d['description'] ?? '') as String,
      dueDate: (d['dueDate'] as Timestamp?)?.toDate(),
      completed: (d['completed'] ?? false) as bool,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      assignedTo: d['assignedTo'] as String?,
      priority: (d['priority'] ?? 'Medium') as String,
      calendarEventId: d['calendarEventId'] as String?,
    );
  }

  bool get isOverdue {
    if (dueDate == null) return false;
    final now = DateTime.now();
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final today = DateTime(now.year, now.month, now.day);
    return due.isBefore(today) && !completed;
  }
}

/// -----------------------------
/// GroupStudyPage widget
/// -----------------------------
class GroupStudyPage extends StatefulWidget {
  final String groupId;
  final String uid;
  final String? displayName;
  final String? email;

  const GroupStudyPage({
    super.key,
    required this.groupId,
    required this.uid,
    this.displayName,
    this.email,
  });

  @override
  State<GroupStudyPage> createState() => _GroupStudyPageState();
}

class _GroupStudyPageState extends State<GroupStudyPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _fire = FirebaseFirestore.instance;

  late TabController _tabController;

  // controllers for add/edit
  final TextEditingController _titleCtl = TextEditingController();
  final TextEditingController _descCtl = TextEditingController();

  // filters
  String _searchQuery = '';
  String _filterPriority = 'All';
  String _sortBy = 'createdAt';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtl.dispose();
    _descCtl.dispose();
    super.dispose();
  }

  // Firestore references
  DocumentReference<Map<String, dynamic>> get _groupRef =>
      _fire.collection('groups').doc(widget.groupId);

  CollectionReference<Map<String, dynamic>> get _tasksRef =>
      _groupRef.collection('tasks');

  CollectionReference<Map<String, dynamic>> get _membersRef =>
      _groupRef.collection('members');

  // ---------------------------
  // UI helpers
  // ---------------------------
  Color _priorityColor(String p) {
    switch (p) {
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

  String _formatDue(DateTime? d) {
    if (d == null) return '';
    final now = DateTime.now();
    final dn = DateTime(d.year, d.month, d.day);
    final today = DateTime(now.year, now.month, now.day);
    if (dn == today) return 'Today';
    if (dn == today.add(const Duration(days: 1))) return 'Tomorrow';
    return DateFormat('MMM d').format(d);
  }

  int _compareTasks(GroupTask a, GroupTask b) {
    switch (_sortBy) {
      case 'priority':
        const order = {'High': 0, 'Medium': 1, 'Low': 2};
        return (order[a.priority] ?? 3).compareTo(order[b.priority] ?? 3);
      case 'dueDate':
        if (a.dueDate == null && b.dueDate == null) return 0;
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      default:
        final aTs = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTs = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTs.compareTo(aTs);
    }
  }

  // ---------------------------
  // Task operations
  // ---------------------------
  Future<void> _createTask({
    required String title,
    String description = '',
    String priority = 'Medium',
    DateTime? dueDate,
    String? assignedTo,
  }) async {
    final data = <String, dynamic>{
      'title': title,
      'description': description,
      'priority': priority,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
      'completed': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdBy': widget.uid,
      'assignedTo': assignedTo,
      'calendarEventId': null,
    };

    await _tasksRef.add(data);
  }

  Future<void> _updateTask(String id, Map<String, dynamic> updates) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _tasksRef.doc(id).update(updates);
  }

  Future<void> _deleteTask(String id) async {
    await _tasksRef.doc(id).delete();
  }

  Future<void> _toggleComplete(GroupTask t) async {
    await _tasksRef.doc(t.id).update({
      'completed': !t.completed,
      'completedAt': !t.completed ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------
  // Add task sheet
  // ---------------------------
  Future<void> _openAddTaskSheet() async {
    _titleCtl.clear();
    _descCtl.clear();
    DateTime? dueDate;
    String priority = 'Medium';
    String? assignedTo;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape:
          const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(6))),
            const SizedBox(height: 12),
            TextField(controller: _titleCtl, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 8),
            TextField(controller: _descCtl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: priority,
                  items: ['Low', 'Medium', 'High'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (v) => priority = v ?? 'Medium',
                  decoration: const InputDecoration(labelText: 'Priority'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(children: [
                  Expanded(child: Text(dueDate == null ? 'No due date' : DateFormat('MMM d, y').format(dueDate!))),
                  TextButton(onPressed: () async {
                    final picked = await showDatePicker(context: context, initialDate: dueDate ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 3650)));
                    if (picked != null) setState(() => dueDate = picked);
                  }, child: const Text('Pick Date')),
                ]),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Expanded(child: SizedBox()),
              FilledButton.tonal(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton(onPressed: () async {
                final title = _titleCtl.text.trim();
                if (title.isEmpty) return;
                await _createTask(title: title, description: _descCtl.text.trim(), priority: priority, dueDate: dueDate, assignedTo: assignedTo);
                if (!mounted) return;
                Navigator.pop(context);
              }, child: const Text('Create')),
            ]),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  // ---------------------------
  // Edit task dialog
  // ---------------------------
  Future<void> _openEditTaskDialog(GroupTask t) async {
    final titleCtl = TextEditingController(text: t.title);
    final descCtl = TextEditingController(text: t.description);
    DateTime? dueDate = t.dueDate;
    String priority = t.priority;
    String? assignedTo = t.assignedTo;

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Edit Task'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: titleCtl, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 8),
            TextField(controller: descCtl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: priority,
              items: ['Low', 'Medium', 'High'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (v) => priority = v ?? 'Medium',
              decoration: const InputDecoration(labelText: 'Priority'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text(dueDate == null ? 'No due date' : DateFormat('MMM d, y').format(dueDate!))),
              TextButton(onPressed: () async {
                final picked = await showDatePicker(context: context, initialDate: dueDate ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 3650)));
                if (picked != null) setState(() => dueDate = picked);
              }, child: const Text('Pick Date')),
            ]),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            final newTitle = titleCtl.text.trim();
            final newDesc = descCtl.text.trim();
            await _updateTask(t.id, {
              'title': newTitle,
              'description': newDesc,
              'priority': priority,
              'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
            });
            if (!mounted) return;
            Navigator.pop(c);
          }, child: const Text('Save')),
        ],
      ),
    );
  }

  // ---------------------------
  // Assign dialog
  // ---------------------------
  Future<void> _openAssignDialog(GroupTask t) async {
    final searchCtl = TextEditingController();
    String? selectedMember;

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Assign Task'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: searchCtl, decoration: const InputDecoration(labelText: 'Search member id/name')),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _membersRef.snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snap.data!.docs;
                  final filtered = docs.where((d) {
                    final s = searchCtl.text.toLowerCase();
                    final id = d.id.toLowerCase();
                    final name = (d.data()['displayName'] ?? '').toString().toLowerCase();
                    if (s.isEmpty) return true;
                    return id.contains(s) || name.contains(s);
                  }).toList();
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final d = filtered[i];
                      final display = d.data()['displayName'] ?? d.id;
                      return RadioListTile<String>(
                        value: d.id,
                        groupValue: selectedMember,
                        title: Text(display),
                        onChanged: (v) => setState(() => selectedMember = v),
                      );
                    },
                  );
                },
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            await _updateTask(t.id, {'assignedTo': selectedMember});
            if (!mounted) return;
            Navigator.pop(c);
          }, child: const Text('Assign')),
        ],
      ),
    );
  }

  // ---------------------------
  // Task card widget
  // ---------------------------
  Widget _taskCard(GroupTask t) {
    return Slidable(
      key: ValueKey(t.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _openEditTaskDialog(t),
            backgroundColor: Colors.blue,
            icon: Icons.edit,
            label: 'Edit',
          ),
          SlidableAction(
            onPressed: (_) async {
              await _deleteTask(t.id);
            },
            backgroundColor: Colors.red,
            icon: Icons.delete,
            label: 'Delete',
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.completed ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _toggleComplete(t),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: t.completed ? Colors.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.completed ? Colors.green : Colors.grey.shade300, width: 1.6),
                ),
                child: Icon(t.completed ? Icons.check : Icons.circle_outlined, color: t.completed ? Colors.white : Colors.grey.shade600),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(t.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, decoration: t.completed ? TextDecoration.lineThrough : null))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(color: _priorityColor(t.priority).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                    child: Text(t.priority, style: TextStyle(fontSize: 12, color: _priorityColor(t.priority), fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  if (t.dueDate != null) ...[
                    Icon(Icons.calendar_today, size: 14, color: t.isOverdue ? Colors.red : Colors.grey),
                    const SizedBox(width: 6),
                    Text(_formatDue(t.dueDate), style: TextStyle(color: t.isOverdue ? Colors.red : Colors.grey.shade700)),
                    const SizedBox(width: 12),
                  ],
                  if ((t.assignedTo ?? '').isNotEmpty) ...[
                    CircleAvatar(radius: 10, backgroundColor: Colors.grey.shade100, child: Text(t.assignedTo![0].toUpperCase())),
                    const SizedBox(width: 6),
                    Text(t.assignedTo!, style: TextStyle(color: Colors.grey.shade700)),
                  ],
                ]),
                if (t.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(t.description, style: TextStyle(color: Colors.grey.shade700)),
                ],
              ]),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'assign') _openAssignDialog(t);
                if (v == 'duplicate') _createTask(title: '${t.title} (copy)', description: t.description, priority: t.priority, dueDate: t.dueDate, assignedTo: t.assignedTo);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'assign', child: Text('Assign')),
                PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------
  // Members tab
  // ---------------------------
  Widget _buildMembersTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _membersRef.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No members yet'));
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (c, i) {
            final d = docs[i];
            final data = d.data();
            final name = (data['displayName'] ?? d.id) as String;
            final email = (data['email'] ?? '') as String;
            return ListTile(
              leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?')),
              title: Text(name),
              subtitle: Text(email),
              onTap: () {},
            );
          },
        );
      },
    );
  }

  // ---------------------------
  // Group header
  // ---------------------------
  Widget _buildGroupHeader() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _tasksRef.snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final total = docs.length;
        final completed = docs.where((d) => (d.data()['completed'] ?? false) == true).length;
        final progress = total == 0 ? 0.0 : (completed / total);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Group Progress', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(minHeight: 10, value: progress, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation<Color>(Colors.green))),
                const SizedBox(height: 6),
                Text('${(progress * 100).round()}% • $completed / $total tasks', style: TextStyle(color: Colors.grey.shade700)),
              ]),
            ),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.info_outline), tooltip: 'Group Info', onPressed: _openGroupInfo),
          ]),
        );
      },
    );
  }

  // ---------------------------
  // Group Info sheet
  // ---------------------------
  void _openGroupInfo() {
    showModalBottomSheet(
      context: context,
      builder: (c) => FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _groupRef.get(),
        builder: (context, snap) {
          if (!snap.hasData) return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
          final data = snap.data!.data()!;
          final name = data['name'] ?? 'Group';
          final desc = data['description'] ?? 'No description';
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
          final code = data['code'] ?? '';
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(desc),
              const SizedBox(height: 12),
              if (createdAt != null) Text('Created: ${DateFormat('MMM d, y').format(createdAt)}', style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 12),
              Row(children: [
                FilledButton.icon(onPressed: () {
                  final codeText = code.toString();
                  Clipboard.setData(ClipboardData(text: codeText));
                  if (mounted) Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group code copied')));
                }, icon: const Icon(Icons.copy), label: const Text('Copy Code')),
                const SizedBox(width: 8),
                FilledButton.icon(onPressed: () {
                  if (mounted) Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calendar sync will be added later')));
                }, icon: const Icon(Icons.calendar_month), label: const Text('Calendar (later)')),
              ]),
              const SizedBox(height: 12),
              ElevatedButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), label: const Text('Close')),
            ]),
          );
        },
      ),
    );
  }

  // ---------------------------
  // Build
  // ---------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // this page is intended as a tab content in your larger app; it can also be pushed as a route
      appBar: AppBar(
        elevation: 0,
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _groupRef.snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data();
            final name = (data != null && data['name'] != null) ? data['name'] as String : 'Group';
            return Row(children: [
              CircleAvatar(radius: 18, backgroundColor: Colors.grey.shade100, child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?')),
              const SizedBox(width: 12),
              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
              IconButton(icon: const Icon(Icons.info_outline), onPressed: _openGroupInfo),
            ]);
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Tasks'), Tab(text: 'Members')],
        ),
      ),
      body: Column(
        children: [
          _buildGroupHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tasks tab
                Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    child: Row(children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search tasks',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(value: _filterPriority, items: ['All', 'High', 'Medium', 'Low'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(), onChanged: (v) => setState(() => _filterPriority = v ?? 'All')),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.sort),
                        tooltip: 'Sort',
                        onSelected: (v) => setState(() => _sortBy = v),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'createdAt', child: Text('Date Created')),
                          PopupMenuItem(value: 'priority', child: Text('Priority')),
                          PopupMenuItem(value: 'dueDate', child: Text('Due Date')),
                        ],
                      ),
                    ]),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _tasksRef.orderBy('createdAt', descending: true).snapshots(),
                      builder: (context, snap) {
                        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                        var tasks = snap.data!.docs.map((d) => GroupTask.fromDoc(d)).toList();

                        if (_filterPriority != 'All') tasks = tasks.where((t) => t.priority == _filterPriority).toList();

                        if (_searchQuery.isNotEmpty) {
                          final q = _searchQuery;
                          tasks = tasks.where((t) =>
                              t.title.toLowerCase().contains(q) ||
                              t.description.toLowerCase().contains(q) ||
                              (t.assignedTo ?? '').toLowerCase().contains(q)).toList();
                        }

                        tasks.sort(_compareTasks);

                        if (tasks.isEmpty) return const Center(child: Text('No tasks — add one to get started'));

                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemCount: tasks.length,
                          itemBuilder: (context, i) => _taskCard(tasks[i]),
                        );
                      },
                    ),
                  ),
                ]),

                // Members tab
                _buildMembersTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(onPressed: _openAddTaskSheet, icon: const Icon(Icons.add), label: const Text('Add Task'))
          : null,
    );
  }
}
