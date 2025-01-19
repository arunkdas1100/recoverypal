import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/voice_room.dart';
import 'voice_chat_room_screen.dart';

class VoiceRoomsScreen extends StatefulWidget {
  const VoiceRoomsScreen({super.key});

  @override
  State<VoiceRoomsScreen> createState() => _VoiceRoomsScreenState();
}

class _VoiceRoomsScreenState extends State<VoiceRoomsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  
  // Add state variables
  String _roomName = '';
  bool _isPrivate = false;
  String _pinCode = '';

  void _createRoom() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Voice Room'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Room Name'),
                  onChanged: (value) => setState(() => _roomName = value),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Private Room'),
                    Switch(
                      value: _isPrivate,
                      onChanged: (value) => setState(() => _isPrivate = value),
                    ),
                  ],
                ),
                if (_isPrivate)
                  TextField(
                    decoration: const InputDecoration(labelText: 'PIN Code'),
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    onChanged: (value) => setState(() => _pinCode = value),
                  ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              _roomName = '';
              _isPrivate = false;
              _pinCode = '';
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (_roomName.isNotEmpty) {
                final room = VoiceRoom(
                  id: '',
                  name: _roomName,
                  hostId: _auth.currentUser!.uid,
                  isPrivate: _isPrivate,
                  pinCode: _isPrivate ? _pinCode : null,
                  participants: [_auth.currentUser!.uid],
                  createdAt: DateTime.now(),
                );

                final doc = await _firestore.collection('voiceRooms').add(room.toMap());
                
                // Reset state
                _roomName = '';
                _isPrivate = false;
                _pinCode = '';
                
                Navigator.pop(context);
                
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VoiceChatRoomScreen(roomId: doc.id),
                  ),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Rooms'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('voiceRooms')
            // Add orderBy to show newest rooms first
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final rooms = snapshot.data!.docs;

          if (rooms.isEmpty) {
            return const Center(
              child: Text('No voice rooms available. Create one!'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = VoiceRoom.fromMap(
                rooms[index].data() as Map<String, dynamic>,
                rooms[index].id,
              );

              final isHost = room.hostId == _auth.currentUser?.uid;

              return Card(
                child: ListTile(
                  leading: Icon(
                    room.isPrivate ? Icons.lock : Icons.lock_open,
                    color: room.isPrivate ? Colors.red : Colors.green,
                  ),
                  title: Text(room.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${room.participants.length}/${room.maxParticipants} participants'),
                      if (isHost)
                        Text(
                          'You are the host',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isHost)
                        IconButton(
                          icon: const Icon(Icons.stop_circle, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('End Room'),
                                content: const Text(
                                  'Are you sure you want to end this room? '
                                  'This action cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text('End Room'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await _firestore
                                  .collection('voiceRooms')
                                  .doc(room.id)
                                  .delete();
                              
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Room ended successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                        ),
                      ElevatedButton(
                        onPressed: () {
                          if (room.isPrivate) {
                            String enteredPin = '';
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Enter PIN'),
                                content: TextField(
                                  decoration: const InputDecoration(labelText: 'PIN Code'),
                                  keyboardType: TextInputType.number,
                                  maxLength: 4,
                                  onChanged: (value) => enteredPin = value,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      if (enteredPin == room.pinCode) {
                                        Navigator.pop(context);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => VoiceChatRoomScreen(
                                              roomId: room.id,
                                            ),
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Incorrect PIN code'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text('Join'),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VoiceChatRoomScreen(
                                  roomId: room.id,
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text('Join'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createRoom,
        child: const Icon(Icons.add),
      ),
    );
  }
} 