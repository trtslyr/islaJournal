import '../services/database_service.dart';
import 'context_settings.dart';

class ConversationMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  ConversationMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'content': content,
      'created_at': timestamp.toIso8601String(),
    };
  }

  factory ConversationMessage.fromMap(Map<String, dynamic> map) {
    return ConversationMessage(
      role: map['role'] as String,
      content: map['content'] as String,
      timestamp: DateTime.parse(map['created_at'] as String),
    );
  }
}

class ConversationSession {
  // Private fields
  String _id;
  String _title;
  List<ConversationMessage> _history;
  DateTime _createdAt;
  DateTime _updatedAt;
  ContextSettings _contextSettings = ContextSettings.empty;
  final DatabaseService _dbService = DatabaseService();

  // Constructor
  ConversationSession({
    String? id,
    required String title,
    List<ConversationMessage>? history,
    DateTime? createdAt,
    DateTime? updatedAt,
    ContextSettings? contextSettings,
  }) : _id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       _title = title,
       _history = history ?? [],
       _createdAt = createdAt ?? DateTime.now(),
       _updatedAt = updatedAt ?? DateTime.now(),
       _contextSettings = contextSettings ?? ContextSettings.empty;

  // Factory constructor for creating a new conversation
  static Future<ConversationSession> create(String title) async {
    final dbService = DatabaseService();
    final id = await dbService.createConversation(title);
    return ConversationSession(id: id, title: title);
  }

  // Factory constructor for loading existing conversation
  static Future<ConversationSession?> load(String id) async {
    final dbService = DatabaseService();
    final conversationData = await dbService.getConversation(id);
    
    if (conversationData == null) return null;
    
    // Parse context settings
    ContextSettings? contextSettings;
    final contextSettingsJson = conversationData['context_settings'] as String?;
    if (contextSettingsJson != null) {
      try {
        final Map<String, dynamic> contextMap = Map<String, dynamic>.from(
          contextSettingsJson.split('&')
            .map((e) => e.split('='))
            .fold<Map<String, dynamic>>({}, (map, pair) {
              if (pair.length == 2) {
                final key = Uri.decodeComponent(pair[0]);
                final value = Uri.decodeComponent(pair[1]);
                // Handle different data types
                if (key == 'customFileIds') {
                  map[key] = value.split(',').where((s) => s.isNotEmpty).toList();
                } else if (key == 'maxTokens') {
                  map[key] = int.tryParse(value) ?? 20000;
                } else {
                  map[key] = value;
                }
              }
              return map;
            })
        );
        contextSettings = ContextSettings.fromJson(contextMap);
      } catch (e) {
        // If parsing fails, use default
        contextSettings = ContextSettings.empty;
      }
    }
    
    final session = ConversationSession(
      id: id,
      title: conversationData['title'] as String,
      contextSettings: contextSettings,
    );
    
    // Load messages from database
    final messagesData = await dbService.getConversationMessages(id);
    session._history.addAll(
      messagesData.map((data) => ConversationMessage.fromMap(data))
    );
    
    return session;
  }

  // Factory constructor for loading all conversations
  static Future<List<ConversationSession>> loadAll() async {
    final dbService = DatabaseService();
    final conversationsData = await dbService.getConversations();
    
    final sessions = <ConversationSession>[];
    for (final data in conversationsData) {
      // Parse context settings
      ContextSettings? contextSettings;
      final contextSettingsJson = data['context_settings'] as String?;
      if (contextSettingsJson != null) {
        try {
          final Map<String, dynamic> contextMap = Map<String, dynamic>.from(
            contextSettingsJson.split('&')
              .map((e) => e.split('='))
              .fold<Map<String, dynamic>>({}, (map, pair) {
                if (pair.length == 2) {
                  final key = Uri.decodeComponent(pair[0]);
                  final value = Uri.decodeComponent(pair[1]);
                  // Handle different data types
                  if (key == 'customFileIds') {
                    map[key] = value.split(',').where((s) => s.isNotEmpty).toList();
                  } else if (key == 'maxTokens') {
                    map[key] = int.tryParse(value) ?? 20000;
                  } else {
                    map[key] = value;
                  }
                }
                return map;
              })
          );
          contextSettings = ContextSettings.fromJson(contextMap);
        } catch (e) {
          // If parsing fails, use default
          contextSettings = ContextSettings.empty;
        }
      }
      
      final session = ConversationSession(
        id: data['id'] as String,
        title: data['title'] as String,
        contextSettings: contextSettings,
      );
      
      // Load messages from database
      final messagesData = await dbService.getConversationMessages(session.id);
      session._history.addAll(
        messagesData.map((data) => ConversationMessage.fromMap(data))
      );
      
      sessions.add(session);
    }
    
    return sessions;
  }

