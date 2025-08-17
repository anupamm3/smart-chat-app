import 'package:smart_chat_app/secrets.dart';

class ChatbotConfig {
  // API Configuration
  static String get geminiApiKey {
    // Try environment variable first, then fallback to secrets
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty) return envKey;
    return ApiSecrets.geminiApiKey;
  }
  static const String modelName = 'gemini-1.5-flash';
  static const double temperature = 0.7;
  static const int maxTokens = 1000;
  
  // Chatbot Identity
  static const String chatbotUserId = 'chatbot_assistant';
  static const String chatbotName = 'Smart Assistant';
  static const String chatbotBio = 'AI-powered assistant to help you with questions, creative tasks, and friendly conversation! 🤖✨';
  static const String chatbotPhotoUrl = '';
  static const String chatbotPhoneNumber = 'assistant';
  
  // Rate Limiting Configuration
  static const int maxRequestsPerMinute = 15;
  static const int maxRequestsPerDay = 1500;
  static const Duration requestCooldown = Duration(seconds: 2);
  
  // UI Configuration
  static const int typingDelayBaseMs = 500;
  static const int typingDelayPerCharMs = 20;
  static const int maxTypingDelayMs = 3000;
  static const int maxResponseLength = 500;
  
  // Conversation Configuration
  static const int maxConversationHistory = 20;
  static const String systemPrompt = '''You are a helpful AI assistant integrated into a chat app. 
Your responses should be:
- Conversational and friendly
- Concise but informative (keep responses under 200 words)
- Helpful and supportive
- Appropriate for a messaging app context

You can help users with:
- General questions and information
- Creative writing and brainstorming
- Problem-solving and advice
- Casual conversation

Always maintain a warm, approachable tone.''';

  // Fallback Messages
  static const List<String> greetingResponses = [
    'Hello! 👋 I\'m your AI assistant. How can I help you today?',
    'Hi there! 🌟 Ready to chat? What\'s on your mind?',
    'Hey! 😊 I\'m here to help. What would you like to talk about?',
  ];
  
  static const List<String> helpResponses = [
    'I can help you with:\n• Answering questions\n• Creative writing\n• Problem solving\n• General conversation\n\nJust ask me anything! 😊',
  ];
  
  static const List<String> goodbyeResponses = [
    'Goodbye! Feel free to chat with me anytime. Have a great day! 👋✨',
    'See you later! I\'ll be here whenever you need me. Take care! 🌟',
    'Bye for now! Thanks for chatting with me. Have an awesome day! 😊',
  ];
  
  static const List<String> thankYouResponses = [
    'You\'re welcome! Happy to help! 😊',
    'Glad I could assist! Feel free to ask anytime! 👍',
    'My pleasure! That\'s what I\'m here for! ✨',
  ];
  
  static const String defaultFallbackMessage = 
    'I\'m currently having trouble connecting to my AI brain 🧠 Please try again in a moment, or contact support if the issue persists.';
  
  // Error Messages
  static const String apiKeyMissingError = '❌ Gemini API key not configured';
  static const String initializationFailedError = '❌ Failed to initialize Gemini AI';
  static const String networkError = 'I\'m having trouble connecting right now. Please check your internet connection and try again. 🌐';
  static const String rateLimitError = 'I\'m receiving too many requests right now. Please wait a moment and try again. ⏳';
  static const String dailyLimitError = 'Daily AI message limit reached. The chatbot will be available again tomorrow! 📅';
  static const String authError = 'There\'s an issue with the AI service configuration. Please contact support. 🔑';
  static const String safetyError = 'I can\'t respond to that type of message. Let\'s try talking about something else! 💭';
  static const String timeoutError = 'My response is taking longer than usual. Please try sending your message again. ⏰';
  static const String genericError = 'I encountered an issue while processing your message. Could you try again? 🤖';
  
  // Validation
  static bool get isApiKeyValid => 
    geminiApiKey.isNotEmpty && 
    geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE' &&
    geminiApiKey != 'YOUR_ACTUAL_GEMINI_API_KEY';
    
  // Configuration validation
  static Map<String, dynamic> validateConfig() {
    return {
      'apiKeyValid': isApiKeyValid,
      'apiKeyLength': geminiApiKey.length,
      'modelName': modelName,
      'maxRequestsPerMinute': maxRequestsPerMinute,
      'maxRequestsPerDay': maxRequestsPerDay,
      'isConfigured': isApiKeyValid,
    };
  }

  static void debugConfiguration() {
    print('🔍 Chatbot Configuration Debug:');
    print('📝 API Key configured: ${isApiKeyValid}');
    print('📝 API Key length: ${geminiApiKey.length}');
    print('📝 API Key preview: ${geminiApiKey.length > 10 ? geminiApiKey.substring(0, 10) : 'too short'}...');
    print('📝 Model name: $modelName');
    print('📝 Temperature: $temperature');
    print('📝 Max tokens: $maxTokens');
    
    final validation = validateConfig();
    print('📊 Validation result: $validation');
  }
}