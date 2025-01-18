import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final bool isEditing;
  
  const ProfileSetupScreen({
    super.key,
    this.isEditing = false,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  String? _googlePhotoUrl;
  String? _googleName;
  String? _googleEmail;
  final _formKey = GlobalKey<FormState>();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGoogleProfile();
    if (widget.isEditing) {
      _loadExistingProfile();
    }
  }

  Future<void> _loadGoogleProfile() async {
    final preferences = await SharedPreferences.getInstance();
    setState(() {
      _googlePhotoUrl = preferences.getString('userPhoto');
      _googleName = preferences.getString('userName');
      _googleEmail = preferences.getString('userEmail');
      
      // Save these to profile data as well
      preferences.setString('fullName', _googleName ?? '');
      preferences.setString('profileImagePath', _googlePhotoUrl ?? '');
    });
  }

  Future<void> _loadExistingProfile() async {
    final preferences = await SharedPreferences.getInstance();
    setState(() {
      _heightController.text = preferences.getDouble('height')?.toString() ?? '';
      _weightController.text = preferences.getDouble('weight')?.toString() ?? '';
    });
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final preferences = await SharedPreferences.getInstance();
      
      // Save profile data
      await preferences.setDouble('height', double.parse(_heightController.text));
      await preferences.setDouble('weight', double.parse(_weightController.text));

      if (mounted) {
        if (widget.isEditing) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile Photo from Google
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[200],
                backgroundImage: _googlePhotoUrl != null 
                    ? NetworkImage(_googlePhotoUrl!)
                    : null,
                child: _googlePhotoUrl == null
                    ? const Icon(Icons.person_outline, size: 60, color: Colors.grey)
                    : null,
              ),
              const SizedBox(height: 16),
              
              // Name from Google
              Text(
                _googleName ?? 'Loading...',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              // Email from Google
              Text(
                _googleEmail ?? '',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              
              // Divider with text
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Additional Information',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey[300])),
                ],
              ),
              const SizedBox(height: 32),
              
              // Height and Weight inputs
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _heightController,
                      decoration: const InputDecoration(
                        labelText: 'Height (cm)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.height),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter height';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Invalid height';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      decoration: const InputDecoration(
                        labelText: 'Weight (kg)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.monitor_weight_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter weight';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Invalid weight';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Save button
              FilledButton.icon(
                onPressed: _saveProfile,
                icon: const Icon(Icons.check),
                label: Text(widget.isEditing ? 'Save Changes' : 'Complete Setup'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 