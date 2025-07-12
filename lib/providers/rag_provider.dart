import 'package:flutter/foundation.dart';
import '../services/rag_service.dart';
import '../models/journal_file.dart';

class RAGProvider with ChangeNotifier {
  final RAGService _ragService = RAGService();
  
  bool _isInitialized = false;
  bool _isLoading = false;
  String _error = '';
  RAGResult? _lastResult;
  List<String> _conversationHistory = [];
  RAGStats? _stats;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String get error => _error;
  RAGResult? get lastResult => _lastResult;
  List<String> get conversationHistory => _conversationHistory;
  RAGStats? get stats => _stats;

  /// Initialize RAG service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _setLoading(true);
    _clearError();
    
    try {
      await _ragService.initialize();
      _isInitialized = true;
      await _loadStats();
      debugPrint('RAG Provider initialized successfully');
    } catch (e) {
      _setError('RAG initialization error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Query the RAG system
  Future<RAGResult?> query(
    String question, {
    String? fileId,
    int maxContexts = 5,
    double similarityThreshold = 0.3,
  }) async {
    if (!_isInitialized) {
      throw Exception('RAG service not initialized');
    }

    _setLoading(true);
    _clearError();

    try {
      final result = await _ragService.query(
        question,
        fileId: fileId,
        maxContexts: maxContexts,
        similarityThreshold: similarityThreshold,
      );
      
      _lastResult = result;
      _conversationHistory.add('Q: $question');
      _conversationHistory.add('A: ${result.answer}');
      
      // Keep conversation history manageable
      if (_conversationHistory.length > 20) {
        _conversationHistory.removeRange(0, _conversationHistory.length - 20);
      }
      
      return result;
    } catch (e) {
      _setError('RAG query error: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Get insights about a specific file
  Future<RAGResult?> getFileInsights(String fileId) async {
    if (!_isInitialized) {
      throw Exception('RAG service not initialized');
    }

    _setLoading(true);
    _clearError();

    try {
      final result = await _ragService.getFileInsights(fileId);
      _lastResult = result;
      return result;
    } catch (e) {
      _setError('File insights error: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Generate writing prompts
  Future<List<String>> generateWritingPrompts({
    int count = 3,
    String? theme,
  }) async {
    if (!_isInitialized) {
      throw Exception('RAG service not initialized');
    }

    _setLoading(true);
    _clearError();

    try {
      final prompts = await _ragService.generateWritingPrompts(
        count: count,
        theme: theme,
      );
      return prompts;
    } catch (e) {
      _setError('Writing prompts error: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Index a journal file
  Future<void> indexFile(JournalFile file) async {
    if (!_isInitialized) {
      throw Exception('RAG service not initialized');
    }

    _setLoading(true);
    _clearError();

    try {
      await _ragService.indexFile(file);
      await _loadStats();
    } catch (e) {
      _setError('File indexing error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Update file index
  Future<void> updateFileIndex(JournalFile file) async {
    if (!_isInitialized) {
      throw Exception('RAG service not initialized');
    }

    _setLoading(true);
    _clearError();

    try {
      await _ragService.updateFileIndex(file);
      await _loadStats();
    } catch (e) {
      _setError('File index update error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Remove file from index
  Future<void> removeFileFromIndex(String fileId) async {
    if (!_isInitialized) {
      throw Exception('RAG service not initialized');
    }

    _setLoading(true);
    _clearError();

    try {
      await _ragService.removeFileFromIndex(fileId);
      await _loadStats();
    } catch (e) {
      _setError('File removal error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load RAG statistics
  Future<void> _loadStats() async {
    try {
      _stats = await _ragService.getStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading RAG stats: $e');
    }
  }

  /// Clear conversation history
  void clearConversationHistory() {
    _conversationHistory.clear();
    notifyListeners();
  }

  /// Get conversation context for display
  String getConversationContext() {
    if (_conversationHistory.isEmpty) return '';
    
    return _conversationHistory.join('\n\n');
  }

  /// Common query suggestions
  List<String> getQuerySuggestions() {
    return [
      'What are the main themes in my recent journal entries?',
      'How has my mood changed over the past week?',
      'What patterns do you notice in my writing?',
      'What topics have I been thinking about most?',
      'Can you summarize my thoughts on work/relationships/goals?',
      'What insights can you share about my personal growth?',
      'What writing prompts would be good for me today?',
      'How do my current entries compare to past ones?',
    ];
  }

  /// Ask follow-up questions
  Future<RAGResult?> askFollowUp(String question) async {
    if (_lastResult == null) {
      return await query(question);
    }

    // Build context from previous result
    final contextualQuestion = '''
    Based on our previous conversation:
    Previous Question: ${_lastResult!.query}
    Previous Answer: ${_lastResult!.answer}
    
    Follow-up Question: $question
    ''';

    return await query(contextualQuestion);
  }

  /// Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    debugPrint('RAG Provider Error: $error');
    notifyListeners();
  }

  void _clearError() {
    _error = '';
    notifyListeners();
  }

  /// Cleanup
  @override
  void dispose() {
    _ragService.dispose();
    super.dispose();
  }
}