  // Getters
  String get id => _id;
  String get title => _title;
  set title(String newTitle) => _title = newTitle;
  List<ConversationMessage> get history => _history;
  DateTime get createdAt => _createdAt;
  DateTime get updatedAt => _updatedAt;
  ContextSettings get contextSettings => _contextSettings;
  
  Future<void> addUserMessage(String content) async {
    final message = ConversationMessage(
      role: 'user',
      content: content,
      timestamp: DateTime.now(),
    );
    
    _history.add(message);
    
    // Save to database
    await _dbService.addConversationMessage(id, 'user', content);
    
    // Keep conversation history manageable - trim if needed
    await _trimHistoryIfNeeded();
  }
  
  Future<void> addAssistantMessage(String content) async {
    final message = ConversationMessage(
      role: 'assistant', 
      content: content,
      timestamp: DateTime.now(),
    );
    
    _history.add(message);
    
    // Save to database
    await _dbService.addConversationMessage(id, 'assistant', content);
    
    // Keep conversation history manageable - trim if needed
    await _trimHistoryIfNeeded();
  }
  
  Future<void> clear() async {
    _history.clear();
    await _dbService.clearConversationMessages(id);
  }
  
  Future<void> _trimHistoryIfNeeded() async {
    const maxMessages = 100; // Increased from 50 to allow for more context
    
    if (_history.length > maxMessages) {
      // Remove from memory
      _history.removeRange(0, _history.length - maxMessages);
      
      // Trim from database
      await _dbService.trimConversationMessages(id, maxMessages);
    }
  }
  
  String buildConversationContext() {
    if (_history.isEmpty) return '';
    
    final conversationParts = <String>[];
    
    // Include last 20 messages for context - conversation history is now separated from journal content
    final recentHistory = _history.length > 20 
        ? _history.sublist(_history.length - 20) 
        : _history;
    
    for (final message in recentHistory) {
      final prefix = message.role == 'user' ? 'User' : 'Assistant';
      conversationParts.add('$prefix: ${message.content}');
    }
    
    return conversationParts.join('\n');
  }
  
  bool get hasHistory => _history.isNotEmpty;
  
  // Helper method to get estimated token count
  int get estimatedTokens {
    return _history.fold(0, (sum, message) => sum + _estimateTokens(message.content));
  }
  
  int _estimateTokens(String text) {
    if (text.trim().isEmpty) return 0;
    
    // More accurate token estimation:
    // - Count words and punctuation separately
    // - Average English word is ~1.3 tokens
    // - Punctuation and spaces add overhead
    final words = text.trim().split(RegExp(r'\s+'));
    final wordTokens = (words.length * 1.3).ceil();
    
    // Add overhead for formatting, punctuation, etc.
    final overhead = (text.length * 0.1).ceil();
    
    return wordTokens + overhead;
  }
  
  Future<void> updateTitle(String newTitle) async {
    await _dbService.updateConversation(id, title: newTitle);
    title = newTitle; // Update in-memory title
  }
  
  Future<void> delete() async {
    await _dbService.deleteConversation(id);
  }
  
  Future<void> updateContextSettings(ContextSettings newSettings) async {
    _contextSettings = newSettings;
    await _dbService.updateConversationContextSettings(id, newSettings);
  }
} 