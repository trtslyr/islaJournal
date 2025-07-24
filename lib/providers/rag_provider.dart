import 'package:flutter/foundation.dart';
import '../services/rag_service.dart';
import '../services/document_import_service.dart';
import '../models/journal_file.dart';

class RAGProvider with ChangeNotifier {
  final RAGService _ragService = RAGService();
  final DocumentImportService _importService = DocumentImportService();
  
  bool _isInitialized = false;
  bool _isIndexing = false;
  int _indexingProgress = 0;
  int _totalToIndex = 0;
  String _indexingStatus = '';
  
  List<ImportedDocument> _importedDocuments = [];
  Map<String, dynamic> _ragStats = {};
  
  bool _isGeneratingResponse = false;
  String _lastResponse = '';
  List<String> _contextualPrompts = [];
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isIndexing => _isIndexing;
  int get indexingProgress => _indexingProgress;
  int get totalToIndex => _totalToIndex;
  String get indexingStatus => _indexingStatus;
  double get indexingPercentage => _totalToIndex > 0 ? (_indexingProgress / _totalToIndex) * 100 : 0;
  
  List<ImportedDocument> get importedDocuments => _importedDocuments;
  Map<String, dynamic> get ragStats => _ragStats;
  
  bool get isGeneratingResponse => _isGeneratingResponse;
  String get lastResponse => _lastResponse;
  List<String> get contextualPrompts => _contextualPrompts;

  // Initialize the RAG system
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('RAGProvider: Starting initialization...');
      
      await _ragService.initialize();
      print('RAGProvider: ✅ RAG service initialized');
      
      await _refreshImportedDocuments();
      print('RAGProvider: ✅ Imported documents loaded');
      
      await _refreshRAGStats();
      print('RAGProvider: ✅ RAG stats loaded');
      
      _isInitialized = true;
      notifyListeners();
      
      print('RAGProvider: ✅ Fully initialized');
      
