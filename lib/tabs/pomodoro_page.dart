import 'package:flutter/material.dart';
import 'dart:async';

class PomodoroPage extends StatefulWidget {
  const PomodoroPage({super.key});

  @override
  State<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends State<PomodoroPage> {
  Timer? _timer;
  int _timeLeft = 25 * 60; // 25 minutes in seconds
  bool _isRunning = false;
  bool _isBreak = false;
  int _completedSessions = 0;

  final int _workDuration = 25 * 60; // 25 minutes
  final int _shortBreakDuration = 5 * 60; // 5 minutes
  final int _longBreakDuration = 15 * 60; // 15 minutes

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _isRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _onTimerComplete();
        }
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _timeLeft = _isBreak ? _getBreakDuration() : _workDuration;
    });
  }

  void _onTimerComplete() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      if (!_isBreak) {
        _completedSessions++;
        _isBreak = true;
        _timeLeft = _getBreakDuration();
      } else {
        _isBreak = false;
        _timeLeft = _workDuration;
      }
    });

    // Show completion notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isBreak 
              ? '🎉 Work session complete! Time for a break.'
              : '✨ Break time over! Ready to work?',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  int _getBreakDuration() {
    // Long break after every 4 sessions
    return (_completedSessions % 4 == 0) ? _longBreakDuration : _shortBreakDuration;
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  double _getProgress() {
    final totalTime = _isBreak ? _getBreakDuration() : _workDuration;
    return 1.0 - (_timeLeft / totalTime);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            '🍅 Pomodoro Timer',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          
          // Session indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isBreak ? Icons.coffee : Icons.work,
                size: 32,
                color: _isBreak ? Colors.green : Colors.blue,
              ),
              const SizedBox(width: 8),
              Text(
                _isBreak 
                    ? (_completedSessions % 4 == 0 ? 'Long Break' : 'Short Break')
                    : 'Work Session',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Completed sessions
          Text(
            'Completed Sessions: $_completedSessions',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          
          // Timer circle
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: CircularProgressIndicator(
                    value: _getProgress(),
                    strokeWidth: 8,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isBreak ? Colors.green : Colors.blue,
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatTime(_timeLeft),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      _isBreak ? 'Break Time' : 'Focus Time',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          
          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _isRunning ? _pauseTimer : _startTimer,
                icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                label: Text(_isRunning ? 'Pause' : 'Start'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(120, 48),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _resetTimer,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(120, 48),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Progress indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final isCompleted = index < (_completedSessions % 4);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted ? Colors.blue : Colors.grey[300],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sessions until long break',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}