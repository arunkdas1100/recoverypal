import 'package:cloud_firestore/cloud_firestore.dart';

class VoiceRoom {
  final String id;
  final String name;
  final String hostId;
  final bool isPrivate;
  final String? pinCode;
  final List<String> participants;
  final DateTime createdAt;
  final int maxParticipants = 3;

  VoiceRoom({
    required this.id,
    required this.name,
    required this.hostId,
    required this.isPrivate,
    this.pinCode,
    required this.participants,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'hostId': hostId,
      'isPrivate': isPrivate,
      'pinCode': pinCode,
      'participants': participants,
      'createdAt': Timestamp.fromDate(createdAt),
      'maxParticipants': maxParticipants,
    };
  }

  factory VoiceRoom.fromMap(Map<String, dynamic> map, String id) {
    return VoiceRoom(
      id: id,
      name: map['name'] ?? '',
      hostId: map['hostId'] ?? '',
      isPrivate: map['isPrivate'] ?? false,
      pinCode: map['pinCode'],
      participants: List<String>.from(map['participants'] ?? []),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
} 