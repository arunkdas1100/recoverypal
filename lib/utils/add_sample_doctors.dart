import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> addSampleDoctors() async {
  final firestore = FirebaseFirestore.instance;
  final doctorsCollection = firestore.collection('doctors');

  // Get tomorrow's date for available slots
  final now = DateTime.now();
  final tomorrow = DateTime(now.year, now.month, now.day + 1);

  final sampleDoctors = [
    {
      'name': 'Dr. Sarah Johnson',
      'specialization': 'Psychiatrist',
      'imageUrl': 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?q=80&w=200',
      'description': 'Experienced psychiatrist specializing in addiction recovery and mental health',
      'rating': 4.8,
      'experience': 12,
      'availableSlots': [
        {
          'startTime': Timestamp.fromDate(DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0)),
          'endTime': Timestamp.fromDate(DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10, 0)),
          'isBooked': false,
        },
        {
          'startTime': Timestamp.fromDate(DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 14, 0)),
          'endTime': Timestamp.fromDate(DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 15, 0)),
          'isBooked': false,
        },
      ],
    },
    {
      'name': 'Dr. Michael Chen',
      'specialization': 'Clinical Psychologist',
      'imageUrl': 'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?q=80&w=200',
      'description': 'Specialized in cognitive behavioral therapy and addiction counseling',
      'rating': 4.9,
      'experience': 8,
      'availableSlots': [
        {
          'startTime': Timestamp.fromDate(DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 11, 0)),
          'endTime': Timestamp.fromDate(DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 12, 0)),
          'isBooked': false,
        },
        {
          'startTime': Timestamp.fromDate(DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 16, 0)),
          'endTime': Timestamp.fromDate(DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 17, 0)),
          'isBooked': false,
        },
      ],
    },
    {
      'name': 'Dr. Emily Rodriguez',
      'specialization': 'Addiction Specialist',
      'imageUrl': 'https://images.unsplash.com/photo-1594824476967-48c8b964273f?q=80&w=200',
      'description': 'Expert in substance abuse treatment and recovery programs',
      'rating': 4.7,
      'experience': 15,
      'availableSlots': [
        {
          'startTime': Timestamp.fromDate(DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10, 0)),
          'endTime': Timestamp.fromDate(DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 11, 0)),
          'isBooked': false,
        },
        {
          'startTime': Timestamp.fromDate(DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 15, 0)),
          'endTime': Timestamp.fromDate(DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 16, 0)),
          'isBooked': false,
        },
      ],
    },
    {
      'name': 'Dr. James Wilson',
      'specialization': 'Therapist',
      'imageUrl': 'https://images.unsplash.com/photo-1537368910025-700350fe46c7?q=80&w=200',
      'description': 'Specializing in group therapy and family counseling for recovery support',
      'rating': 4.6,
      'experience': 10,
      'availableSlots': [
        {
          'startTime': Timestamp.fromDate(DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 13, 0)),
          'endTime': Timestamp.fromDate(DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 14, 0)),
          'isBooked': false,
        },
        {
          'startTime': Timestamp.fromDate(DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 17, 0)),
          'endTime': Timestamp.fromDate(DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 18, 0)),
          'isBooked': false,
        },
      ],
    },
  ];

  // Add each doctor to Firestore
  for (final doctor in sampleDoctors) {
    await doctorsCollection.add(doctor);
  }
} 