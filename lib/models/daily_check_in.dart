import 'package:cloud_firestore/cloud_firestore.dart';

class DailyCheckIn {
  final String id;
  final DateTime date;
  final double sleepHours;
  final double waterIntake;
  final List<DailyRoutine> completedRoutines;
  final String userId;
  final bool isCompleted;
  final bool goalAchieved;

  DailyCheckIn({
    required this.id,
    required this.date,
    required this.sleepHours,
    required this.waterIntake,
    required this.completedRoutines,
    required this.userId,
    required this.isCompleted,
    required this.goalAchieved,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'sleepHours': sleepHours,
      'waterIntake': waterIntake,
      'completedRoutines': completedRoutines.map((r) => r.toMap()).toList(),
      'userId': userId,
      'isCompleted': isCompleted,
      'goalAchieved': goalAchieved,
    };
  }

  factory DailyCheckIn.fromMap(Map<String, dynamic> map, String id) {
    return DailyCheckIn(
      id: id,
      userId: map['userId'] ?? '',
      date: map['timestamp'] != null 
          ? (map['timestamp'] as Timestamp).toDate() 
          : DateTime.now(),
      sleepHours: (map['sleep'] as num).toDouble(),
      waterIntake: (map['water'] as num).toDouble(),
      completedRoutines: (map['completedRoutines'] as List<dynamic>)
          .map((r) => DailyRoutine.fromMap(r as Map<String, dynamic>))
          .toList(),
      isCompleted: map['isCompleted'] ?? false,
      goalAchieved: map['goalAchieved'] ?? false,
    );
  }
}

class DailyRoutine {
  final String name;
  final bool isCompleted;
  final String? notes;

  DailyRoutine({
    required this.name,
    required this.isCompleted,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isCompleted': isCompleted,
      'notes': notes,
    };
  }

  factory DailyRoutine.fromMap(Map<String, dynamic> map) {
    return DailyRoutine(
      name: map['name'],
      isCompleted: map['isCompleted'],
      notes: map['notes'],
    );
  }
}

// Default daily routines
final List<DailyRoutine> defaultRoutines = [
  DailyRoutine(name: 'Morning Meditation', isCompleted: false),
  DailyRoutine(name: 'Exercise', isCompleted: false),
  DailyRoutine(name: 'Take Medications', isCompleted: false),
  DailyRoutine(name: 'Evening Reflection', isCompleted: false),
  DailyRoutine(name: 'Support Group Meeting', isCompleted: false),
]; 