import 'package:flutter/foundation.dart';
import 'ai_service.dart';
import 'embedding_service.dart';
import 'database_service.dart';
import '../models/journal_file.dart';

/// Result from RAG query
class RAGResult {
  final String answer;
  final List<RAGContext> contexts;
  final double confidence;
  final String query;

  RAGResult({
    required this.answer,
    required this.contexts,
    required this.confidence,
    required this.query,
  });
}

/// Context information used for RAG
class RAGContext {
  final String text;
  final String fileId;
  final String fileName;
  final double similarity;
  final DateTime createdAt;

  RAGContext({
    required this.text,
    required this.fileId,
    required this.fileName,
    required this.similarity,
    required this.createdAt,
  });
}

/// Service for Retrieval-Augmented Generation (RAG)
class RAGService {
  static final RAGService _instance = RAGService._internal();
  factory RAGService() => _instance;
  RAGService._internal();

  final AIService _aiService = AIService();
  final EmbeddingService _embeddingService = EmbeddingService();
  final DatabaseService _dbService = DatabaseService();

  bool _isInitialized = false;

  /// Initialize the RAG service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize dependencies
      await _aiService.initialize();
      await _embeddingService.initialize();
      
      _isInitialized = true;
      debugPrint('RAG Service initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize RAG Service: $e');
      throw Exception('Failed to initialize RAG service: $e');
    }
  }

  /// Query the RAG system with a question
  Future<RAGResult> query(
    String question, {
    String? fileId,
    int maxContexts = 5,
    double similarityThreshold = 0.3,
  }) async {
    if (!_isInitialized) {
      throw Exception('RAG Service not initialized');
    }

    try {
      // Step 1: Find relevant contexts using semantic search
      final searchResults = await _embeddingService.semanticSearch(
        question,
        limit: maxContexts,
        threshold: similarityThreshold,
        fileId: fileId,
      );

      // Step 2: Build contexts from search results
      final contexts = <RAGContext>[];
      for (final result in searchResults) {
        final metadata = result.embedding.metadata;
        contexts.add(RAGContext(
          text: result.embedding.text,
          fileId: metadata['fileId'] as String,
          fileName: metadata['fileName'] as String,
          similarity: result.similarity,
          createdAt: result.embedding.createdAt,
        ));
      }

      // Step 3: Generate answer using AI with context
      final answer = await _generateAnswerWithContext(question, contexts);

      // Step 4: Calculate confidence based on similarity scores
      final confidence = _calculateConfidence(contexts);

      return RAGResult(
        answer: answer,
        contexts: contexts,
        confidence: confidence,
        query: question,
      );
    } catch (e) {
      debugPrint('Error in RAG query: $e');
      throw Exception('Failed to process RAG query: $e');
    }
  }

  /// Generate an answer using AI with provided context
  Future<String> _generateAnswerWithContext(
    String question,
    List<RAGContext> contexts,
  ) async {
    if (contexts.isEmpty) {
      // No context found, provide a general response
      return await _aiService.generateText(
        _buildNoContextPrompt(question),
        options: {
          'temperature': 0.7,
          'max_tokens': 500,
        },
      );
    }

    // Build prompt with context
    final prompt = _buildContextualPrompt(question, contexts);
    
    return await _aiService.generateText(
      prompt,
      options: {
        'temperature': 0.6,
        'max_tokens': 800,
      },
    );
  }

  /// Build prompt with context for AI generation
  String _buildContextualPrompt(String question, List<RAGContext> contexts) {
    final contextTexts = contexts.map((c) => 
      "From ${c.fileName}:\n${c.text}\n"
    ).join('\n---\n');

    return '''You are an AI assistant for Isla Journal, a private journaling app. 
You help users understand and explore their journal entries. 
Answer the user's question based on the provided context from their journal.

Context from journal entries:
---
$contextTexts
---

User's question: $question

Please provide a thoughtful, personal response based on the journal content. 
Be empathetic and insightful. If the context doesn't fully answer the question, 
acknowledge this and provide what insights you can from the available information.

Answer:''';
  }

  /// Build prompt for when no context is available
  String _buildNoContextPrompt(String question) {
    return '''You are an AI assistant for Isla Journal, a private journaling app.
The user asked: "$question"

I couldn't find relevant information in your journal entries to answer this specific question. 
However, I can provide some general guidance or suggest how you might explore this topic in your journaling.

Please provide a helpful response that acknowledges the lack of specific context while still being useful.

Answer:''';
  }

  /// Calculate confidence score based on context similarities
  double _calculateConfidence(List<RAGContext> contexts) {
    if (contexts.isEmpty) return 0.0;
    
    // Average similarity score as confidence
    final avgSimilarity = contexts
        .map((c) => c.similarity)
        .reduce((a, b) => a + b) / contexts.length;
    
    // Boost confidence if we have multiple high-quality contexts
    final highQualityContexts = contexts.where((c) => c.similarity > 0.7).length;
    final qualityBoost = highQualityContexts * 0.1;
    
    return (avgSimilarity + qualityBoost).clamp(0.0, 1.0);
  }

  /// Get insights about a specific journal file
  Future<RAGResult> getFileInsights(String fileId) async {
    if (!_isInitialized) {
      throw Exception('RAG Service not initialized');
    }

    try {
      // Get the file content
      final file = await _dbService.getFile(fileId);
      if (file == null) {
        throw Exception('File not found');
      }

      // Generate insights using AI
      final insights = await _aiService.generateText(
        _buildInsightsPrompt(file),
        options: {
          'temperature': 0.7,
          'max_tokens': 600,
        },
      );

      return RAGResult(
        answer: insights,
        contexts: [
          RAGContext(
            text: file.content,
            fileId: file.id,
            fileName: file.name,
            similarity: 1.0,
            createdAt: file.createdAt,
          ),
        ],
        confidence: 0.9,
        query: 'Insights for ${file.name}',
      );
    } catch (e) {
      debugPrint('Error getting file insights: $e');
      throw Exception('Failed to get file insights: $e');
    }
  }

  /// Build prompt for generating insights about a journal entry
  String _buildInsightsPrompt(JournalFile file) {
    return '''You are an AI assistant for Isla Journal. Analyze this journal entry and provide thoughtful insights.

Journal Entry: "${file.name}"
Created: ${file.createdAt}
Content:
---
${file.content}
---

Please provide insights about:
1. Main themes and topics
2. Emotional tone and mood
3. Notable patterns or recurring thoughts
4. Personal growth or reflection points
5. Suggested tags or categories

Be empathetic and constructive in your analysis. Focus on helping the user understand their thoughts and feelings better.

Insights:''';
  }

  /// Generate writing prompts based on journal history
  Future<List<String>> generateWritingPrompts({
    int count = 3,
    String? theme,
  }) async {
    if (!_isInitialized) {
      throw Exception('RAG Service not initialized');
    }

    try {
      // Get recent journal entries for context
      final recentFiles = await _dbService.getRecentFiles(limit: 5);
      
      final prompt = _buildWritingPromptsPrompt(recentFiles, theme, count);
      
      final response = await _aiService.generateText(
        prompt,
        options: {
          'temperature': 0.8,
          'max_tokens': 400,
        },
      );

      // Parse the response into individual prompts
      return _parseWritingPrompts(response);
    } catch (e) {
      debugPrint('Error generating writing prompts: $e');
      throw Exception('Failed to generate writing prompts: $e');
    }
  }

  /// Build prompt for generating writing prompts
  String _buildWritingPromptsPrompt(
    List<JournalFile> recentFiles,
    String? theme,
    int count,
  ) {
    final contextText = recentFiles.isEmpty
        ? "No recent journal entries available."
        : recentFiles.map((f) => 
            "Entry: ${f.name}\n${f.content.substring(0, 100)}..."
          ).join('\n\n');

    final themeText = theme != null ? "Focus on the theme: $theme" : "";

    return '''You are an AI assistant for Isla Journal. Generate $count thoughtful writing prompts 
based on the user's recent journal entries. ${themeText}

Recent journal context:
---
$contextText
---

Generate $count writing prompts that:
1. Are personally relevant based on the journal history
2. Encourage self-reflection and growth
3. Are specific and engaging
4. Build on themes from recent entries

Format each prompt as a numbered list item (1., 2., 3., etc.).

Writing Prompts:''';
  }

  /// Parse writing prompts from AI response
  List<String> _parseWritingPrompts(String response) {
    final lines = response.split('\n');
    final prompts = <String>[];
    
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && 
          (trimmed.startsWith(RegExp(r'\d+\.')) || 
           trimmed.startsWith('•') || 
           trimmed.startsWith('-'))) {
        // Remove numbering and bullet points
        final prompt = trimmed.replaceFirst(RegExp(r'^\d+\.\s*'), '')
                             .replaceFirst(RegExp(r'^[•-]\s*'), '')
                             .trim();
        if (prompt.isNotEmpty) {
          prompts.add(prompt);
        }
      }
    }
    
    return prompts;
  }

  /// Index a journal file for RAG
  Future<void> indexFile(JournalFile file) async {
    if (!_isInitialized) {
      throw Exception('RAG Service not initialized');
    }

    try {
      await _embeddingService.storeFileEmbeddings(
        file.id,
        file.name,
        file.content,
      );
      debugPrint('Indexed file: ${file.name}');
    } catch (e) {
      debugPrint('Error indexing file: $e');
      throw Exception('Failed to index file: $e');
    }
  }

  /// Update index for a journal file
  Future<void> updateFileIndex(JournalFile file) async {
    if (!_isInitialized) {
      throw Exception('RAG Service not initialized');
    }

    try {
      await _embeddingService.updateFileEmbeddings(
        file.id,
        file.name,
        file.content,
      );
      debugPrint('Updated index for file: ${file.name}');
    } catch (e) {
      debugPrint('Error updating file index: $e');
      throw Exception('Failed to update file index: $e');
    }
  }

  /// Remove file from index
  Future<void> removeFileFromIndex(String fileId) async {
    if (!_isInitialized) {
      throw Exception('RAG Service not initialized');
    }

    try {
      await _embeddingService.deleteFileEmbeddings(fileId);
      debugPrint('Removed file from index: $fileId');
    } catch (e) {
      debugPrint('Error removing file from index: $e');
      throw Exception('Failed to remove file from index: $e');
    }
  }

  /// Get RAG system statistics
  Future<RAGStats> getStats() async {
    if (!_isInitialized) {
      throw Exception('RAG Service not initialized');
    }

    final embeddingStats = await _embeddingService.getStats();
    
    return RAGStats(
      totalIndexedFiles: embeddingStats.uniqueFiles,
      totalEmbeddings: embeddingStats.totalEmbeddings,
      indexSize: embeddingStats.totalSize,
      isAIAvailable: _aiService.isModelLoaded,
    );
  }

  /// Cleanup resources
  Future<void> dispose() async {
    await _embeddingService.dispose();
    await _aiService.dispose();
    _isInitialized = false;
  }
}

/// Statistics about the RAG system
class RAGStats {
  final int totalIndexedFiles;
  final int totalEmbeddings;
  final int indexSize;
  final bool isAIAvailable;

  RAGStats({
    required this.totalIndexedFiles,
    required this.totalEmbeddings,
    required this.indexSize,
    required this.isAIAvailable,
  });
}