import 'package:cloud_firestore/cloud_firestore.dart';

class TimeSlot {
  final DateTime startTime;
  final DateTime endTime;
  final bool isBooked;

  TimeSlot({
    required this.startTime,
    required this.endTime,
    required this.isBooked,
  });

  Map<String, dynamic> toMap() {
    return {
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'isBooked': isBooked,
    };
  }

  factory TimeSlot.fromMap(Map<String, dynamic> map) {
    return TimeSlot(
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: (map['endTime'] as Timestamp).toDate(),
      isBooked: map['isBooked'] as bool,
    );
  }
}

class Doctor {
  final String id;
  final String name;
  final String specialization;
  final String imageUrl;
  final String description;
  final double rating;
  final int experience;
  final List<TimeSlot> availableSlots;

  Doctor({
    required this.id,
    required this.name,
    required this.specialization,
    required this.imageUrl,
    required this.description,
    required this.rating,
    required this.experience,
    required this.availableSlots,
  });

  factory Doctor.fromMap(Map<String, dynamic> map, String docId) {
    return Doctor(
      id: docId,
      name: map['name'] as String,
      specialization: map['specialization'] as String,
      imageUrl: map['imageUrl'] as String,
      description: map['description'] as String,
      rating: (map['rating'] as num).toDouble(),
      experience: map['experience'] as int,
      availableSlots: (map['availableSlots'] as List<dynamic>)
          .map((slot) => TimeSlot.fromMap(slot as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'specialization': specialization,
      'imageUrl': imageUrl,
      'description': description,
      'rating': rating,
      'experience': experience,
      'availableSlots': availableSlots.map((slot) => slot.toMap()).toList(),
    };
  }
} 