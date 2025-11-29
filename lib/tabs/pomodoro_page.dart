import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

enum PomodoroMode { soft, hardcore }

class PomodoroPage extends StatefulWidget {
  const PomodoroPage({super.key});

  @override
  State<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends State<PomodoroPage>
    with SingleTickerProviderStateMixin {
  // --- Mode & mood ---
  PomodoroMode _mode = PomodoroMode.soft;
  String _dailyMood = 'Neutral'; // "Great", "Okay", "Neutral", "Tired", "Low"

  // --- Durations (in seconds) default per mode ---
  int _softWork = 20 * 60; // 20 minutes initial for Soft
  int _softShortBreak = 7 * 60; // 7 minutes
  int _softLongBreak = 12 * 60; // 12 minutes

  int _hardWork = 50 * 60; // 50 minutes for Hardcore
  int _hardShortBreak = 8 * 60; // 8 minutes
  int _hardLongBreak = 10 * 60; // 10 minutes

  // Current running values (may adapt)
  late int _workDuration;
  late int _shortBreak;
  late int _longBreak;

  // --- Timer state ---
  Timer? _timer;
  bool _isRunning = false;
  bool _isBreak = false;
  int _timeLeft = 0;

  // --- Behavior tracking for adaptive logic ---
  int _completedSessionsTotal = 0; // all sessions completed
  int _completedSessionsStreak =
      0; // consecutive completed sessions (resets on pause/stop)
  int _pauseCountCurrentSession = 0; // pauses in current session
  List<Map<String, dynamic>> _recentSessions =
      []; // keep small history of last sessions

  // --- UI animations (breathing during break) ---
  late AnimationController _breathController;
  late Animation<double> _breathAnim;

  // --- Messages ---
  final List<String> _softEncouragements = [
    'Breathe. Small steps win the race.',
    'Gentle focus — you’ve got this.',
    'Keep calm and keep going.',
    'One session at a time, well done!',
    'Short, steady work builds habits.',
  ];
  final List<String> _hardEncouragements = [
    'Deep focus — lock it down.',
    'Discipline > motivation — keep pushing.',
    'High intensity: stay on task.',
    'This is a deep work window — no distractions.',
    'Push through — you’ve trained for this.',
  ];

  // --- Auto suggestion logic control ---
  bool _showSuggestion = false;
  String _suggestionText = '';

  // --- UI convenience ---
  final Random _rand = Random();

  @override
  void initState() {
    super.initState();
    // initialize durations based on default mode
    _applyModeDurations();
    // default time left to work duration
    _timeLeft = _workDuration;

    // breathing animation for breaks
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _breathAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );
    _breathController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _breathController.reverse();
      if (status == AnimationStatus.dismissed) _breathController.forward();
    });

    // start paused
    _breathController.stop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _breathController.dispose();
    super.dispose();
  }

  void _applyModeDurations() {
    if (_mode == PomodoroMode.soft) {
      _workDuration = _softWork;
      _shortBreak = _softShortBreak;
      _longBreak = _softLongBreak;
    } else {
      _workDuration = _hardWork;
      _shortBreak = _hardShortBreak;
      _longBreak = _hardLongBreak;
    }

    // adjust durations slightly by mood
    if (_dailyMood == 'Tired' || _dailyMood == 'Low') {
      // lower work duration if tired
      _workDuration = (_workDuration * 0.8).round();
      _shortBreak = (_shortBreak * 1.2).round();
    } else if (_dailyMood == 'Great') {
      // boost a bit if great
      _workDuration = (_workDuration * 1.05).round();
    }

    // if in a session, keep timeLeft proportional to new duration if not running
    if (!_isRunning && !_isBreak) {
      _timeLeft = _workDuration;
    } else if (!_isRunning && _isBreak) {
      // keep break time
      _timeLeft = _getBreakDuration();
    }
  }

  int _getBreakDuration() {
    // long break every 4 completed sessions
    return (_completedSessionsTotal > 0 && _completedSessionsTotal % 4 == 0)
        ? _longBreak
        : _shortBreak;
  }

  void _startTimer() {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _pauseCountCurrentSession = 0; // reset pause counter at start
      _showSuggestion = false;
      _suggestionText = '';
    });

    // start breathing animation on break
    if (_isBreak) {
      _breathController.forward();
    } else {
      _breathController.stop();
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
          // occasional in-session micro messages (to keep motivation)
          // We'll display a SnackBar at certain milestones (but not too often)
          if (_timeLeft ==
              (_isBreak ? _getBreakDuration() ~/ 2 : _workDuration ~/ 2)) {
            final message = _randomEncouragement();
            _showInAppMessage(message);
          }
        } else {
          _onSessionComplete();
        }
      });
    });
  }

  void _pauseTimer() {
    if (!_isRunning) return;
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _pauseCountCurrentSession++;
      _completedSessionsStreak = 0; // break the streak when paused
    });

    // stop breathing animation if break paused
    _breathController.stop();

    _evaluateAutoSuggestions();
  }

  void _resetTimer({bool resetModeDurations = false}) {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isBreak = false;
      if (resetModeDurations) _applyModeDurations();
      _timeLeft = _workDuration;
      _pauseCountCurrentSession = 0;
      _showSuggestion = false;
    });
    _breathController.stop();
  }

  void _skipToBreak() {
    // force end session immediately
    _timer?.cancel();
    setState(() {
      _timeLeft = 0;
    });
    // call completion handler
    _onSessionComplete();
  }

  void _onSessionComplete() {
    _timer?.cancel();
    // register the session into history
    final session = {
      'timestamp': DateTime.now(),
      'wasBreak': _isBreak,
      'pausedCount': _pauseCountCurrentSession,
      'mode': _mode.toString(),
      'duration': _isBreak ? _getBreakDuration() : _workDuration,
      'completed': true,
    };
    _recentSessions.add(session);
    if (_recentSessions.length > 10) _recentSessions.removeAt(0);

    setState(() {
      if (!_isBreak) {
        // just finished a work session
        _completedSessionsTotal++;
        _completedSessionsStreak++;
        // adaptive: if user completed session without pauses => slightly increase next work duration (max cap)
        if (_pauseCountCurrentSession == 0) {
          _adaptIncreaseWorkDuration();
        }
        // prepare break
        _isBreak = true;
        _timeLeft = _getBreakDuration();
        _isRunning = false;
      } else {
        // just finished a break
        _isBreak = false;
        _timeLeft = _workDuration;
        _isRunning = false;
      }
      _pauseCountCurrentSession = 0;
    });

    // play supportive message
    final snackText = !_isBreak
        ? '✨ Break over — ready to work?'
        : '🎉 Work session complete! Take a short break.';
    _showInAppMessage(snackText);

    // breathing for breaks
    if (_isBreak) {
      _breathController.forward();
    } else {
      _breathController.stop();
    }

    // Suggest mode change if behavior warrants it
    _evaluateAutoSuggestions();
  }

  void _adaptIncreaseWorkDuration() {
    // gentle increase (5% up to a cap), only in hardcore mode; for soft be more conservative
    if (_mode == PomodoroMode.hardcore) {
      final increase = (_workDuration * 0.05).round();
      final newVal = (_workDuration + increase).clamp(
        _hardWork,
        60 * 60,
      ); // cap 60 min
      _workDuration = newVal;
    } else {
      final increase = (_workDuration * 0.03).round();
      final newVal = (_workDuration + increase).clamp(
        10 * 60,
        30 * 60,
      ); // soft cap
      _workDuration = newVal;
    }
  }

  void _adaptDecreaseWorkDuration() {
    // called when user keeps pausing frequently
    if (_mode == PomodoroMode.hardcore) {
      final decrease = (_workDuration * 0.07).round();
      _workDuration = max((_hardWork * 0.5).round(), _workDuration - decrease);
    } else {
      final decrease = (_workDuration * 0.05).round();
      _workDuration = max(10 * 60, _workDuration - decrease);
    }
  }

  String _randomEncouragement() {
    if (_mode == PomodoroMode.soft) {
      return _softEncouragements[_rand.nextInt(_softEncouragements.length)];
    } else {
      return _hardEncouragements[_rand.nextInt(_hardEncouragements.length)];
    }
  }

  void _showInAppMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _toggleMode(PomodoroMode newMode, {bool manual = true}) {
    setState(() {
      _mode = newMode;
    });

    // If manual toggle, apply durations immediately and reset current session (but keep stats)
    if (manual) {
      _applyModeDurations();
      _resetTimer(resetModeDurations: true);
      _showInAppMessage(
        _mode == PomodoroMode.soft
            ? 'Switched to Calm Mode'
            : 'Switched to Hardcore Mode',
      );
    } else {
      // For automatic suggestions, we show a suggestion banner (not force change)
      setState(() {
        _showSuggestion = true;
        _suggestionText = newMode == PomodoroMode.soft
            ? 'It looks like you might be tired. Switch to Calm Mode?'
            : 'Nice focus! Want to switch to Hardcore Mode for deeper sessions?';
      });
    }
  }

  void _evaluateAutoSuggestions() {
    // Basic heuristics:
    // - If user paused 2+ times in last session or pauses several times overall: suggest Soft mode
    // - If user completed 3+ consecutive sessions (streak) and fewer pauses: suggest Hardcore
    final recentPauses = _recentSessions.fold<int>(
      0,
      (s, e) => s + (e['pausedCount'] as int? ?? 0),
    );
    if (_pauseCountCurrentSession >= 2 || recentPauses >= 4) {
      if (_mode != PomodoroMode.soft) {
        // suggest soft
        setState(() {
          _showSuggestion = true;
          _suggestionText =
              'You had several interruptions — try Calm Mode to reduce stress.';
        });
      }
      // also gently decrease next work duration
      _adaptDecreaseWorkDuration();
      return;
    }

    if (_completedSessionsStreak >= 3 && _mode != PomodoroMode.hardcore) {
      setState(() {
        _showSuggestion = true;
        _suggestionText = 'Great streak! Try Hardcore Mode for deeper focus.';
      });
      return;
    }

    // otherwise hide suggestion
    setState(() {
      _showSuggestion = false;
      _suggestionText = '';
    });
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double _getProgress() {
    final total = _isBreak ? _getBreakDuration() : _workDuration;
    if (total == 0) return 0.0;
    return 1.0 - (_timeLeft / total);
  }

  // UI: mood selector small
  Widget _buildMoodSelector() {
    final moods = ['Great', 'Okay', 'Neutral', 'Tired', 'Low'];
    return DropdownButton<String>(
      value: _dailyMood,
      items: moods
          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          _dailyMood = v;
          // reapply durations and adjust time left gently (non-intrusive)
          _applyModeDurations();
        });
        _showInAppMessage('Mood set to $_dailyMood');
      },
    );
  }

  // UI: suggestion banner
  Widget _buildSuggestionBanner() {
    if (!_showSuggestion || _suggestionText.isEmpty)
      return const SizedBox.shrink();
    return Container(
      color: Colors.yellow.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(_suggestionText, style: const TextStyle(fontSize: 14)),
          ),
          TextButton(
            onPressed: () {
              // if suggestion contains "Calm" switch to soft, else hardcore
              final preferSoft =
                  _suggestionText.toLowerCase().contains('calm') ||
                  _suggestionText.toLowerCase().contains('tired');
              _toggleMode(
                preferSoft ? PomodoroMode.soft : PomodoroMode.hardcore,
                manual: true,
              );
              setState(() {
                _showSuggestion = false;
                _suggestionText = '';
              });
            },
            child: const Text('Apply'),
          ),
          TextButton(
            onPressed: () => setState(() {
              _showSuggestion = false;
            }),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  // UI: small stats card
  Widget _buildStatsCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Completed',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '$_completedSessionsTotal',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 18),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Streak',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '$_completedSessionsStreak',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Pauses (now)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '$_pauseCountCurrentSession',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // UI: breathing widget
  Widget _buildBreathingAnimation() {
    return ScaleTransition(
      scale: _breathAnim,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            Icons.self_improvement,
            size: 44,
            color: Colors.green.shade700,
          ),
        ),
      ),
    );
  }

  // UI: motivational micro message card
  Widget _buildMotivationCard() {
    final msg = _randomEncouragement();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Card(
        color: _mode == PomodoroMode.soft
            ? Colors.blue.shade50
            : Colors.grey.shade900,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Icon(
                _mode == PomodoroMode.soft ? Icons.spa : Icons.whatshot,
                color: _mode == PomodoroMode.soft ? Colors.blue : Colors.orange,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  msg,
                  style: TextStyle(
                    color: _mode == PomodoroMode.soft
                        ? Colors.black87
                        : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- build scaffold ---
  @override
  Widget build(BuildContext context) {
    final modeLabel = _mode == PomodoroMode.soft
        ? 'Calm Mode'
        : 'Hardcore Mode';
    final sessionLabel = _isBreak ? 'Break' : 'Work';
    final modeColor = _mode == PomodoroMode.soft
        ? Colors.teal
        : Colors.deepOrange;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pomodoro — Smart Study'),
        elevation: 0,
        backgroundColor: modeColor,
        actions: [
          // manual toggle segmented
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ToggleButtons(
              isSelected: [
                _mode == PomodoroMode.soft,
                _mode == PomodoroMode.hardcore,
              ],
              onPressed: (i) {
                _toggleMode(
                  i == 0 ? PomodoroMode.soft : PomodoroMode.hardcore,
                  manual: true,
                );
              },
              borderRadius: BorderRadius.circular(8),
              selectedColor: Colors.white,
              color: Colors.white70,
              fillColor: Colors.black26,
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('Calm'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('Hardcore'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildSuggestionBanner(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text(
                  modeLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: modeColor,
                  ),
                ),
                const SizedBox(width: 12),
                _buildMoodSelector(),
                const Spacer(),
                IconButton(
                  tooltip: 'Reset durations & session',
                  onPressed: () => _resetTimer(resetModeDurations: true),
                  icon: const Icon(Icons.restore),
                ),
              ],
            ),
          ),
          _buildStatsCard(),
          _buildMotivationCard(),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                // ← FIX ADDED
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Large progress circle & time
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: CircularProgressIndicator(
                            value: _getProgress(),
                            strokeWidth: 12,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              modeColor,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(_timeLeft),
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              sessionLabel,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Mode: ${_mode == PomodoroMode.soft ? 'Calm' : 'Hardcore'} • Mood: $_dailyMood',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (_isBreak)
                      // breathing helper
                      Column(
                        children: [
                          const Text(
                            'Break helper',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          _buildBreathingAnimation(),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40.0,
                            ),
                            child: Text(
                              'Try this: 4-sec inhale — 4-sec hold — 6-sec exhale. Repeat twice.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      )
                    else
                      // focus tips during work
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 36.0,
                          vertical: 6,
                        ),
                        child: Text(
                          _mode == PomodoroMode.soft
                              ? 'Focus gently: single task, shallow breathing, short sprints.'
                              : 'Deep focus: close other tabs, mute notifications, single task.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                    label: Text(_isRunning ? 'Pause' : 'Start'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: modeColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      if (_isRunning) {
                        _pauseTimer();
                      } else {
                        // if stopped and timeLeft equals 0 or session not set, ensure correct values
                        if (_timeLeft <= 0) {
                          _timeLeft = _isBreak
                              ? _getBreakDuration()
                              : _workDuration;
                        }
                        _startTimer();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () => _resetTimer(resetModeDurations: false),
                  child: const Icon(Icons.replay),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _skipToBreak,
                  child: const Icon(Icons.fast_forward),
                ),
              ],
            ),
          ),

          // Small footer with session quick controls and history preview
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                Text(
                  'Upcoming: ${_isBreak ? 'Work ${_workDuration ~/ 60}m' : 'Break ${_getBreakDuration() ~/ 60}m'}',
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    // quick action: toggle automatic suggestion mode (dismiss)
                    setState(() {
                      _showSuggestion = false;
                      _suggestionText = '';
                    });
                  },
                  child: const Text('Dismiss Suggestions'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
