import 'package:flutter/foundation.dart';
import '../models/conversation_session.dart';
import '../services/database_service.dart';

class ConversationProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  
  List<ConversationSession> _conversations = [];
  ConversationSession? _activeConversation;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<ConversationSession> get conversations => List.unmodifiable(_conversations);
  ConversationSession? get activeConversation => _activeConversation;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasConversations => _conversations.isNotEmpty;

  // Initialize the provider
  Future<void> initialize() async {
    await loadConversations();
    await loadActiveConversation();
  }

  // Load all conversations from database
  Future<void> loadConversations() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _conversations = await ConversationSession.loadAll();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load conversations: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load the active conversation
  Future<void> loadActiveConversation() async {
    try {
      final activeId = await _dbService.getActiveConversationId();
      if (activeId != null) {
        _activeConversation = await ConversationSession.load(activeId);
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to load active conversation: $e';
    }
  }

  // Create a new conversation
  Future<ConversationSession> createConversation([String? title]) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final defaultTitle = title ?? 'Chat ${_conversations.length + 1}';
      final conversation = await ConversationSession.create(defaultTitle);
      
      _conversations.insert(0, conversation); // Add to beginning of list
      await setActiveConversation(conversation);
      
      return conversation;
    } catch (e) {
      _error = 'Failed to create conversation: $e';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Set the active conversation
  Future<void> setActiveConversation(ConversationSession conversation) async {
    try {
      await _dbService.setActiveConversation(conversation.id);
      _activeConversation = conversation;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to set active conversation: $e';

    }
  }

  // Delete a conversation
  Future<void> deleteConversation(ConversationSession conversation) async {
    try {
  
      await conversation.delete();
      
  
      final beforeCount = _conversations.length;
      _conversations.removeWhere((c) => c.id == conversation.id);
      final afterCount = _conversations.length;
      
      
      // If this was the active conversation, clear it
      if (_activeConversation?.id == conversation.id) {

        _activeConversation = null;
        
        // Set the first conversation as active if available
        if (_conversations.isNotEmpty) {

          await setActiveConversation(_conversations.first);
        } else {
          
        }
      }
      
      
      notifyListeners();
      
    } catch (e) {
      _error = 'Failed to delete conversation: $e';
      
    }
  }

  // Clear all conversations
  Future<void> clearAllConversations() async {
    try {
      for (final conversation in _conversations) {
        await conversation.delete();
      }
      
      _conversations.clear();
      _activeConversation = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to clear all conversations: $e';
      
    }
  }

  // Update conversation title
  Future<void> updateConversationTitle(ConversationSession conversation, String newTitle) async {
    try {
  
      await conversation.updateTitle(newTitle);
      
      
      // The conversation object itself is updated, no need to replace it
      // Just notify listeners that the data has changed
      
      notifyListeners();
      
    } catch (e) {
      _error = 'Failed to update conversation title: $e';
      
    }
  }

  // Get or create a default conversation
  Future<ConversationSession> getOrCreateDefaultConversation() async {
    if (_activeConversation != null) {
      return _activeConversation!;
    }
    
    if (_conversations.isNotEmpty) {
      await setActiveConversation(_conversations.first);
      return _conversations.first;
    }
    
    return await createConversation('General Chat');
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Search conversations by title
  List<ConversationSession> searchConversations(String query) {
    if (query.isEmpty) return _conversations;
    
    return _conversations.where((conversation) =>
      conversation.title.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  // Get conversation by ID
  ConversationSession? getConversationById(String id) {
    try {
      return _conversations.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get recent conversations (sorted by update time)
  List<ConversationSession> getRecentConversations({int limit = 5}) {
    final sorted = List<ConversationSession>.from(_conversations);
    // Note: We would need to add updatedAt to ConversationSession to sort properly
    // For now, just return the first conversations
    return sorted.take(limit).toList();
  }

  // Update context settings for active conversation
  Future<void> updateContextSettings(dynamic newSettings) async {
    try {
      if (_activeConversation != null) {
    
        await _activeConversation!.updateContextSettings(newSettings);
    
        notifyListeners();
        
      }
    } catch (e) {
      _error = 'Failed to update context settings: $e';
      
    }
  }
} 