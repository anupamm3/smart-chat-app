import 'package:smart_chat_app/config/chatbot_config.dart';
import 'package:smart_chat_app/models/user_model.dart';
import 'package:smart_chat_app/services/chatbot_service.dart';

class ChatbotModel extends UserModel {
  // Static chatbot properties
  static const String _chatbotUid = ChatbotConfig.chatbotUserId;
  static const String _chatbotName = ChatbotConfig.chatbotName;
  static const String _chatbotBio = ChatbotConfig.chatbotBio;
  static const String _chatbotPhotoUrl = ChatbotConfig.chatbotPhotoUrl;
  static const String _chatbotPhoneNumber = ChatbotConfig.chatbotPhoneNumber;
  static const bool _isOnline = true;

  // Additional chatbot-specific properties
  final bool isAI;
  final String version;
  final DateTime createdAt;

  ChatbotModel({
    required super.uid,
    required super.phoneNumber,
    required super.name,
    required super.bio,
    required super.photoUrl,
    required super.isOnline,
    required super.lastSeen,
    required super.groups,
    required super.friends,
    required super.blockedUsers,
    this.isAI = true,
    this.version = '1.0.0',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Get the singleton chatbot user instance
  static ChatbotModel getChatbotUser() {
    return ChatbotModel(
      uid: _chatbotUid,
      phoneNumber: _chatbotPhoneNumber,
      name: _chatbotName,
      bio: _chatbotBio,
      photoUrl: _chatbotPhotoUrl,
      isOnline: _isOnline,
      lastSeen: DateTime.now(),
      groups: [],
      friends: [],
      blockedUsers: [],
      isAI: true,
      version: '1.0.0',
    );
  }

  /// Check if a message is from the chatbot
  static bool isChatbotMessage(String senderId) {
    return senderId == _chatbotUid;
  }

  /// Check if a user is the chatbot
  static bool isChatbotUser(String uid) {
    return uid == _chatbotUid;
  }

  /// Generate chatbot response using ChatbotService
  static Future<String> generateChatbotResponse(String userMessage) async {
    try {
      final chatbotService = ChatbotService();
      final response = await chatbotService.sendMessageToGemini(userMessage);
      return response;
    } catch (e) {
      // Fallback responses if Gemini fails
      return _getFallbackResponse(userMessage);
    }
  }

  /// Fallback responses when AI service is unavailable
  static String _getFallbackResponse(String userMessage) {
    final message = userMessage.toLowerCase().trim();
    
    // Greeting responses
    if (message.contains('hello') || message.contains('hi') || message.contains('hey')) {
      return 'Hello! 👋 I\'m your AI assistant. How can I help you today?';
    }
    
    // Help responses
    if (message.contains('help') || message.contains('what can you do')) {
      return 'I can help you with:\n• Answering questions\n• Creative writing\n• Problem solving\n• General conversation\n\nJust ask me anything! 😊';
    }
    
    // Goodbye responses
    if (message.contains('bye') || message.contains('goodbye') || message.contains('see you')) {
      return 'Goodbye! Feel free to chat with me anytime. Have a great day! 👋✨';
    }
    
    // Thank you responses
    if (message.contains('thank') || message.contains('thanks')) {
      return 'You\'re welcome! Happy to help! 😊';
    }
    
    // Default fallback
    return 'I\'m currently having trouble connecting to my AI brain 🧠 Please try again in a moment, or contact support if the issue persists.';
  }

  /// Get chatbot status info
  static Future<Map<String, dynamic>> getChatbotStatus() async {
    final chatbotService = ChatbotService();
    final isAvailable = chatbotService.isAvailable;
    final quotaInfo = chatbotService.getQuotaInfo();
    
    return {
      'isAvailable': isAvailable,
      'modelInfo': chatbotService.modelInfo,
      'quotaInfo': quotaInfo,
      'uid': _chatbotUid,
      'name': _chatbotName,
      'version': '1.0.0',
    };
  }

  /// Convert chatbot to UserModel for compatibility
  UserModel toUserModel() {
    return UserModel(
      uid: uid,
      phoneNumber: phoneNumber,
      name: name,
      bio: bio,
      photoUrl: photoUrl,
      isOnline: isOnline,
      lastSeen: lastSeen,
      groups: groups,
      friends: friends,
      blockedUsers: blockedUsers,
    );
  }

  /// Create ChatbotModel from UserModel
  static ChatbotModel fromUserModel(UserModel userModel) {
    return ChatbotModel(
      uid: userModel.uid,
      phoneNumber: userModel.phoneNumber,
      name: userModel.name,
      bio: userModel.bio,
      photoUrl: userModel.photoUrl,
      isOnline: userModel.isOnline,
      lastSeen: userModel.lastSeen,
      groups: userModel.groups,
      friends: userModel.friends,
      blockedUsers: userModel.blockedUsers,
      isAI: isChatbotUser(userModel.uid),
    );
  }

  /// Serialization methods for compatibility
  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'isAI': isAI,
      'version': version,
      'createdAt': createdAt.millisecondsSinceEpoch,
    });
    return map;
  }

  /// Create ChatbotModel from Map
  static ChatbotModel fromMap(Map<String, dynamic> map) {
    return ChatbotModel(
      uid: map['uid'] ?? _chatbotUid,
      phoneNumber: map['phoneNumber'] ?? _chatbotPhoneNumber,
      name: map['name'] ?? _chatbotName,
      bio: map['bio'] ?? _chatbotBio,
      photoUrl: map['photoUrl'] ?? _chatbotPhotoUrl,
      isOnline: map['isOnline'] ?? _isOnline,
      lastSeen: map['lastSeen'] != null 
          ? (map['lastSeen'] is DateTime 
              ? map['lastSeen'] 
              : DateTime.fromMillisecondsSinceEpoch(map['lastSeen']))
          : DateTime.now(),
      groups: List<String>.from(map['groups'] ?? []),
      friends: List<String>.from(map['friends'] ?? []),
      blockedUsers: List<String>.from(map['blockedUsers'] ?? []),
      isAI: map['isAI'] ?? true,
      version: map['version'] ?? '1.0.0',
      createdAt: map['createdAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
    );
  }

  /// JSON serialization
  @override
  String toString() {
    return 'ChatbotModel(uid: $uid, name: $name, isAI: $isAI, version: $version)';
  }

  /// Copy with method for immutability
  @override
  ChatbotModel copyWith({
    String? uid,
    String? phoneNumber,
    String? name,
    String? bio,
    String? photoUrl,
    bool? isOnline,
    DateTime? lastSeen,
    List<String>? groups,
    List<String>? friends,
    List<String>? blockedUsers,
    bool? isAI,
    String? version,
    DateTime? createdAt,
  }) {
    return ChatbotModel(
      uid: uid ?? this.uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      photoUrl: photoUrl ?? this.photoUrl,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      groups: groups ?? this.groups,
      friends: friends ?? this.friends,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      isAI: isAI ?? this.isAI,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Equality operators
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatbotModel &&
        other.uid == uid &&
        other.name == name &&
        other.isAI == isAI &&
        other.version == version;
  }

  @override
  int get hashCode {
    return uid.hashCode ^ name.hashCode ^ isAI.hashCode ^ version.hashCode;
  }

  /// Predefined chatbot personalities (for future expansion)
  static List<ChatbotModel> getPredefinedChatbots() {
    return [
      getChatbotUser(), // Default assistant
      // Future: Add specialized bots
      // ChatbotModel(uid: 'creative_bot', name: 'Creative Writer', ...),
      // ChatbotModel(uid: 'coding_bot', name: 'Code Helper', ...),
    ];
  }
}