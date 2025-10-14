import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class CalendarTable extends StatefulWidget {
  final String uid;
  const CalendarTable({Key? key, required this.uid}) : super(key: key);

  @override
  State<CalendarTable> createState() => _CalendarTableState();
}

class _CalendarTableState extends State<CalendarTable> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  Map<DateTime, List<DocumentSnapshot>> _events = {};

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    _loadGoals();
  }

  /// Load goals from Firestore and map them by their targetDate
  Future<void> _loadGoals() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('goals')
        .get();

    final Map<DateTime, List<DocumentSnapshot>> eventMap = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['targetDate'] != null) {
        final Timestamp timestamp = data['targetDate'];
        final DateTime date = DateTime(timestamp.toDate().year, timestamp.toDate().month, timestamp.toDate().day);
        if (eventMap[date] == null) eventMap[date] = [];
        eventMap[date]!.add(doc);
      }
    }

    setState(() {
      _events = eventMap;
    });
  }

  /// Get events for a specific day
  List<DocumentSnapshot> _getEventsForDay(DateTime day) {
    final DateTime key = DateTime(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final goalsForSelectedDay = _getEventsForDay(_selectedDay!);

    return Scaffold(
      appBar: AppBar(
        title: const Text("📅 Study Planner"),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: RefreshIndicator(
        onRefresh: _loadGoals,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildCalendar(),
              const SizedBox(height: 10),
              _buildGoalList(goalsForSelectedDay),
            ],
          ),
        ),
      ),
    );
  }

  /// Calendar UI
  Widget _buildCalendar() {
    return TableCalendar(
      focusedDay: _focusedDay,
      firstDay: DateTime(2020),
      lastDay: DateTime(2100),
      selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
      eventLoader: _getEventsForDay,
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: Colors.deepPurpleAccent.withOpacity(0.4),
          shape: BoxShape.circle,
        ),
        selectedDecoration: const BoxDecoration(
          color: Colors.deepPurple,
          shape: BoxShape.circle,
        ),
        markerDecoration: const BoxDecoration(
          color: Colors.orange,
          shape: BoxShape.circle,
        ),
      ),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      headerStyle: const HeaderStyle(
        titleCentered: true,
        formatButtonVisible: false,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// List of goals for the selected day
  Widget _buildGoalList(List<DocumentSnapshot> goals) {
    if (goals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: const [
            Icon(Icons.hourglass_empty, size: 60, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              "No goals scheduled for this day.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: goals.length,
      itemBuilder: (context, index) {
        final goal = goals[index];
        final data = goal.data() as Map<String, dynamic>;
        final title = data['title'] ?? "Untitled Goal";
        final desc = data['description'] ?? "";
        final completed = data['completed'] ?? false;
        final priority = data['priority'] ?? "Medium";
        final est = data['estimatedMinutes'] ?? 0;
        final done = data['totalStudyMinutes'] ?? 0;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: completed ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (desc.isNotEmpty) Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: est > 0 ? (done / est).clamp(0, 1).toDouble() : 0,
                  minHeight: 5,
                  backgroundColor: Colors.grey[300],
                  color: Colors.blueAccent,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Priority: $priority",
                      style: TextStyle(color: _priorityColor(priority), fontWeight: FontWeight.w500),
                    ),
                    Text(
                      "$done / $est min",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Checkbox(
              value: completed,
              onChanged: (val) => _toggleGoalCompletion(goal.id, val ?? false),
            ),
            onTap: () => _showGoalDetails(data),
          ),
        );
      },
    );
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _toggleGoalCompletion(String goalId, bool newValue) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('goals')
        .doc(goalId)
        .update({'completed': newValue});
    _loadGoals(); // Refresh events
  }

  void _showGoalDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(data['title'] ?? "Goal Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data['description'] != null)
              Text(data['description'], style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 10),
            if (data['targetDate'] != null)
              Text(
                "Target: ${DateFormat('dd MMM yyyy').format((data['targetDate'] as Timestamp).toDate())}",
              ),
            Text("Priority: ${data['priority'] ?? 'Medium'}"),
            Text("Study Sessions: ${data['studySessions'] ?? 0}"),
            Text("Total Time: ${data['totalStudyMinutes'] ?? 0} min"),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
        ],
      ),
    );
  }
}
