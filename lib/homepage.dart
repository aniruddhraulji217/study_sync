import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Tab pages
import 'tabs/personal_study.dart';
import 'tabs/pomodoro_page.dart';
import 'tabs/groups_list_page.dart'; // ✅ NEW: Groups list instead of single group
import 'tabs/progress_page.dart';
import 'tabs/calendar_table.dart';
import 'package:google_sign_in/google_sign_in.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _activeTab = 0;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ---- Logout Helpers ----
  Future<void> _logout(BuildContext context) async {
    try {
      // Sign out from Google if logged in with Google
      await _googleSignIn.signOut();

      // Also disconnect to clear cached tokens
      await _googleSignIn.disconnect().catchError((_) {});

      // Then sign out from Firebase
      await FirebaseAuth.instance.signOut();

      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      debugPrint('Error during logout: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
      }
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Logout cancelled')));
      }
    }
  }

  // ❌ REMOVED: joinGroupIfMissing - No longer needed!
  // Users will create/join groups manually through GroupsListPage

  // ---- Build ----
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // ❌ REMOVED: No auto-join logic here

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
                const PomodoroPage(), // 1
                // ✅ NEW: Groups list page instead of single group
                GroupsListPage(
                  uid: user.uid,
                  displayName: user.displayName,
                  email: user.email,
                ), // 2
                const ProgressPage(), // 3
                CalendarTable(uid: user.uid), // 4
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
            label: 'Groups', // ✅ Changed to plural
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
        ],
      ),
    );
  }

  // ---- Drawer (REDESIGNED UI, SAME LOGIC) ----
  Widget _buildAppDrawer(User? user) {
    if (user == null) {
      return const Drawer(child: Center(child: Text("No user logged in.")));
    }

    final displayName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!
        : (user.email?.split('@')[0] ?? 'User');

    final photoUrl = user.photoURL;

    final statsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('meta')
        .doc('stats');

    final tasksStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('tasks')
        .snapshots();

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---------- HEADER ----------
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: photoUrl != null
                        ? NetworkImage(photoUrl)
                        : null,
                    child: photoUrl == null
                        ? Text(
                            displayName[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Hello, $displayName!",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ---------- STATS CARD ----------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Card(
                elevation: 0,
                color: Theme.of(
                  context,
                ).colorScheme.surfaceVariant.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: statsRef.snapshots(),
                    builder: (context, snap) {
                      final data = snap.data?.data();
                      final streak = data != null ? (data['streak'] ?? 0) : 0;
                      final lastDay = data != null
                          ? (data['lastCompletedDay'] ?? '—')
                          : '—';

                      return Row(
                        children: [
                          _smallStat(
                            icon: Icons.local_fire_department,
                            label: "Streak",
                            value: "$streak days",
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 12),
                          _smallStat(
                            icon: Icons.event_available,
                            label: "Last Study",
                            value: "$lastDay",
                            color: Colors.green,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ---------- NAVIGATION ----------
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // PERSONAL TASKS
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: tasksStream,
                    builder: (context, snap) {
                      final count = snap.data?.docs.length ?? 0;
                      return _drawerTile(
                        icon: Icons.list_alt,
                        title: "My Tasks",
                        subtitle: "$count total tasks",
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _activeTab = 0);
                        },
                      );
                    },
                  ),

                  _drawerTile(
                    icon: Icons.groups_3,
                    title: "Study Groups",
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _activeTab = 2);
                    },
                  ),
                  _drawerTile(
                    icon: Icons.timeline,
                    title: "Progress",
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _activeTab = 3);
                    },
                  ),
                  _drawerTile(
                    icon: Icons.calendar_month,
                    title: "Calendar",
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _activeTab = 4);
                    },
                  ),
                ],
              ),
            ),

            const Divider(height: 0),

            // ---------- LOGOUT BUTTON ----------
            Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                label: const Text("Logout"),
                onPressed: () {
                  Navigator.pop(context);
                  _confirmLogout(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Helper Widget for Stats ----------
  Widget _smallStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ---------- Helper Widget for ListTile ----------
  Widget _drawerTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
