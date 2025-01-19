import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/voice_room.dart';
import 'voice_chat_room_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isPrivate = false;
  bool _isLoading = false;

  Future<void> _createRoom() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final roomRef = await FirebaseFirestore.instance.collection('voiceRooms').add({
        'name': _nameController.text,
        'description': _descriptionController.text,
        'hostId': user.uid,
        'isPrivate': _isPrivate,
        'pinCode': _isPrivate ? _pinController.text : null,
        'participants': [user.uid],
        'createdAt': FieldValue.serverTimestamp(),
        'maxParticipants': 3,
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VoiceChatRoomScreen(roomId: roomRef.id),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating room: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Voice Room'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Room Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.meeting_room),
                        ),
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Please enter a room name' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Room Description',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                          hintText: 'What is this room about?',
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Private Room'),
                        subtitle: const Text('Require PIN to join'),
                        value: _isPrivate,
                        onChanged: (value) => setState(() => _isPrivate = value),
                      ),
                      if (_isPrivate) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _pinController,
                          decoration: const InputDecoration(
                            labelText: 'PIN Code',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) => _isPrivate && (value?.isEmpty ?? true)
                              ? 'Please enter a PIN code'
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _createRoom,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Create Room'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _pinController.dispose();
    super.dispose();
  }
} 