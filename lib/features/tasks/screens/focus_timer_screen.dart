import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/task_provider.dart';
import '../models/focus_session_model.dart';
import '../../../features/settings/providers/settings_provider.dart';
import '../../../core/theme/app_theme.dart';

class FocusTimerScreen extends StatefulWidget {
  final String taskId;
  const FocusTimerScreen({super.key, required this.taskId});

  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

enum TimerPhase { focus, shortBreak, longBreak }

class _FocusTimerScreenState extends State<FocusTimerScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  int _secondsLeft = 0;
  bool _isRunning = false;
  TimerPhase _phase = TimerPhase.focus;
  int _sessionsCompleted = 0;
  DateTime? _sessionStart;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reset());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  int get _totalSeconds {
    final settings = context.read<SettingsProvider>();
    switch (_phase) {
      case TimerPhase.focus:
        return settings.pomodoroMinutes * 60;
      case TimerPhase.shortBreak:
        return settings.shortBreakMinutes * 60;
      case TimerPhase.longBreak:
        return settings.longBreakMinutes * 60;
    }
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _secondsLeft = _totalSeconds;
      _isRunning = false;
      _sessionStart = null;
    });
  }

  void _startPause() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      _sessionStart ??= DateTime.now();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_secondsLeft <= 0) {
          t.cancel();
          _onTimerComplete();
        } else {
          setState(() => _secondsLeft--);
        }
      });
      setState(() => _isRunning = true);
    }
  }

  void _onTimerComplete() async {
    if (_phase == TimerPhase.focus && _sessionStart != null) {
      final settings = context.read<SettingsProvider>();
      final session = FocusSessionModel(
        taskId: widget.taskId,
        startTime: _sessionStart!,
        endTime: DateTime.now(),
        durationMinutes: settings.pomodoroMinutes,
        completed: true,
      );
      await context.read<TaskProvider>().addFocusSession(session);
      _sessionsCompleted++;
    }

    setState(() {
      _isRunning = false;
      _sessionStart = null;
      // Switch phase
      if (_phase == TimerPhase.focus) {
        _phase = _sessionsCompleted % 4 == 0
            ? TimerPhase.longBreak
            : TimerPhase.shortBreak;
      } else {
        _phase = TimerPhase.focus;
      }
      _secondsLeft = _totalSeconds;
    });

    _showCompletionSnack();
  }

  void _endEarly() {
    if (_sessionStart != null && _phase == TimerPhase.focus) {
      final elapsed = DateTime.now().difference(_sessionStart!).inMinutes;
      if (elapsed >= 5) {
        // Log partial session if at least 5 minutes
        final session = FocusSessionModel(
          taskId: widget.taskId,
          startTime: _sessionStart!,
          endTime: DateTime.now(),
          durationMinutes: elapsed,
          completed: false,
        );
        context.read<TaskProvider>().addFocusSession(session);
      }
    }
    _reset();
  }

  void _showCompletionSnack() {
    final msg = _phase == TimerPhase.focus
        ? '🎉 Focus session complete! Take a break.'
        : '⚡ Break over! Ready to focus again?';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.successColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String get _formattedTime {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progress {
    final total = _totalSeconds;
    return total > 0 ? 1 - (_secondsLeft / total) : 0;
  }

  @override
  Widget build(BuildContext context) {
    final task = context.watch<TaskProvider>().findById(widget.taskId);
    final theme = Theme.of(context);

    final phaseColor = _phase == TimerPhase.focus
        ? AppTheme.primaryDark
        : _phase == TimerPhase.shortBreak
            ? AppTheme.successColor
            : AppTheme.accentDark;

    final phaseLabel = _phase == TimerPhase.focus
        ? 'Focus'
        : _phase == TimerPhase.shortBreak
            ? 'Short Break'
            : 'Long Break';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(task?.title ?? 'Focus Timer'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isRunning) _endEarly();
            context.pop();
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // ── Phase Selector ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _PhaseTab(
                      label: 'Focus',
                      isSelected: _phase == TimerPhase.focus,
                      color: AppTheme.primaryDark,
                      onTap: () {
                        _reset();
                        setState(() => _phase = TimerPhase.focus);
                        _reset();
                      },
                    ),
                    _PhaseTab(
                      label: 'Short Break',
                      isSelected: _phase == TimerPhase.shortBreak,
                      color: AppTheme.successColor,
                      onTap: () {
                        _reset();
                        setState(() => _phase = TimerPhase.shortBreak);
                        _reset();
                      },
                    ),
                    _PhaseTab(
                      label: 'Long Break',
                      isSelected: _phase == TimerPhase.longBreak,
                      color: AppTheme.accentDark,
                      onTap: () {
                        _reset();
                        setState(() => _phase = TimerPhase.longBreak);
                        _reset();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // ── Timer Ring ─────────────────────────────────────────────
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: _isRunning
                          ? [
                              BoxShadow(
                                color: phaseColor.withValues(
                                  alpha: 0.1 + 0.2 * _pulseController.value,
                                ),
                                blurRadius: 40 + 20 * _pulseController.value,
                                spreadRadius: 5,
                              ),
                            ]
                          : [],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 260,
                          height: 260,
                          child: CircularProgressIndicator(
                            value: _progress,
                            strokeWidth: 8,
                            backgroundColor: phaseColor.withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation(phaseColor),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _formattedTime,
                              style: theme.textTheme.displayLarge?.copyWith(
                                color: phaseColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 52,
                                letterSpacing: -2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              phaseLabel,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(color: phaseColor),
                            ),
                            if (_sessionsCompleted > 0) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (int i = 0;
                                      i <
                                          (_sessionsCompleted % 4 == 0
                                              ? 4
                                              : _sessionsCompleted % 4);
                                      i++)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 2),
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: phaseColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                '$_sessionsCompleted session${_sessionsCompleted != 1 ? 's' : ''} completed today',
                style: theme.textTheme.bodySmall,
              ),

              const Spacer(),

              // ── Controls ───────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Reset
                  IconButton(
                    onPressed: _isRunning ? null : _reset,
                    icon: const Icon(Icons.refresh),
                    iconSize: 32,
                    style: IconButton.styleFrom(
                      backgroundColor: theme.cardColor,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Start/Pause
                  GestureDetector(
                    onTap: _startPause,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            phaseColor,
                            phaseColor.withValues(alpha: 0.7)
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: phaseColor.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isRunning ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Skip
                  IconButton(
                    onPressed: _isRunning ? _endEarly : null,
                    icon: const Icon(Icons.skip_next),
                    iconSize: 32,
                    style: IconButton.styleFrom(
                      backgroundColor: theme.cardColor,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── Task progress ──────────────────────────────────────────
              if (task != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Goal Progress',
                              style: theme.textTheme.titleMedium),
                          Text(
                            '${(task.progressPercent * 100).toStringAsFixed(0)}%',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: task.progressPercent,
                          minHeight: 8,
                          backgroundColor:
                              theme.colorScheme.primary.withValues(alpha: 0.15),
                          valueColor:
                              AlwaysStoppedAnimation(theme.colorScheme.primary),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(task.focusedMinutes / 60).toStringAsFixed(1)}h focused / ${task.estimatedHours.toStringAsFixed(1)}h estimated',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhaseTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _PhaseTab({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color:
                isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? color : Colors.grey,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
