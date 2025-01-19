import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/doctor.dart';
import '../utils/add_sample_doctors.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<void> _bookAppointment(Doctor doctor, TimeSlot slot) async {
    try {
      // Generate a unique meeting ID
      final meetingId = '${DateTime.now().millisecondsSinceEpoch}-${_auth.currentUser?.uid?.substring(0, 8)}';
      final meetLink = 'https://meet.google.com/$meetingId';
      
      // Create appointment document
      await _firestore.collection('appointments').add({
        'userId': _auth.currentUser?.uid,
        'doctorId': doctor.id,
        'doctorName': doctor.name,
        'specialization': doctor.specialization,
        'date': Timestamp.fromDate(slot.startTime),
        'endTime': Timestamp.fromDate(slot.endTime),
        'meetLink': meetLink,
        'status': 'confirmed',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update the time slot as booked
      // This should be done in a transaction in production
      await _firestore.collection('doctors').doc(doctor.id).update({
        'availableSlots': doctor.availableSlots.map((s) {
          if (s.startTime == slot.startTime) {
            return {...s.toMap(), 'isBooked': true};
          }
          return s.toMap();
        }).toList(),
      });

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment booked successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error booking appointment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showTimeSlots(Doctor doctor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: NetworkImage(doctor.imageUrl),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doctor.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              doctor.specialization,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Available Time Slots',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: doctor.availableSlots.length,
                itemBuilder: (context, index) {
                  final slot = doctor.availableSlots[index];
                  if (slot.isBooked) return const SizedBox.shrink();
                  
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.access_time),
                      title: Text(
                        '${_formatTime(slot.startTime)} - ${_formatTime(slot.endTime)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        _formatDate(slot.startTime),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      trailing: ElevatedButton(
                        onPressed: () => _bookAppointment(doctor, slot),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text('Book'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Book Appointment',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Temporary button to add sample doctors
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              try {
                await addSampleDoctors();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sample doctors added successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error adding doctors: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ],
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
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('doctors').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final doctors = snapshot.data!.docs.map((doc) => 
              Doctor.fromMap(doc.data() as Map<String, dynamic>, doc.id)
            ).toList();

            if (doctors.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.medical_services_outlined, 
                      size: 64, 
                      color: Colors.blue.shade300
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No doctors available',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: doctors.length,
              itemBuilder: (context, index) {
                final doctor = doctors[index];
                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () => _showTimeSlots(doctor),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: NetworkImage(doctor.imageUrl),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doctor.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  doctor.specialization,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.star, 
                                      size: 16, 
                                      color: Colors.amber.shade600
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      doctor.rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Icon(Icons.work, 
                                      size: 16, 
                                      color: Colors.blue.shade600
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${doctor.experience} years',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
} 