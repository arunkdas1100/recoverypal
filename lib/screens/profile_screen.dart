import 'package:flutter/material.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'profile_setup_screen.dart';
import 'login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _name;
  int? _age;
  double? _height;
  double? _weight;
  String? _profileImagePath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    setState(() {
      _name = preferences.getString('fullName');
      _age = preferences.getInt('age');
      _height = preferences.getDouble('height');
      _weight = preferences.getDouble('weight');
      _profileImagePath = preferences.getString('userPhoto');
    });
  }

  Future<void> _handleLogout() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();
      
      // Sign out from Google
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();

      // Clear SharedPreferences
      final SharedPreferences preferences = await SharedPreferences.getInstance();
      await preferences.clear();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildProfileImage() {
    return CircleAvatar(
      radius: 60,
      backgroundColor: Colors.grey[200],
      backgroundImage: _profileImagePath != null && _profileImagePath!.startsWith('http')
          ? NetworkImage(_profileImagePath!) as ImageProvider
          : _profileImagePath != null
              ? FileImage(File(_profileImagePath!))
              : null,
      child: _profileImagePath == null
          ? const Icon(Icons.person_outline, size: 60, color: Colors.grey)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileSetupScreen(isEditing: true),
                ),
              ).then((_) => _loadProfile());
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildProfileImage(),
                  const SizedBox(height: 16),
                  Text(
                    _name ?? 'No Name',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 32),
                  _buildInfoCard(
                    title: 'Personal Information',
                    items: [
                      InfoItem(icon: Icons.height, label: 'Height', value: '${_height?.toString() ?? 'Not set'} cm'),
                      InfoItem(icon: Icons.monitor_weight_outlined, label: 'Weight', value: '${_weight?.toString() ?? 'Not set'} kg'),
                    ],
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard({required String title, required List<InfoItem> items}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(item.icon, size: 24, color: Colors.blue),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        item.value,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class InfoItem {
  final IconData icon;
  final String label;
  final String value;

  InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });
} 