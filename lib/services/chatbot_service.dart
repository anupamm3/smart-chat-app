import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:smart_chat_app/config/chatbot_config.dart';

class ChatbotService {
  static final ChatbotService _instance = ChatbotService._internal();
  factory ChatbotService() => _instance;
  ChatbotService._internal();

  // Gemini API configuration
  static String get _apiKey => ChatbotConfig.geminiApiKey;
  static const String _modelName = ChatbotConfig.modelName;
  static const double _temperature = ChatbotConfig.temperature;
  static const int _maxTokens = ChatbotConfig.maxTokens;

  GenerativeModel? _model;
  ChatSession? _chatSession;
  List<Content> _conversationHistory = [];
  bool _isInitialized = false;
  
  // Rate limiting
  DateTime? _lastRequestTime;
  static const Duration _requestCooldown = Duration(seconds: 4);
  int _requestCount = 0;
  static const int _maxRequestsPerMinute = 15;
  static const int _maxRequestsPerDay = 1500;
  DateTime _minuteStartTime = DateTime.now();
  DateTime _dayStartTime = DateTime.now();
  int _dailyRequestCount = 0;

  /// Initialize Gemini AI with configuration
  Future<bool> initializeGemini() async {
    try {
      if (_isInitialized) return true;

      // Validate API key
      if (!ChatbotConfig.isApiKeyValid) {
        return false;
      }

      // Initialize the model with safety settings
      _model = GenerativeModel(
        model: _modelName,
        apiKey: _apiKey,
        safetySettings: [
          SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
          SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
          SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.medium),
          SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium),
        ],
        generationConfig: GenerationConfig(
          temperature: _temperature,
          maxOutputTokens: _maxTokens,
          topP: 0.8,
          topK: 40,
        ),
      );

      // Initialize chat session with system instructions
      _chatSession = _model!.startChat();

