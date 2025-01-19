import 'package:flutter/material.dart';
import 'package:recoverypal/screens/calendar_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';
import 'profile_screen.dart';
import 'blog_screen.dart';
import 'voice_rooms_screen.dart';
import 'voice_chat_room_screen.dart';
import 'appointments_screen.dart';
import '../models/voice_room.dart';
import '../models/daily_check_in.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  int _selectedIndex = 0;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else if (hour < 21) {
      return 'Good Evening';
    } else {
      return 'Good Night';
    }
  }

  Widget _buildHomeContent() {
    return Container(
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
      child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              // Greeting card
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade800],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  FutureBuilder<SharedPreferences>(
                    future: SharedPreferences.getInstance(),
                    builder: (context, snapshot) {
                      final String? imagePath = snapshot.data?.getString('userPhoto');
                      return _buildProfileImage(imagePath);
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: const TextStyle(
                            color: Colors.white,
                                fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        FutureBuilder<String>(
                          future: SharedPreferences.getInstance()
                              .then((prefs) => prefs.getString('fullName') ?? 'User'),
                          builder: (context, snapshot) {
                            return Text(
                              snapshot.data ?? 'User',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                    fontSize: 16,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
              ),
              const SizedBox(height: 24),
              // Statistics Section
              _buildSectionTitle('Your Progress'),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('dailyCheckIns')
                    .where('userId', isEqualTo: _auth.currentUser?.uid)
                    .orderBy('date', descending: true)
                    .limit(7)
                    .snapshots(),
                builder: (context, snapshot) {
                  // Print error for debugging
                  if (snapshot.hasError) {
                    print('Firestore Error: ${snapshot.error}');
                    print('Firestore Error Stack: ${snapshot.stackTrace}');
                    return Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text(
                              'Unable to load progress',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Error: ${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  try {
                    final checkIns = snapshot.data!.docs
                        .map((doc) {
                          try {
                            final data = doc.data() as Map<String, dynamic>;
                            // Add null check for timestamp
                            if (data['timestamp'] == null) {
                              print('Skipping document ${doc.id} due to missing timestamp');
                              return null;
                            }
                            return DailyCheckIn.fromMap(data, doc.id);
                          } catch (e, stackTrace) {
                            print('Error parsing check-in document ${doc.id}: $e');
                            print('Stack trace: $stackTrace');
                            return null;
                          }
                        })
                        .where((checkIn) => checkIn != null)
                        .cast<DailyCheckIn>()
                        .toList();

                    if (checkIns.isEmpty) {
                      return Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(Icons.timeline, size: 48, color: Colors.blue.shade300),
                              const SizedBox(height: 16),
                              const Text(
                                'Start Your Journey',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Complete your first daily check-in to see your progress statistics!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selectedIndex = 2; // Switch to Calendar tab
                                  });
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Start Check-in'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    print('Number of check-ins loaded: ${checkIns.length}');
                    print('Check-ins dates: ${checkIns.map((c) => c.date).toList()}');

                    // Calculate statistics
                    double avgSleep = checkIns.map((c) => c.sleepHours).reduce((a, b) => a + b) / checkIns.length;
                    double avgWater = checkIns.map((c) => c.waterIntake).reduce((a, b) => a + b) / checkIns.length;
                    int totalRoutines = checkIns
                        .expand((c) => c.completedRoutines)
                        .where((r) => r.isCompleted)
                        .length;

                    print('Average sleep: $avgSleep');
                    print('Average water: $avgWater');
                    print('Total completed routines: $totalRoutines');

                    return Column(
                      children: [
                        // Weekly Overview Card
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
                                Text(
                                  'Last ${checkIns.length} Days Overview',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildProgressTile(
                                  Icons.bedtime,
                                  'Average Sleep',
                                  '${avgSleep.toStringAsFixed(1)} hours',
                                  avgSleep >= 7.0,
                                ),
                                _buildProgressTile(
                                  Icons.water_drop,
                                  'Average Water Intake',
                                  '${avgWater.toStringAsFixed(1)} L',
                                  avgWater >= 3.0,
                                ),
                                _buildProgressTile(
                                  Icons.check_circle,
                                  'Completed Routines',
                                  totalRoutines.toString(),
                                  true,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Replace Daily Progress Card with Streak Progress
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
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "You're almost there!",
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          'On the Right Track',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${checkIns.length}',
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                // Progress Bar
                                Column(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: LinearProgressIndicator(
                                        value: checkIns.length / 100, // Assuming goal is 100 days
                                        minHeight: 12,
                                        backgroundColor: Colors.grey.shade200,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.green.shade400,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${checkIns.length} days cleared',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          'Goal 100',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Stats Row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildStreakStat(
                                      icon: Icons.star,
                                      value: '${checkIns.length}',
                                      label: 'Current Streak',
                                      color: Colors.amber,
                                    ),
                                    _buildStreakStat(
                                      icon: Icons.water_drop,
                                      value: '${avgWater.toStringAsFixed(1)}L',
                                      label: 'Avg. Water',
                                      color: Colors.blue,
                                    ),
                                    _buildStreakStat(
                                      icon: Icons.bedtime,
                                      value: '${avgSleep.toStringAsFixed(1)}h',
                                      label: 'Avg. Sleep',
                                      color: Colors.purple,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  } catch (e, stackTrace) {
                    print('Error processing check-ins: $e');
                    print('Stack trace: $stackTrace');
                    return Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text(
                              'Unable to load progress',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Error: $e',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 24),
              // Add this widget to show upcoming appointments
              _buildUpcomingAppointments(),
            ],
          ),
        ),
      ),
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

  Widget _buildProgressTile(IconData icon, String title, String value, bool isAchieved) {
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

  Widget _buildProfileImage(String? imagePath) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 30,
      backgroundColor: Colors.white,
      backgroundImage: imagePath != null && imagePath.startsWith('http')
          ? NetworkImage(imagePath) as ImageProvider
          : imagePath != null
              ? FileImage(File(imagePath))
              : null,
      child: imagePath == null
            ? const Icon(Icons.person_outline, color: Colors.blue, size: 32)
          : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      _buildHomeContent(),
      const BlogScreen(),
      const CalendarScreen(),
      _buildSocialContent(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        elevation: 8,
        backgroundColor: Colors.white,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article),
            label: 'Blogs',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Social',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildSocialContent() {
    return Container(
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
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Social Hub'),
              const SizedBox(height: 20),
              // Voice Rooms Section
              _buildFeatureCard(
                icon: Icons.mic,
                iconColor: Colors.blue,
                title: 'Voice Rooms',
                subtitle: 'Join voice chat rooms and connect with others',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VoiceRoomsScreen()),
                ),
              ),
              const SizedBox(height: 12),
              // Appointments Section
              _buildFeatureCard(
                icon: Icons.calendar_month,
                iconColor: Colors.purple,
                title: 'Appointments',
                subtitle: 'Schedule and manage your appointments',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AppointmentsScreen()),
                ),
              ),
              const SizedBox(height: 20),
              // Active Voice Rooms Preview
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('voiceRooms').limit(3).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Active Voice Rooms'),
                      const SizedBox(height: 16),
                      ...snapshot.data!.docs.map((doc) {
                        final room = VoiceRoom.fromMap(
                          doc.data() as Map<String, dynamic>,
                          doc.id,
                        );
                        return Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: Icon(
                              room.isPrivate ? Icons.lock : Icons.lock_open,
                              color: room.isPrivate ? Colors.red : Colors.green,
                            ),
                            title: Text(
                              room.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${room.participants.length}/${room.maxParticipants} participants',
                            ),
                            trailing: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => VoiceChatRoomScreen(roomId: room.id),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text('Join'),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool isComingSoon = false,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: isComingSoon
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Coming Soon',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }

  Widget _buildStreakStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // Add this widget to show upcoming appointments
  Widget _buildUpcomingAppointments() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('appointments')
          .where('userId', isEqualTo: _auth.currentUser?.uid)
          .where('status', isEqualTo: 'confirmed')
          .orderBy('date', descending: false)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Upcoming Appointments'),
            const SizedBox(height: 16),
            ...snapshot.data!.docs.map((doc) {
              final appointment = doc.data() as Map<String, dynamic>;
              final date = (appointment['date'] as Timestamp).toDate();
              final endTime = (appointment['endTime'] as Timestamp).toDate();
              final now = DateTime.now();
              
              // Skip past appointments
              if (endTime.isBefore(now)) {
                return const SizedBox.shrink();
              }

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
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.medical_services_outlined,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dr. ${appointment['doctorName']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  appointment['specialization'],
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.video_call),
                            color: Colors.blue.shade600,
                            onPressed: () => _joinMeeting(appointment['meetLink']),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, 
                            size: 16, 
                            color: Colors.grey.shade600
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('MMMM d, yyyy').format(date),
                            style: TextStyle(
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.access_time, 
                            size: 16, 
                            color: Colors.grey.shade600
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${DateFormat('h:mm a').format(date)} - ${DateFormat('h:mm a').format(endTime)}',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  // Update the _joinMeeting method
  void _joinMeeting(String meetLink) async {
    final Uri url = Uri.parse(meetLink);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch Google Meet'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error launching meet: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 