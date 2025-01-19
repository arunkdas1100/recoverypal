import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/daily_check_in.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  late DateTime _selectedDay;
  late DateTime _focusedDay;
  Map<DateTime, bool> _completedDays = {};
  Map<DateTime, bool> _achievedGoals = {};
  bool _hasCompletedToday = false;

  // Health metrics
  double _sleepHours = 0;
  double _waterIntake = 0;
  List<DailyRoutine> _routines = [];

  // Constants for goals
  static const double REQUIRED_SLEEP_HOURS = 7.0;
  static const double REQUIRED_WATER_INTAKE = 3.0;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _focusedDay = DateTime.now();
    _loadCompletedDays();
    _loadDailyCheckIn();
  }

  Future<void> _loadCompletedDays() async {
    final checkIns = await _firestore
        .collection('dailyCheckIns')
        .where('userId', isEqualTo: _auth.currentUser!.uid)
        .get();

    setState(() {
      _completedDays = {};
      _achievedGoals = {};
      for (var doc in checkIns.docs) {
        final data = doc.data();
        final date = DateTime(
          (data['date'] as Timestamp).toDate().year,
          (data['date'] as Timestamp).toDate().month,
          (data['date'] as Timestamp).toDate().day,
        );
        _completedDays[date] = data['isCompleted'] ?? false;
        _achievedGoals[date] = data['goalAchieved'] ?? false;
      }
    });
  }

  Future<void> _loadDailyCheckIn() async {
    final today = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    final checkIn = await _firestore
        .collection('dailyCheckIns')
        .where('userId', isEqualTo: _auth.currentUser!.uid)
        .where('date', isEqualTo: Timestamp.fromDate(today))
        .get();

    if (checkIn.docs.isNotEmpty) {
      final data = DailyCheckIn.fromMap(
        checkIn.docs.first.data(),
        checkIn.docs.first.id,
      );
      setState(() {
        _sleepHours = data.sleepHours;
        _waterIntake = data.waterIntake;
        _routines = data.completedRoutines;
        _hasCompletedToday = data.isCompleted;
      });
    } else {
      setState(() {
        _sleepHours = 0;
        _waterIntake = 0;
        _routines = List.from(defaultRoutines);
        _hasCompletedToday = false;
      });
    }
  }

  bool _checkGoalAchievement() {
    return _sleepHours >= REQUIRED_SLEEP_HOURS && 
           _waterIntake >= REQUIRED_WATER_INTAKE &&
           _routines.every((routine) => routine.isCompleted);
  }

  Future<void> _submitCheckIn() async {
    if (_sleepHours == 0 || _waterIntake == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all health metrics')),
      );
      return;
    }

    try {
      final goalAchieved = _checkGoalAchievement();
      String message;
      Color messageColor;

      if (goalAchieved) {
        message = 'Congratulations! You\'ve achieved your daily goals! 🎉';
        messageColor = Colors.green;
      } else {
        message = 'Keep pushing! Remember:\n'
            '• Sleep at least 7 hours\n'
            '• Drink at least 3L of water\n'
            '• Complete all daily routines';
        messageColor = Colors.orange;
      }

      // Check if an entry already exists for this day
      final today = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
      final existingCheckIn = await _firestore
          .collection('dailyCheckIns')
          .where('userId', isEqualTo: _auth.currentUser!.uid)
          .where('date', isEqualTo: Timestamp.fromDate(today))
          .get();

      if (existingCheckIn.docs.isNotEmpty) {
        // Update existing check-in
        await _firestore
            .collection('dailyCheckIns')
            .doc(existingCheckIn.docs.first.id)
            .update({
          'sleepHours': _sleepHours,
          'waterIntake': _waterIntake,
          'completedRoutines': _routines.map((r) => r.toMap()).toList(),
          'isCompleted': true,
          'goalAchieved': goalAchieved,
        });
      } else {
        // Create new check-in
        final checkIn = DailyCheckIn(
          id: '',
          date: today,
          sleepHours: _sleepHours,
          waterIntake: _waterIntake,
          completedRoutines: _routines,
          userId: _auth.currentUser!.uid,
          isCompleted: true,
          goalAchieved: goalAchieved,
        );

        await _firestore.collection('dailyCheckIns').add(checkIn.toMap());
      }
      
      setState(() {
        _hasCompletedToday = true;
        _completedDays[today] = true;
        _achievedGoals[today] = goalAchieved;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: messageColor,
          duration: const Duration(seconds: 4),
        ),
      );

      // Reload the calendar data
      await _loadCompletedDays();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving check-in: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    final bool isToday = isSameDay(selectedDate, today);
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Daily Check-in',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade800,
              Colors.blue.shade50,
            ],
            stops: const [0.0, 0.2],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TableCalendar(
                    firstDay: DateTime(now.year - 1),
                    lastDay: now,  // Restrict to today
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    calendarFormat: CalendarFormat.month,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    headerStyle: HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: false,
                      titleTextStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.blue),
                      rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.blue),
                    ),
                    calendarStyle: CalendarStyle(
                      selectedDecoration: BoxDecoration(
                        color: Colors.blue.shade600,
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: Colors.blue.shade300,
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      weekendTextStyle: const TextStyle(color: Colors.red),
                      disabledTextStyle: TextStyle(color: Colors.grey.shade400),
                    ),
                    onDaySelected: (selectedDay, focusedDay) {
                      if (!isSameDay(_selectedDay, selectedDay)) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                        _loadDailyCheckIn();
                      }
                    },
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, date, events) {
                        if (_achievedGoals[DateTime(date.year, date.month, date.day)] == true) {
                          return Container(
                            margin: const EdgeInsets.all(4.0),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green,
                            ),
                            width: 8,
                            height: 8,
                          );
                        } else if (_completedDays[DateTime(date.year, date.month, date.day)] == true) {
                          return Container(
                            margin: const EdgeInsets.all(4.0),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.orange.shade600,
                            ),
                            width: 8,
                            height: 8,
                          );
                        }
                        return null;
                      },
                      defaultBuilder: (context, day, focusedDay) {
                        if (day.isAfter(now)) {
                          return Center(
                            child: Text(
                              '${day.day}',
                              style: TextStyle(color: Colors.grey.shade400),
                            ),
                          );
                        }
                        return null;
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Legend
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildLegendItem(Colors.green, 'Goal Achieved'),
                      _buildLegendItem(Colors.orange.shade600, 'Completed'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (!isToday) ...[
                Center(
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            selectedDate.isAfter(today) 
                              ? Icons.lock_clock 
                              : Icons.history,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            selectedDate.isAfter(today)
                              ? 'Future dates are locked'
                              : 'Past check-ins are locked',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            selectedDate.isAfter(today)
                              ? 'You can only complete check-ins for the current day'
                              : 'You can only view past check-ins',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else if (!_hasCompletedToday) ...[
                _buildGoalsCard(),
                const SizedBox(height: 24),
                _buildSectionTitle('Health Metrics'),
                const SizedBox(height: 16),
                _buildHealthMetricsCard(),
                const SizedBox(height: 24),
                _buildSectionTitle('Daily Routines'),
                const SizedBox(height: 16),
                _buildRoutinesCard(),
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton(
                    onPressed: _submitCheckIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 4,
                    ),
                    child: const Text(
                      'Complete Check-in',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ] else
                _buildCompletionSummary(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildGoalsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.stars, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Daily Goals',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildGoalItem(
              Icons.bedtime,
              'Sleep at least ${REQUIRED_SLEEP_HOURS.toStringAsFixed(1)} hours',
            ),
            const SizedBox(height: 8),
            _buildGoalItem(
              Icons.water_drop,
              'Drink at least ${REQUIRED_WATER_INTAKE.toStringAsFixed(1)}L of water',
            ),
            const SizedBox(height: 8),
            _buildGoalItem(
              Icons.check_circle,
              'Complete all daily routines',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHealthMetricsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetricSlider(
              'Sleep Hours',
              Icons.bedtime,
              _sleepHours,
              REQUIRED_SLEEP_HOURS,
              0,
              12,
              24,
              'hours',
            ),
            const SizedBox(height: 24),
            _buildMetricSlider(
              'Water Intake',
              Icons.water_drop,
              _waterIntake,
              REQUIRED_WATER_INTAKE,
              0,
              5,
              10,
              'L',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricSlider(
    String title,
    IconData icon,
    double value,
    double required,
    double min,
    double max,
    int divisions,
    String unit,
  ) {
    final isAchieved = value >= required;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isAchieved ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${value.toStringAsFixed(1)} / ${required.toStringAsFixed(1)} $unit',
                style: TextStyle(
                  color: isAchieved ? Colors.green : Colors.orange.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: isAchieved ? Colors.green : Colors.orange,
            inactiveTrackColor: Colors.grey.shade200,
            thumbColor: isAchieved ? Colors.green : Colors.orange,
            overlayColor: (isAchieved ? Colors.green : Colors.orange).withOpacity(0.2),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: '${value.toStringAsFixed(1)} $unit',
            onChanged: (newValue) {
              setState(() {
                if (title == 'Sleep Hours') {
                  _sleepHours = newValue;
                } else {
                  _waterIntake = newValue;
                }
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRoutinesCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _routines.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final routine = _routines[index];
          return CheckboxListTile(
            title: Text(
              routine.name,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade800,
                fontWeight: routine.isCompleted ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            value: routine.isCompleted,
            activeColor: Colors.green,
            checkColor: Colors.white,
            onChanged: (value) {
              setState(() {
                _routines[index] = DailyRoutine(
                  name: routine.name,
                  isCompleted: value ?? false,
                );
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildCompletionSummary() {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _achievedGoals[_selectedDay] == true
                  ? Colors.green.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _achievedGoals[_selectedDay] == true
                  ? Icons.emoji_events
                  : Icons.check_circle,
              color: _achievedGoals[_selectedDay] == true
                  ? Colors.green
                  : Colors.orange.shade600,
              size: 64,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _achievedGoals[_selectedDay] == true
                ? 'Daily Goals Achieved! 🎉'
                : 'Daily Check-in Completed',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _achievedGoals[_selectedDay] == true
                  ? Colors.green
                  : Colors.orange.shade600,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryTile(
                    Icons.bedtime,
                    'Sleep',
                    '${_sleepHours.toStringAsFixed(1)} hours',
                    _sleepHours >= REQUIRED_SLEEP_HOURS,
                  ),
                  const Divider(),
                  _buildSummaryTile(
                    Icons.water_drop,
                    'Water',
                    '${_waterIntake.toStringAsFixed(1)} L',
                    _waterIntake >= REQUIRED_WATER_INTAKE,
                  ),
                  const Divider(),
                  const Text(
                    'Completed Routines',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...(_routines.where((r) => r.isCompleted).map((r) => 
                    ListTile(
                      leading: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                      ),
                      title: Text(
                        r.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      dense: true,
                    ),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTile(IconData icon, String title, String value, bool isAchieved) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue.shade600),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isAchieved ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          value,
          style: TextStyle(
            color: isAchieved ? Colors.green : Colors.orange.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
} 