import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../models/voice_room.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/gradient_background.dart';
import '../widgets/custom_card.dart';
import '../theme/app_theme.dart';
import 'dart:io';

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

  // Add these properties
  Timer? _audioLevelTimer;
  final Map<String, double> _audioLevels = {};

  @override
  void initState() {
    super.initState();
    _initAgora();
    // Start monitoring audio levels
    _startAudioLevelMonitoring();
  }

  @override
  void dispose() {
    _audioLevelTimer?.cancel();
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
          // Add current user to the users map
          _users[0] = _auth.currentUser!.uid;
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

  void _startAudioLevelMonitoring() {
    _audioLevelTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _engine?.enableAudioVolumeIndication(
        interval: 100,
        smooth: 3,
        reportVad: true,
      );
    });

    _engine?.registerEventHandler(
      RtcEngineEventHandler(
        onAudioVolumeIndication: (connection, speakers, speakerNumber, totalVolume) {
          setState(() {
            for (var speaker in speakers) {
              // For local user, uid is 0
              final uid = speaker.uid == 0 ? _auth.currentUser!.uid : speaker.uid.toString();
              // Fix null safety issue with volume
              final volume = speaker.volume ?? 0;
              _audioLevels[uid] = volume / 255.0; // Normalize to 0-1
            }
          });
        },
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("Local user joined");
          setState(() {
            _isInit = true;
            _users[0] = _auth.currentUser!.uid;
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
      ),
    );
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
    final audioLevel = _audioLevels[userId] ?? 0.0;
    
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, prefsSnapshot) {
        // For current user, first try to get photo from SharedPreferences
        if (userId == _auth.currentUser!.uid && prefsSnapshot.hasData) {
          final photoUrl = prefsSnapshot.data!.getString('userPhoto');
          final name = prefsSnapshot.data!.getString('fullName') ?? 'User';
          
          if (photoUrl != null && photoUrl.isNotEmpty) {
            return _buildAvatarWithPhoto(photoUrl, name, userId, isSpeaking);
          }
        }

        // If not current user or no SharedPreferences photo, try Firestore
        return StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('users').doc(userId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              print('Error fetching user data: ${snapshot.error}');
              return _buildAvatarWithPhoto(null, 'User', userId, isSpeaking);
            }

            if (!snapshot.hasData) {
              return _buildAvatarWithPhoto(null, 'User', userId, isSpeaking);
            }

            final userData = snapshot.data!.data() as Map<String, dynamic>?;
            if (userData == null) {
              return _buildAvatarWithPhoto(null, 'User', userId, isSpeaking);
            }

            final photoUrl = userData['photoUrl'] ?? 
                           userData['userPhoto'] ?? 
                           userData['photoURL'] ?? 
                           userData['profilePicture'];
            
            final name = userData['fullName'] ?? 
                        userData['displayName'] ?? 
                        userData['name'] ?? 
                        'User';

            return _buildAvatarWithPhoto(photoUrl, name, userId, isSpeaking);
          },
        );
      },
    );
  }

  Widget _buildAvatarWithPhoto(String? photoUrl, String name, String userId, bool isSpeaking) {
    final audioLevel = _audioLevels[userId] ?? 0.0;
    
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Voice activity visualizer
            if (isSpeaking)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: audioLevel),
                duration: const Duration(milliseconds: 100),
                builder: (context, value, child) {
                  return Container(
                    width: 100 + (value * 20), // Grow based on audio level
                    height: 100 + (value * 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.5 + (value * 0.5)),
                        width: 2 + (value * 2),
                      ),
                    ),
                    child: CustomPaint(
                      painter: VoiceVisualizer(
                        animation: value,
                        color: Colors.blue,
                        intensity: value, // Pass audio level to painter
                      ),
                    ),
                  );
                },
              ),

            // Profile picture
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSpeaking ? Colors.blue : Colors.transparent,
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Colors.grey[200],
                backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                    ? (photoUrl.startsWith('http') 
                        ? NetworkImage(photoUrl) 
                        : FileImage(File(photoUrl))) as ImageProvider
                    : null,
                child: (photoUrl == null || photoUrl.isEmpty)
                    ? const Icon(Icons.person, size: 40, color: Colors.grey)
                    : null,
              ),
            ),

            // Mute indicator
            if (_isMuted && userId == _auth.currentUser!.uid)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mic_off,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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
          body: GradientBackground(
            child: Column(
              children: [
                if (room.description.isNotEmpty)
                  CustomCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, color: AppTheme.primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'About this room',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          room.description,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                CustomCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            room.isPrivate ? Icons.lock : Icons.lock_open,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            room.isPrivate ? 'Private Room' : 'Public Room',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      Text(
                        '${room.participants.length}/${room.maxParticipants} participants',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
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
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildControlButton(
                        onPressed: _toggleMute,
                        icon: _isMuted ? Icons.mic_off : Icons.mic,
                        color: _isMuted ? AppTheme.errorColor : AppTheme.successColor,
                      ),
                      const SizedBox(width: 16),
                      _buildControlButton(
                        onPressed: () {
                          _leaveChannel();
                          Navigator.pop(context);
                        },
                        icon: Icons.call_end,
                        color: AppTheme.errorColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlButton({
    required VoidCallback onPressed,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: color,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return RotationTransition(
              turns: animation,
              child: ScaleTransition(
                scale: animation,
                child: child,
              ),
            );
          },
          child: Icon(
            icon,
            key: ValueKey<IconData>(icon),
          ),
        ),
      ),
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

class VoiceVisualizer extends CustomPainter {
  final double animation;
  final Color color;
  final double intensity;

  VoiceVisualizer({
    required this.animation,
    required this.color,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    
    // Ensure minimum visibility even with low audio
    final minIntensity = 0.2;
    final adjustedIntensity = minIntensity + (intensity * (1 - minIntensity));

    for (var i = 0; i < 3; i++) {
      final paint = Paint()
        ..color = color.withOpacity((1 - (i / 3)) * 0.4 * adjustedIntensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 + (intensity * 1.5);

      final progress = (animation + (i / 3)) % 1.0;
      final currentRadius = radius * progress * (1 + (intensity * 0.3));
      
      // Draw multiple circles with wave effect
      for (var j = 0; j < 8; j++) {
        final angle = (j / 8) * 2 * math.pi;
        final offset = Offset(
          math.cos(angle) * (intensity * 3),
          math.sin(angle) * (intensity * 3),
        );
        canvas.drawCircle(center + offset, currentRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(VoiceVisualizer oldDelegate) =>
      animation != oldDelegate.animation ||
      intensity != oldDelegate.intensity;
} 