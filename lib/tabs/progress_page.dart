import 'package:flutter/material.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Progress Overview'),
        centerTitle: true,
        elevation: 0,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // -----------------------
            //   HEADER SECTION
            // -----------------------
            Text(
              'Your Study Summary',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A quick glance at your overall performance across StudySync.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),

            const SizedBox(height: 24),

            // -----------------------
            //   TOTAL ACTIVITY CARD
            // -----------------------
            _bigStatCard(
              icon: Icons.track_changes,
              title: "Overall Progress Score",
              value: "82%",
              subtitle: "Based on tasks, goals, and group activity",
              color: Colors.blue,
            ),

            const SizedBox(height: 24),

            // -----------------------
            //   GOAL PROGRESS
            // -----------------------
            Text(
              "Personal Study Progress",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            _miniProgressCard(
              color: Colors.teal,
              title: "Goals Completed",
              value: "8 / 12",
              percent: 0.66,
              icon: Icons.check_circle,
            ),
            const SizedBox(height: 12),

            _miniProgressCard(
              color: Colors.orange,
              title: "Tasks Completed",
              value: "42 / 67",
              percent: 0.62,
              icon: Icons.task_alt,
            ),

            const SizedBox(height: 24),

            // -----------------------
            //   GROUP ACTIVITY
            // -----------------------
            Text(
              "Group Activity",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            _circleStatRow(
              label1: "Groups Joined",
              value1: "3",
              label2: "Tasks Done",
              value2: "18",
            ),

            const SizedBox(height: 24),

            // -----------------------
            //   POMODORO STATS
            // -----------------------
            Text(
              "Pomodoro Sessions",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            _pomodoroStatCard(
              minutes: "450",
              sessions: "15",
              streak: "3 days",
            ),

            const SizedBox(height: 40),
            Center(
              child: Text(
                "More analytics coming soon…",
                style: TextStyle(
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  //  BIG OVERVIEW CARD
  // -------------------------------------------------------------
  Widget _bigStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, color: color, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // MINI PROGRESS CARD WITH BAR
  // -------------------------------------------------------------
  Widget _miniProgressCard({
    required Color color,
    required String title,
    required String value,
    required double percent,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.15),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          )
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  //  TWO CIRCLE STAT CARDS
  // -------------------------------------------------------------
  Widget _circleStatRow({
    required String label1,
    required String value1,
    required String label2,
    required String value2,
  }) {
    return Row(
      children: [
        Expanded(
          child: _circleStat(label1, value1),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _circleStat(label2, value2),
        ),
      ],
    );
  }

  Widget _circleStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                fontSize: 14,
              )),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  //  POMODORO STAT CARD
  // -------------------------------------------------------------
  Widget _pomodoroStatCard({
    required String minutes,
    required String sessions,
    required String streak,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.red.withOpacity(0.15),
            child: const Icon(Icons.timer, size: 32, color: Colors.red),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Pomodoro Focus",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[900]),
                ),
                const SizedBox(height: 4),
                Text("Focused Minutes: $minutes"),
                Text("Sessions Completed: $sessions"),
                Text("Current Streak: $streak"),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
