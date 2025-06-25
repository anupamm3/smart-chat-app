import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime? timestamp;
  final bool isScheduled;
  final DateTime? scheduledTime;

  MessageModel({
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.timestamp,
    this.isScheduled = false,
    this.scheduledTime,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      text: map['text'] ?? '',
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : null,
      isScheduled: map['isSent'] == false, // If not sent, it's scheduled
      scheduledTime: map['scheduledTime'] != null
          ? (map['scheduledTime'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': timestamp,
      'isSent': !isScheduled,
      'scheduledTime': scheduledTime,
    };
  }
}