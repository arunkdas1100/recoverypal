import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../models/voice_room.dart';

class VoiceChatRoomScreen extends StatefulWidget {
  final String roomId;

  const VoiceChatRoomScreen({
    super.key,
    required this.roomId,
  });

  @override
  State<VoiceChatRoomScreen> createState() => _VoiceChatRoomScreenState();
}

class _VoiceChatRoomScreenState extends State<VoiceChatRoomScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  
  // Agora engine instance
  RtcEngine? _engine;
  bool _isInit = false;
  bool _isMuted = false;
  
  // Your Agora App ID
  final String appId = '2e01978c4ab14504a29a1f03700f3ec6';
  
  // Store connected users info
  final Map<int, String> _users = {};

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  @override
  void dispose() {
    _leaveChannel();
    super.dispose();
  }

  Future<void> _initAgora() async {
    // Request permissions
    await [Permission.microphone].request();

    // Create RTC engine instance
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    // Register event handlers
    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        debugPrint("Local user joined");
        setState(() {
          _isInit = true;
        });
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        debugPrint("Remote user joined: $remoteUid");
        setState(() {
          _users[remoteUid] = remoteUid.toString();
        });
      },
      onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        debugPrint("Remote user left: $remoteUid");
        setState(() {
          _users.remove(remoteUid);
        });
      },
    ));

    // Set audio profile and scenario
    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine!.enableAudio();
    await _engine!.setAudioProfile(
      profile: AudioProfileType.audioProfileDefault,
      scenario: AudioScenarioType.audioScenarioChatroom,
    );

    // Join the channel
    await _engine!.joinChannel(
      token: '', // For testing only. In production, use a token server
      channelId: widget.roomId,
      uid: 0,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
      ),
    );

    // Add user to room participants
    await _firestore.collection('voiceRooms').doc(widget.roomId).update({
      'participants': FieldValue.arrayUnion([_auth.currentUser!.uid])
    });
  }

  Future<void> _leaveChannel() async {
    await _engine?.leaveChannel();
    await _engine?.release();
    
    // Remove user from room participants
    await _firestore.collection('voiceRooms').doc(widget.roomId).update({
      'participants': FieldValue.arrayRemove([_auth.currentUser!.uid])
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _engine?.muteLocalAudioStream(_isMuted);
    });
  }

  Widget _buildParticipantAvatar(String userId, bool isSpeaking) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircleAvatar(
            radius: 30,
            child: Icon(Icons.person),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final photoUrl = userData['photoUrl'] as String?;

        return Stack(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: isSpeaking
                    ? Border.all(color: Colors.blue, width: 2)
                    : null,
              ),
              child: CircleAvatar(
                radius: 30,
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null ? const Icon(Icons.person) : null,
              ),
            ),
            if (isSpeaking)
              Positioned.fill(
                child: CustomPaint(
                  painter: WaveformPainter(),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('voiceRooms').doc(widget.roomId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final room = VoiceRoom.fromMap(
          snapshot.data!.data() as Map<String, dynamic>,
          snapshot.data!.id,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(room.name),
            actions: [
              if (room.hostId == _auth.currentUser!.uid)
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    await _firestore.collection('voiceRooms').doc(widget.roomId).delete();
                    if (!mounted) return;
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: Center(
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final participant in room.participants)
                        _buildParticipantAvatar(
                          participant,
                          !_isMuted && participant == _auth.currentUser!.uid,
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton(
                      onPressed: _toggleMute,
                      backgroundColor: _isMuted ? Colors.red : Colors.green,
                      child: Icon(_isMuted ? Icons.mic_off : Icons.mic),
                    ),
                    const SizedBox(width: 16),
                    FloatingActionButton(
                      onPressed: () {
                        _leaveChannel();
                        Navigator.pop(context);
                      },
                      backgroundColor: Colors.red,
                      child: const Icon(Icons.call_end),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class WaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Animate multiple circles expanding outward
    for (var i = 0; i < 3; i++) {
      final progress = (DateTime.now().millisecondsSinceEpoch / 1000 + i / 3) % 1.0;
      canvas.drawCircle(center, radius * progress, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
} 