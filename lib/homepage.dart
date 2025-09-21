import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:percent_indicator/percent_indicator.dart';
// add imports for new tab pages
import 'tabs/personal_study.dart';
import 'tabs/pomodoro_page.dart';
import 'tabs/group_study.dart';
import 'tabs/progress_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _activeTab = 0;
  // list of tab labels used by the ChoiceChips
  static const List<String> _tabTitles = [
    "Personal Study",
    "Pomodoro",
    "Group Study",
    "Progress",
  ];

  _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) Navigator.of(context).pushReplacementNamed('/login');
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _logout(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logout cancelled')));
    }
  }

  void _showCreateTaskDialog(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    showDialog(
      context: context,
      builder: (_) => CreateTaskDialog(uid: user.uid, onCreate: (title, duration) => _createTask(user.uid, title, duration)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = (user?.displayName != null && user!.displayName!.trim().isNotEmpty)
        ? user.displayName!
        : (user?.email != null ? user!.email!.split('@')[0] : 'there');
    final mq = MediaQuery.of(context);
    final width = mq.size.width;

    return Scaffold(
      drawer: _buildAppDrawer(user),
      appBar: AppBar(title: const Text('📘 StudySync'), actions: [
        IconButton(icon: const Icon(Icons.logout), onPressed: () => _confirmLogout(context)),
      ]),
      body: user == null
          ? const Center(child: Text('No user logged in.'))
          : LayoutBuilder(builder: (context, constraints) {
              final uid = user.uid;
              int columns = 1;
              if (constraints.maxWidth >= 1000) columns = 3;
              else if (constraints.maxWidth >= 600) columns = 2;

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: width < 400 ? 12 : 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tabs - horizontally scrollable
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          for (var i = 0; i < _tabTitles.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: ChoiceChip(
                                label: Text(_tabTitles[i]),
                                selected: _activeTab == i,
                                onSelected: (_) => setState(() => _activeTab = i),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Only show the selected tab's page below (no duplicate headers/tasks)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: _buildActiveTabContent(uid, columns),
                    ),
                  ],
                ),
              );
            }),
    );
  }
 
  // returns the widget for the active tab
   Widget _buildActiveTabContent(String? uid, int columns) {
     switch (_activeTab) {
       case 0:
         return PersonalStudyPage(uid: uid ?? '');
       case 1:
         return PomodoroPage();
       case 2:
         return GroupStudyPage();
       case 3:
         return ProgressPage();
       default:
         return const SizedBox.shrink();
     }
   }

  Widget _buildStreakBlock() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Study Streak", style: TextStyle(fontSize: 16)),
        SizedBox(height: 6),
        Text("🔥 7 days", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildGoalBlock() {
    return Column(
      children: [
        const Text("Today's Goal"),
        const SizedBox(height: 8),
        CircularPercentIndicator(
          radius: 40.0,
          lineWidth: 6.0,
          percent: 0.6,
          center: const Text("3/5"),
          progressColor: Colors.blue,
        ),
      ],
    );
  }

  // App Drawer (moved into _HomePageState so it can call _confirmLogout)
  Widget _buildAppDrawer(User? user) {
    final displayName = (user?.displayName != null && user!.displayName!.trim().isNotEmpty)
        ? user.displayName!
        : (user?.email != null ? user!.email!.split('@')[0] : 'there');

    final statsRef = user == null
        ? null
        : FirebaseFirestore.instance.collection('users').doc(user.uid).collection('meta').doc('stats');
    final tasksStream = user == null
        ? const Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : FirebaseFirestore.instance.collection('users').doc(user.uid).collection('tasks').snapshots();

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text('Let\'s study, $displayName'),
              accountEmail: Text(user?.email ?? ''),
              currentAccountPicture: CircleAvatar(child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S')),
            ),
            if (statsRef != null)
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: statsRef.snapshots(),
                builder: (context, snap) {
                  final data = snap.data?.data();
                  final streak = data != null ? (data['streak'] ?? 0) as int : 0;
                  final lastDay = data != null ? (data['lastCompletedDay'] ?? '—') : '—';
                  return ListTile(
                    leading: const Icon(Icons.local_fire_department),
                    title: Text('Study Streak'),
                    subtitle: Text('🔥 $streak days • last: $lastDay'),
                  );
                },
              )
            else
              const ListTile(
                leading: Icon(Icons.local_fire_department),
                title: Text('Study Streak'),
                subtitle: Text('Not signed in'),
              ),
            const ListTile(
              leading: Icon(Icons.flag),
              title: Text("Today's Goal"),
              subtitle: Text('Complete 3 tasks • 45 mins'),
            ),
            const Divider(),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: tasksStream,
              builder: (context, snap) {
                final count = snap.data?.docs.length ?? 0;
                return ListTile(
                  leading: const Icon(Icons.list),
                  title: const Text('Tasks'),
                  subtitle: Text('$count total'),
                  onTap: () => Navigator.of(context).pop(),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.timeline),
              title: const Text('Progress'),
              onTap: () => Navigator.of(context).pop(),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                onPressed: () {
                  Navigator.of(context).pop(); // close drawer
                  _confirmLogout(context);
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// CreateTaskDialog Widget (responsive)
class CreateTaskDialog extends StatefulWidget {
  final String uid;
  final Future<void> Function(String title, String? duration) onCreate;
  const CreateTaskDialog({super.key, required this.uid, required this.onCreate});

  @override
  State<CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<CreateTaskDialog> {
  final _titleCtl = TextEditingController();
  final _durationCtl = TextEditingController();
  bool _loading = false;

  Future<void> _onCreate() async {
    if (_titleCtl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await widget.onCreate(_titleCtl.text.trim(), _durationCtl.text.trim());
      if (context.mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width;
    final dialogWidth = maxWidth > 600 ? 600.0 : maxWidth * 0.95;

    return AlertDialog(
      title: const Text('Create New Task'),
      content: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtl,
              decoration: const InputDecoration(
                labelText: 'Task Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _durationCtl,
              decoration: const InputDecoration(
                labelText: 'Duration (minutes)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _loading ? null : _onCreate,
          child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create'),
        ),
      ],
    );
  }
}