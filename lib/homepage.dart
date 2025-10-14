import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Tab pages
import 'tabs/personal_study.dart';
import 'tabs/pomodoro_page.dart';
import 'tabs/group_study.dart';
import 'tabs/progress_page.dart';
import 'tabs/calendar_table.dart'; // ✅ Calendar file

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _activeTab = 0;

  // ---- Logout Helpers ----
  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logout cancelled')),
        );
      }
    }
  }

  // ---- Build ----
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      drawer: _buildAppDrawer(user),
      appBar: AppBar(
        title: const Text('📘 StudySync'),
        actions: [
          // Add Calendar Icon Button in AppBar
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Calendar',
            onPressed: () {
              setState(() {
                _activeTab = 4; // Switch to calendar tab
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('No user logged in.'))
          : IndexedStack(
              index: _activeTab,
              children: [
                PersonalStudyPage(uid: user.uid), // 0
                const PomodoroPage(),              // 1
                const GroupStudyPage(),            // 2
                const ProgressPage(),              // 3
                CalendarTable(uid: user.uid),      // 4 ✅ Calendar Tab
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _activeTab,
        onDestinationSelected: (index) {
          setState(() {
            _activeTab = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Personal',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: 'Pomodoro',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_3_outlined),
            selectedIcon: Icon(Icons.groups_3),
            label: 'Group',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendar', // ✅ Calendar Tab
          ),
        ],
      ),
    );
  }

  // ---- Drawer ----
  Widget _buildAppDrawer(User? user) {
    final displayName = (user?.displayName != null && user!.displayName!.trim().isNotEmpty)
        ? user.displayName!
        : (user?.email != null ? user!.email!.split('@')[0] : 'there');

    final statsRef = user == null
        ? null
        : FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('meta')
            .doc('stats');

    final tasksStream = user == null
        ? const Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('tasks')
            .snapshots();

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text("Let's study, $displayName"),
              accountEmail: Text(user?.email ?? ''),
              currentAccountPicture: CircleAvatar(
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S',
                ),
              ),
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
                    title: const Text('Study Streak'),
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
                  onTap: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _activeTab = 0; // Go to Personal tab
                    });
                  },
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.timeline),
              title: const Text('Progress'),
              onTap: () {
                Navigator.of(context).pop();
                setState(() {
                  _activeTab = 3; // Go to Progress tab
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Calendar'),
              onTap: () {
                Navigator.of(context).pop();
                setState(() {
                  _activeTab = 4; // Go to Calendar tab
                });
              },
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