      // Start background indexing if needed (non-blocking)
      _startBackgroundIndexing();
    } catch (e) {
      print('RAGProvider: ❌ Initialization error: $e');
      // Set error state but don't throw - allow UI to show error
      _indexingStatus = 'Initialization failed: $e';
      notifyListeners();
      // Don't rethrow - let the app continue to work
    }
  }

  // Start background indexing of journal entries
  Future<void> _startBackgroundIndexing() async {
    if (_isIndexing || !_isInitialized) return;
    
    try {
      print('RAGProvider: Starting background indexing...');
      _isIndexing = true;
      _indexingStatus = 'Starting indexing...';
      notifyListeners();
      
      await _ragService.indexAllJournalEntries(
        progressCallback: (current, total) {
          _indexingProgress = current;
          _totalToIndex = total;
          _indexingStatus = 'Indexing journal entries... ($current/$total)';
          notifyListeners();
        },
      );
      
      _indexingStatus = 'Indexing completed successfully';
      print('RAGProvider: ✅ Background indexing completed');
      await _refreshRAGStats();
    } catch (e) {
      _indexingStatus = 'Indexing failed: $e';
      print('RAGProvider: ⚠️ Background indexing failed (non-critical): $e');
      // Don't rethrow - this is a background operation
    } finally {
      _isIndexing = false;
      notifyListeners();
    }
  }

  // Manually trigger full re-indexing
  Future<void> reindexAllContent() async {
    if (_isIndexing) return;
    
    try {
      _isIndexing = true;
      _indexingProgress = 0;
      _totalToIndex = 0;
      _indexingStatus = 'Re-indexing all content...';
      notifyListeners();
      
      await _ragService.reindexAllContent(
        progressCallback: (current, total) {
          _indexingProgress = current;
          _totalToIndex = total;
          _indexingStatus = 'Re-indexing... ($current/$total)';
          notifyListeners();
        },
      );
      
      _indexingStatus = 'Re-indexing completed';
      await _refreshRAGStats();
    } catch (e) {
      _indexingStatus = 'Re-indexing failed: $e';
      debugPrint('Error during re-indexing: $e');
    } finally {
      _isIndexing = false;
      notifyListeners();
    }
  }

  // Index a specific journal entry
  Future<void> indexJournalEntry(JournalFile journalFile) async {
    if (!_isInitialized) await initialize();
    
    try {
      await _ragService.indexJournalEntry(journalFile);
      await _refreshRAGStats();
    } catch (e) {
      debugPrint('Error indexing journal entry: $e');
    }
  }

  // Import documents
  Future<List<ImportedDocument>> importDocuments({
    List<String>? allowedExtensions,
    bool allowMultiple = true,
  }) async {
    if (!_isInitialized) await initialize();
    
    try {
      final importedDocs = await _importService.importDocuments(
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
      );
      
      await _refreshImportedDocuments();
      await _refreshRAGStats();
      
      return importedDocs;
    } catch (e) {
      debugPrint('Error importing documents: $e');
      rethrow;
    }
  }

  // Generate contextual AI response
  Future<String> generateContextualResponse(
    String query, {
    String? systemPrompt,
    int maxTokens = 512,
    double temperature = 0.7,
  }) async {
    if (!_isInitialized) await initialize();
    
    try {
      _isGeneratingResponse = true;
      _lastResponse = '';
      notifyListeners();
      
      final response = await _ragService.generateContextualResponse(
        query,
        systemPrompt: systemPrompt,
        maxTokens: maxTokens,
        temperature: temperature,
      );
      
      _lastResponse = response;
      return response;
    } catch (e) {
      debugPrint('Error generating contextual response: $e');
      _lastResponse = 'Error generating response: $e';
      rethrow;
    } finally {
      _isGeneratingResponse = false;
      notifyListeners();
    }
  }

  // Analyze writing patterns
  Future<String> analyzeWritingPatterns() async {
    if (!_isInitialized) await initialize();
    
    try {
      _isGeneratingResponse = true;
      notifyListeners();
      
      final analysis = await _ragService.analyzeWritingPatterns();
      _lastResponse = analysis;
      return analysis;
    } catch (e) {
      debugPrint('Error analyzing writing patterns: $e');
      _lastResponse = 'Error analyzing patterns: $e';
      rethrow;
    } finally {
      _isGeneratingResponse = false;
      notifyListeners();
    }
  }

  // Get contextual writing prompts
  Future<List<String>> getContextualWritingPrompts(String currentContent) async {
    if (!_isInitialized) await initialize();
    
    try {
      final prompts = await _ragService.getContextualWritingPrompts(currentContent);
      _contextualPrompts = prompts;
      notifyListeners();
      return prompts;
    } catch (e) {
      debugPrint('Error getting contextual writing prompts: $e');
      return [];
    }
  }

  // Search across all content
  Future<List<RetrievalResult>> searchAllContent(
    String query, {
    int maxResults = 10,
    double minSimilarity = 0.2,
  }) async {
    if (!_isInitialized) await initialize();
    
    try {
      return await _ragService.retrieveRelevantContent(
        query,
        maxResults: maxResults,
        minSimilarity: minSimilarity,
      );
    } catch (e) {
      debugPrint('Error searching content: $e');
      return [];
    }
  }

  // Delete imported document
  Future<void> deleteImportedDocument(String documentId) async {
    try {
      await _importService.deleteImportedDocument(documentId);
      await _refreshImportedDocuments();
      await _refreshRAGStats();
    } catch (e) {
      debugPrint('Error deleting imported document: $e');
      rethrow;
    }
  }

  // Get document content
  Future<List<ImportedContent>> getDocumentContent(String documentId) async {
    try {
      return await _importService.getDocumentContent(documentId);
    } catch (e) {
      debugPrint('Error getting document content: $e');
      return [];
    }
  }

  // Refresh imported documents list
  Future<void> _refreshImportedDocuments() async {
    try {
      _importedDocuments = await _importService.getImportedDocuments();
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing imported documents: $e');
    }
  }

  // Refresh RAG statistics
  Future<void> _refreshRAGStats() async {
    try {
      _ragStats = await _ragService.getRAGStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing RAG stats: $e');
    }
  }

  // Check if content is being indexed
  bool get hasIndexedContent {
    final stats = _ragStats;
    return (stats['totalIndexedItems'] as int? ?? 0) > 0;
  }

  // Get indexing summary
  String get indexingSummary {
    final stats = _ragStats;
    final journalEntries = stats['journalEntriesIndexed'] as int? ?? 0;
    final importedContent = stats['importedContentIndexed'] as int? ?? 0;
    final total = journalEntries + importedContent;
    
    if (total == 0) return 'No content indexed';
    
    return '$total items indexed ($journalEntries journal entries, $importedContent imported chunks)';
  }

  // Get vocabulary size
  int get vocabularySize {
    final vocabStats = _ragStats['vocabularyStats'] as Map<String, dynamic>? ?? {};
    return vocabStats['vocabularySize'] as int? ?? 0;
  }

  // Clear corrupted embeddings
  Future<void> clearCorruptedEmbeddings() async {
    if (!_isInitialized) await initialize();
    
    try {
      await _ragService.clearCorruptedEmbeddings();
      await _refreshRAGStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing corrupted embeddings: $e');
      rethrow;
    }
  }

  // Debug database status
  Future<Map<String, dynamic>> debugDatabaseStatus() async {
    if (!_isInitialized) await initialize();
    
    try {
      return await _ragService.debugDatabaseStatus();
    } catch (e) {
      debugPrint('Error debugging database status: $e');
      return {'error': e.toString()};
    }
  }

  @override
  void dispose() {
    _ragService.dispose();
    super.dispose();
  }
} 