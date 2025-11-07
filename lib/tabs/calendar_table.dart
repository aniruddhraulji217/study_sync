import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;

// ---------------- Google Auth Client ----------------
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

// ---------------- Calendar Widget ----------------
class CalendarTable extends StatefulWidget {
  final String uid;
  const CalendarTable({Key? key, required this.uid}) : super(key: key);

  @override
  State<CalendarTable> createState() => _CalendarTableState();
}

class _CalendarTableState extends State<CalendarTable> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _events = {};
  bool _isLoading = false;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [gcal.CalendarApi.calendarScope],
  );

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    _loadAllEvents();
    _listenToGoalChanges(); // Real-time listener
  }

  // ---------------- Real-time Firestore Listener ----------------
  void _listenToGoalChanges() {
    FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('goals')
        .snapshots()
        .listen((snapshot) {
      _loadAllEvents(); // Refresh when any goal changes
    });
  }

  // ---------------- Load Firestore + Google Calendar ----------------
  Future<void> _loadAllEvents() async {
    setState(() => _isLoading = true);
    final Map<DateTime, List<dynamic>> eventMap = {};

    try {
      // 1️⃣ Firestore Goals
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('goals')
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['targetDate'] != null) {
          final Timestamp timestamp = data['targetDate'];
          final DateTime date = DateTime(
              timestamp.toDate().year, timestamp.toDate().month, timestamp.toDate().day);
          eventMap.putIfAbsent(date, () => []).add(doc);
        }
      }

      // 2️⃣ Google Calendar Events
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        final authHeaders = await account.authHeaders;
        final client = GoogleAuthClient(authHeaders);
        final calendarApi = gcal.CalendarApi(client);

        final now = DateTime.now();
        final events = await calendarApi.events.list(
          "primary",
          timeMin: now.subtract(const Duration(days: 30)),
          timeMax: now.add(const Duration(days: 365)),
          singleEvents: true,
          orderBy: "startTime",
        );

        for (var event in events.items ?? []) {
          if (event.start?.dateTime != null) {
            final start = event.start!.dateTime!;
            final key = DateTime(start.year, start.month, start.day);
            eventMap.putIfAbsent(key, () => []).add(event);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading events: $e')),
        );
      }
    }

    if (mounted) {
      setState(() {
        _events = eventMap;
        _isLoading = false;
      });
    }
  }

  // ---------------- Add Task to Google Calendar (Auto-sync) ----------------
  Future<void> _addTaskToGoogleCalendar(String goalId, Map<String, dynamic> goalData, {bool showMessage = true}) async {
    try {
      // Check if already synced
      if (goalData['googleEventId'] != null) {
        if (showMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Already synced to Google Calendar')),
          );
        }
        return;
      }

      final account = await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
      if (account == null) {
        if (showMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please sign in to Google Calendar')),
          );
        }
        return;
      }

      final authHeaders = await account.authHeaders;
      final client = GoogleAuthClient(authHeaders);
      final calendarApi = gcal.CalendarApi(client);

      final targetDate = (goalData['targetDate'] as Timestamp).toDate();
      final startTime = DateTime(targetDate.year, targetDate.month, targetDate.day, 9, 0);
      final endTime = startTime.add(Duration(minutes: goalData['estimatedMinutes'] ?? 60));

      final event = gcal.Event()
        ..summary = '📚 ${goalData['title'] ?? 'Study Task'}'
        ..description = '${goalData['description'] ?? ''}\n\n📌 Priority: ${goalData['priority'] ?? 'Medium'}\n⏱️ Estimated: ${goalData['estimatedMinutes'] ?? 0} minutes\n\n✨ Created from Study Planner App'
        ..start = gcal.EventDateTime(dateTime: startTime, timeZone: 'Asia/Kolkata')
        ..end = gcal.EventDateTime(dateTime: endTime, timeZone: 'Asia/Kolkata')
        ..colorId = _getColorId(goalData['priority'] ?? 'Medium')
        ..reminders = (gcal.EventReminders()
          ..useDefault = false
          ..overrides = [
            gcal.EventReminder()..method = 'popup'..minutes = 30,
            gcal.EventReminder()..method = 'popup'..minutes = 1440, // 1 day before
          ]);

      final createdEvent = await calendarApi.events.insert(event, 'primary');

      // Save Google Event ID to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('goals')
          .doc(goalId)
          .update({
        'googleEventId': createdEvent.id,
        'syncedToGoogle': true,
        'lastSyncedAt': FieldValue.serverTimestamp(),
      });

      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Task added to Google Calendar!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      _loadAllEvents();
    } catch (e) {
      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  String _getColorId(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return '11'; // Red
      case 'medium':
        return '5'; // Yellow
      case 'low':
        return '10'; // Green
      default:
        return '1'; // Blue
    }
  }

  // ---------------- Events for selected day ----------------
  List<dynamic> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  // ---------------- Add New Task Dialog ----------------
  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime selectedDate = _selectedDay ?? DateTime.now();
    String priority = 'Medium';
    int estimatedMinutes = 60;
    bool addToGoogle = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            '➕ Add New Task',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Task Title',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.description),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, color: Color(0xFF6366F1)),
                  title: Text(DateFormat('MMM dd, yyyy').format(selectedDate)),
                  trailing: const Icon(Icons.edit),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 8),
                const Text('Priority:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['High', 'Medium', 'Low'].map((p) {
                    return ChoiceChip(
                      label: Text(p),
                      selected: priority == p,
                      selectedColor: _priorityColor(p).withOpacity(0.3),
                      onSelected: (selected) {
                        if (selected) setDialogState(() => priority = p);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Estimated Minutes',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.timer),
                  ),
                  onChanged: (val) => estimatedMinutes = int.tryParse(val) ?? 60,
                  controller: TextEditingController(text: '60'),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Add to Google Calendar'),
                  subtitle: const Text('Automatically sync this task'),
                  value: addToGoogle,
                  onChanged: (val) => setDialogState(() => addToGoogle = val ?? true),
                  activeColor: const Color(0xFF6366F1),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a task title')),
                  );
                  return;
                }

                Navigator.pop(context);

                // Add to Firestore
                final docRef = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.uid)
                    .collection('goals')
                    .add({
                  'title': titleController.text.trim(),
                  'description': descController.text.trim(),
                  'targetDate': Timestamp.fromDate(selectedDate),
                  'priority': priority,
                  'estimatedMinutes': estimatedMinutes,
                  'totalStudyMinutes': 0,
                  'studySessions': 0,
                  'completed': false,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Task created successfully!')),
                );

                // Auto-sync to Google Calendar if checkbox is checked
                if (addToGoogle) {
                  final data = {
                    'title': titleController.text.trim(),
                    'description': descController.text.trim(),
                    'targetDate': Timestamp.fromDate(selectedDate),
                    'priority': priority,
                    'estimatedMinutes': estimatedMinutes,
                  };
                  await _addTaskToGoogleCalendar(docRef.id, data, showMessage: true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Create Task'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final goalsForSelectedDay = _getEventsForDay(_selectedDay!);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          "Study Calendar",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 22),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _loadAllEvents,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllEvents,
              color: const Color(0xFF6366F1),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildCalendar(),
                    const SizedBox(height: 16),
                    _buildDateHeader(),
                    const SizedBox(height: 12),
                    _buildGoalList(goalsForSelectedDay),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskDialog,
        backgroundColor: const Color(0xFF6366F1),
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
    );
  }

  // ---------------- Calendar UI ----------------
  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TableCalendar(
        focusedDay: _focusedDay,
        firstDay: DateTime(2020),
        lastDay: DateTime(2100),
        selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
        eventLoader: _getEventsForDay,
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(
            color: Color(0xFF6366F1),
            fontWeight: FontWeight.bold,
          ),
          selectedDecoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          markerDecoration: const BoxDecoration(
            color: Color(0xFFF59E0B),
            shape: BoxShape.circle,
          ),
          markersMaxCount: 3,
          outsideDaysVisible: false,
          cellMargin: const EdgeInsets.all(4),
          defaultTextStyle: const TextStyle(fontSize: 15),
        ),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        headerStyle: HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          titleTextStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
          leftChevronIcon: const Icon(Icons.chevron_left, color: Color(0xFF6366F1)),
          rightChevronIcon: const Icon(Icons.chevron_right, color: Color(0xFF6366F1)),
          headerPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
          weekendStyle: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFEF4444)),
        ),
      ),
    );
  }

  // ---------------- Date Header ----------------
  Widget _buildDateHeader() {
    final count = _getEventsForDay(_selectedDay!).length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('EEEE, MMMM d').format(_selectedDay!),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count ${count == 1 ? 'task' : 'tasks'}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- List of events ----------------
  Widget _buildGoalList(List<dynamic> goals) {
    if (goals.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: const [
            Icon(Icons.event_available, size: 80, color: Color(0xFFD1D5DB)),
            SizedBox(height: 16),
            Text(
              "No tasks scheduled",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Tap + to add a new task",
              style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: goals.length,
      itemBuilder: (context, index) {
        final item = goals[index];

        if (item is DocumentSnapshot) {
          final data = item.data() as Map<String, dynamic>;
          return _buildFirestoreGoal(item.id, data);
        }

        if (item is gcal.Event) {
          return _buildGoogleEvent(item);
        }

        return const SizedBox();
      },
    );
  }

  // ---------------- Firestore goal widget ----------------
  Widget _buildFirestoreGoal(String id, Map<String, dynamic> data) {
    final title = data['title'] ?? "Untitled Goal";
    final desc = data['description'] ?? "";
    final completed = data['completed'] ?? false;
    final priority = data['priority'] ?? "Medium";
    final est = data['estimatedMinutes'] ?? 0;
    final done = data['totalStudyMinutes'] ?? 0;
    final syncedToGoogle = data['syncedToGoogle'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _priorityColor(priority).withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _priorityColor(priority).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                completed ? Icons.check_circle : Icons.radio_button_unchecked,
                color: _priorityColor(priority),
                size: 28,
              ),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: const Color(0xFF1F2937),
                decoration: completed ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildChip(priority, _priorityColor(priority)),
                    const SizedBox(width: 8),
                    _buildChip("$done / $est min", const Color(0xFF6366F1)),
                    if (syncedToGoogle) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.cloud_done, color: Color(0xFF10B981), size: 16),
                    ],
                  ],
                ),
              ],
            ),
            trailing: Checkbox(
              value: completed,
              onChanged: (val) => _toggleGoalCompletion(id, val ?? false),
              activeColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onTap: () => _showGoalDetails(id, data),
          ),
          if (est > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (done / est).clamp(0, 1).toDouble(),
                  minHeight: 6,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation(_priorityColor(priority)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  // ---------------- Google event widget ----------------
  Widget _buildGoogleEvent(gcal.Event event) {
    final start = event.start?.dateTime ?? DateTime.now();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.event, color: Colors.white, size: 24),
        ),
        title: Text(
          event.summary ?? "Google Event",
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFF1F2937),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: Color(0xFF6B7280)),
                const SizedBox(width: 4),
                Text(
                  DateFormat('hh:mm a').format(start),
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.cloud, color: Color(0xFFF59E0B), size: 20),
        ),
        onTap: () => _showGoogleEventDetails(event),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFEF4444);
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'low':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Future<void> _toggleGoalCompletion(String goalId, bool newValue) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('goals')
        .doc(goalId)
        .update({'completed': newValue});
  }

  void _showGoalDetails(String id, Map<String, dynamic> data) {
    final syncedToGoogle = data['syncedToGoogle'] ?? false;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              data['title'] ?? "Goal Details",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 16),
            if (data['description'] != null && data['description'].toString().isNotEmpty) ...[
              _buildDetailRow(Icons.description, data['description']),
              const SizedBox(height: 12),
            ],
            if (data['targetDate'] != null) ...[
              _buildDetailRow(
                Icons.calendar_today,
                DateFormat('dd MMM yyyy').format((data['targetDate'] as Timestamp).toDate()),
              ),
              const SizedBox(height: 12),
            ],
            _buildDetailRow(Icons.flag, "Priority: ${data['priority'] ?? 'Medium'}"),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.timer, "Study Sessions: ${data['studySessions'] ?? 0}"),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.access_time, "Total Time: ${data['totalStudyMinutes'] ?? 0} min"),
            const SizedBox(height: 24),
            if (!syncedToGoogle) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _addTaskToGoogleCalendar(id, data);
                      },
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Sync to Google Calendar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle, color: Color(0xFF10B981)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Synced to Google Calendar',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Color(0xFF6366F1)),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGoogleEventDetails(gcal.Event event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.event, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    event.summary ?? "Google Event",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (event.description != null) ...[
              _buildDetailRow(Icons.description, event.description!),
              const SizedBox(height: 12),
            ],
            _buildDetailRow(
              Icons.schedule,
              "Start: ${event.start?.dateTime ?? event.start?.date}",
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.event_available,
              "End: ${event.end?.dateTime ?? event.end?.date}",
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6366F1)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF4B5563),
            ),
          ),
        ),
      ],
    );
  }
}