      _isInitialized = true;
      return true;
    } catch (e) {
      _isInitialized = false;
      return false;
    }
  }

  /// Send message to Gemini and get response
  Future<String> sendMessageToGemini(String userMessage) async {
    const maxRetries = 3;
  const retryDelay = Duration(seconds: 3);

  for (int attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      // Check initialization
      if (!_isInitialized) {
        final initialized = await initializeGemini();
        if (!initialized) {
          return _handleError('AI service is currently unavailable. Please try again later.');
        }
      }

      // Validate input
      if (userMessage.trim().isEmpty) {
        return 'Please send a message for me to respond to! 😊';
      }

      // Check rate limiting
      if (attempt == 1 && !_checkRateLimit()) {
        return 'I\'m receiving too many messages right now. Please wait a moment and try again. ⏰';
      }

      // Add system context to each message
      final contextualMessage = '''${ChatbotConfig.systemPrompt}

User message: $userMessage

Please respond as a helpful AI assistant in a conversational manner.''';

      // Simulate typing delay for realistic experience
      await _simulateTypingDelay(userMessage);

      // Send message to Gemini
      final response = await _chatSession!.sendMessage(
        Content.text(contextualMessage),
      );

      final responseText = response.text;
      if (responseText == null || responseText.isEmpty) {
        return _handleError('I couldn\'t generate a response right now. Could you try rephrasing your message?');
      }

      // Format and return response
      final formattedResponse = _formatResponse(responseText);
      _updateRateLimitingOnSuccess();
      logUsageStats();
      
      // Update conversation history
      _updateConversationHistory(userMessage, formattedResponse);
      
      return formattedResponse;

    } catch (e) {
      // Check if it's a server overload error
      final errorString = e.toString().toLowerCase();
      final isServerOverload = errorString.contains('503') || 
                              errorString.contains('overloaded') || 
                              errorString.contains('unavailable');
      
      // If it's server overload and we have retries left, wait and try again
      if (isServerOverload && attempt < maxRetries) {
        await Future.delayed(retryDelay);
        continue; // Try again
      }
      
      // Specific error handling
      if (e.toString().contains('API_KEY_INVALID')) {
        return 'Invalid API key. Please check your Gemini API key configuration. 🔑';
      }
      
      return _handleError(e);
    }
  }

  // This should never be reached, but just in case
  return _handleError('Failed to get response after $maxRetries attempts');
  }

  void _updateRateLimitingOnSuccess() {
  final now = DateTime.now();
  _lastRequestTime = now;
  _requestCount++;
  _dailyRequestCount++;
}

  /// Check rate limiting
  bool _checkRateLimit() {
    final now = DateTime.now();

    // Reset daily counter
    if (now.difference(_dayStartTime).inDays >= 1) {
      _dailyRequestCount = 0;
      _dayStartTime = now;
    }
    
    // Reset counter if a minute has passed
    if (now.difference(_minuteStartTime).inMinutes >= 1) {
      _requestCount = 0;
      _minuteStartTime = now;
    }

    // Check daily limit
    if (_dailyRequestCount >= _maxRequestsPerDay) {
      return false;
    }
    
    // Check requests per minute limit
    if (_requestCount >= _maxRequestsPerMinute) {
      return false;
    }
    
    // Check cooldown between requests
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = now.difference(_lastRequestTime!);
      if (timeSinceLastRequest < _requestCooldown) {
        return false;
      }
    }
    return true;
  }

  /// Simulate realistic typing delay
  Future<void> _simulateTypingDelay(String message) async {
    // Calculate delay based on message length (simulate reading time)
    final baseDelay = 500; // Base 500ms
    final readingDelay = (message.length * 20); // 20ms per character
    final randomDelay = Random().nextInt(500); // Random 0-500ms
    
    final totalDelay = baseDelay + readingDelay + randomDelay;
    final clampedDelay = totalDelay.clamp(500, 3000); // Between 0.5-3 seconds
    
    await Future.delayed(Duration(milliseconds: clampedDelay));
  }

  /// Format AI response for better chat experience
  String _formatResponse(String response) {
    if (response.trim().isEmpty) {
      return 'I\'m not sure how to respond to that. Could you try asking in a different way? 🤔';
    }

    // Remove excessive whitespace
    String formatted = response.trim().replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n');
    
    // Add conversational elements if response seems too formal
    if (!formatted.contains('!') && !formatted.contains('?') && !formatted.contains('😊') && !formatted.contains('👍')) {
      // Add subtle conversational touch for dry responses
      final conversationalEndings = [
        ' Hope this helps! 😊',
        ' Let me know if you need more info! 👍',
        ' Feel free to ask if you have other questions! 💭',
        ' Does this answer your question? 🤔',
      ];
      
      if (formatted.length < 400) {
        formatted += conversationalEndings[Random().nextInt(conversationalEndings.length)];
      }
    }
    
    return formatted;
  }

  /// Handle various error scenarios
  String _handleError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Network/connectivity errors
    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'I\'m having trouble connecting right now. Please check your internet connection and try again. 🌐';
    }
    
    // API quota/rate limit errors
    if (errorString.contains('quota') || errorString.contains('limit')) {
      if (_dailyRequestCount >= _maxRequestsPerDay) {
        return 'Daily AI message limit reached. The chatbot will be available again tomorrow! 📅';
      } else if (_requestCount >= _maxRequestsPerMinute) {
        return 'I need a short break! Please wait a minute before sending another message. ⏳';
      }
      return 'I\'m receiving too many requests right now. Please wait a moment and try again. ⏳';
    }
    
    // Authentication errors
    if (errorString.contains('auth') || errorString.contains('key')) {
      return 'There\'s an issue with the AI service configuration. Please contact support. 🔑';
    }
    
    // Content filtering errors
    if (errorString.contains('safety') || errorString.contains('blocked')) {
      return 'I can\'t respond to that type of message. Let\'s try talking about something else! 💭';
    }
    
    // Timeout errors
    if (errorString.contains('timeout')) {
      return 'My response is taking longer than usual. Please try sending your message again. ⏰';
    }
    
    // Generic error
    return 'I encountered an issue while processing your message. Could you try again? 🤖';
  }

  /// Update conversation history for context
  void _updateConversationHistory(String userMessage, String aiResponse) {
    _conversationHistory.addAll([
      Content.text(userMessage),
      Content.text(aiResponse),
    ]);
    
    // Keep only last 20 messages for context (10 exchanges)
    if (_conversationHistory.length > 20) {
      _conversationHistory = _conversationHistory.sublist(_conversationHistory.length - 20);
    }
  }

  /// Get conversation history for context
  List<Content> getConversationHistory() {
    return List.from(_conversationHistory);
  }

  /// Clear conversation history
  Future<void> clearConversationHistory() async {
    _conversationHistory.clear();
    
    // Restart chat session to clear context
    if (_model != null) {
      _chatSession = _model!.startChat();
    }
  }

  Map<String, dynamic> getQuotaInfo() {
    final now = DateTime.now();
    final minutesUntilReset = 60 - now.minute;
    final hoursUntilDayReset = 24 - now.hour;
    
    return {
      'requestsThisMinute': _requestCount,
      'maxPerMinute': _maxRequestsPerMinute,
      'requestsToday': _dailyRequestCount,
      'maxPerDay': _maxRequestsPerDay,
      'minutesUntilReset': minutesUntilReset,
      'hoursUntilDayReset': hoursUntilDayReset,
      'canMakeRequest': _requestCount < _maxRequestsPerMinute && _dailyRequestCount < _maxRequestsPerDay,
    };
  }

  void logUsageStats() {
    if (kDebugMode) {
      final quota = getQuotaInfo();
      debugPrint('🤖 Gemini Usage: ${quota['requestsToday']}/${quota['maxPerDay']} daily, ${quota['requestsThisMinute']}/${quota['maxPerMinute']} per minute');
    }
  }

  /// Check if Gemini is available
  bool get isAvailable => _isInitialized && _model != null;

  /// Get current model information
  String get modelInfo => _isInitialized ? 'Gemini Pro (Ready)' : 'Not initialized';

  /// Dispose resources
  void dispose() {
    _conversationHistory.clear();
    _chatSession = null;
    _model = null;
    _isInitialized = false;
  }
}