import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_chat_app/widgets/messege_bubble.dart';

class MessageModel {
  final String senderId;
  final String? receiverId;
  final String text;
  final DateTime? timestamp;
  final MessageStatus status;
  final String? type;
  final bool sent;
  final DateTime? scheduledTime;

  MessageModel({
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.timestamp,
    required this.status,
    this.type,
    this.sent = true,
    this.scheduledTime,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'],
      text: map['text'] ?? '',
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : null,
      status: MessageStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'sent'),
        orElse: () => MessageStatus.sent,
      ),
      type: map['type'] as String?,
      sent: map['sent'] is bool
          ? map['sent'] as bool
          : (map['isSent'] is bool ? map['isSent'] as bool : true),
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
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : null,
      'status': status.name,
      'type': type ?? 'text',
      'sent': sent,
      'scheduledTime': scheduledTime != null ? Timestamp.fromDate(scheduledTime!) : null,
    };
  }
}