import 'dart:async';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/journal_file.dart';
import 'database_service.dart';
import 'embedding_service.dart';
import 'document_import_service.dart';
import 'ai_service.dart';

class RetrievalResult {
  final String content;
  final double similarity;
  final String sourceId;
  final String sourceType; // 'journal_entry' or 'imported_document'
  final Map<String, dynamic> metadata;

  RetrievalResult({
    required this.content,
    required this.similarity,
    required this.sourceId,
    required this.sourceType,
    required this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'similarity': similarity,
      'sourceId': sourceId,
      'sourceType': sourceType,
      'metadata': metadata,
    };
  }

  factory RetrievalResult.fromMap(Map<String, dynamic> map) {
    return RetrievalResult(
      content: map['content'] as String,
      similarity: map['similarity'] as double,
      sourceId: map['sourceId'] as String,
      sourceType: map['sourceType'] as String,
      metadata: Map<String, dynamic>.from(map['metadata']),
    );
  }
}

class RAGService {
  static final RAGService _instance = RAGService._internal();
  factory RAGService() => _instance;
  RAGService._internal();

  final DatabaseService _dbService = DatabaseService();
  final EmbeddingService _embeddingService = EmbeddingService();
  final DocumentImportService _importService = DocumentImportService();
  final AIService _aiService = AIService();

  bool _isInitialized = false;
  bool _isIndexing = false;
  
  // RAG Configuration
  static const int maxRetrievedDocuments = 5;
  static const double similarityThreshold = 0.3;
  static const int maxContextLength = 2000; // characters

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _embeddingService.initialize();
      await _importService.initialize();
      await _aiService.initialize();
      
      _isInitialized = true;
      print('RAG Service initialized successfully');
    } catch (e) {
      print('Error initializing RAG service: $e');
      throw Exception('Failed to initialize RAG service: $e');
    }
  }

  // Generate embedding for a journal entry and store it
  Future<void> indexJournalEntry(JournalFile journalFile) async {
    if (!_isInitialized) await initialize();
    
    try {
      final embedding = await _embeddingService.generateEmbedding(
        journalFile.content,
        journalFile.id,
      );
      
      await _storeEmbedding(
        journalFile.id,
        embedding,
        journalFile.content,
        'journal_entry',
      );
      
      print('Indexed journal entry: ${journalFile.name}');
    } catch (e) {
      print('Error indexing journal entry ${journalFile.id}: $e');
    }
  }

  // Batch index all journal entries
  Future<void> indexAllJournalEntries({
    Function(int current, int total)? progressCallback,
  }) async {
    if (!_isInitialized) await initialize();
    if (_isIndexing) return;
    
    _isIndexing = true;
    
    try {
      final db = await _dbService.database;
      
      // Get all journal files
      final files = await _dbService.getFiles();
      
      print('Starting to index ${files.length} journal entries...');
      
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        
        // Check if already indexed
        final existing = await db.query(
          'file_embeddings',
          where: 'file_id = ? AND embedding_version = ?',
          whereArgs: [file.id, 1],
        );
        
        if (existing.isEmpty) {
          // Load full content and index
          final fullFile = await _dbService.getFile(file.id);
          if (fullFile != null) {
            await indexJournalEntry(fullFile);
          }
        }
        
        progressCallback?.call(i + 1, files.length);
      }
      
      print('Finished indexing journal entries');
    } catch (e) {
      print('Error during batch indexing: $e');
      throw Exception('Failed to index journal entries: $e');
    } finally {
      _isIndexing = false;
    }
  }

  // Store embedding in database
  Future<void> _storeEmbedding(
    String fileId,
    List<double> embedding,
    String content,
    String sourceType,
  ) async {
    final db = await _dbService.database;
    
    // Convert embedding to bytes for storage
    final embeddingBytes = Float64List.fromList(embedding).buffer.asUint8List();
    
    await db.insert(
      'file_embeddings',
      {
        'id': const Uuid().v4(),
        'file_id': fileId,
        'embedding': embeddingBytes,
        'embedding_version': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'chunk_index': 0,
        'chunk_text': content.substring(0, content.length.clamp(0, 500)),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Retrieve relevant content based on query
  Future<List<RetrievalResult>> retrieveRelevantContent(
    String query, {
    int maxResults = maxRetrievedDocuments,
    double minSimilarity = similarityThreshold,
  }) async {
    if (!_isInitialized) await initialize();
    
    try {
      print('RAG: Retrieving relevant content for query: "$query"');
      
      // Generate embedding for the query
      final queryEmbedding = await _embeddingService.generateQueryEmbedding(query);
      print('RAG: Generated query embedding with ${queryEmbedding.length} dimensions');
      
      // Get all stored embeddings
      final results = <RetrievalResult>[];
      
      // Search journal entries
      print('RAG: Searching journal entries...');
      final journalResults = await _searchJournalEntries(
        queryEmbedding,
        maxResults: maxResults,
        minSimilarity: minSimilarity,
      );
      print('RAG: Found ${journalResults.length} relevant journal entries');
      results.addAll(journalResults);
      
      // Search imported documents
      print('RAG: Searching imported documents...');
      final importedResults = await _searchImportedDocuments(
        queryEmbedding,
        maxResults: maxResults,
        minSimilarity: minSimilarity,
      );
      print('RAG: Found ${importedResults.length} relevant imported documents');
      results.addAll(importedResults);
      
      // Sort by similarity and take top results
      results.sort((a, b) => b.similarity.compareTo(a.similarity));
      
      final finalResults = results.take(maxResults).toList();
      print('RAG: Returning ${finalResults.length} total results');
      
      return finalResults;
    } catch (e) {
      print('Error retrieving relevant content: $e');
      return [];
    }
  }

  // Search journal entries
  Future<List<RetrievalResult>> _searchJournalEntries(
    List<double> queryEmbedding, {
    required int maxResults,
    required double minSimilarity,
  }) async {
    final db = await _dbService.database;
    final results = <RetrievalResult>[];
    
    // Get all journal entry embeddings
    final embeddings = await db.rawQuery('''
      SELECT fe.*, f.name, f.file_path, f.created_at, f.updated_at
      FROM file_embeddings fe
      JOIN files f ON fe.file_id = f.id
      WHERE fe.embedding_version = 1
    ''');
    
    print('RAG: Found ${embeddings.length} journal embeddings in database');
    
    for (final row in embeddings) {
      try {
        // Convert bytes back to embedding
        final embeddingBytes = row['embedding'] as Uint8List;
        final embedding = Float64List.view(embeddingBytes.buffer).toList();
        
        // Validate embedding dimension
        if (embedding.length != queryEmbedding.length) {
          print('Skipping corrupted embedding: expected ${queryEmbedding.length}, got ${embedding.length}');
          continue;
        }
        
        // Calculate similarity
        final similarity = EmbeddingService.cosineSimilarity(
          queryEmbedding,
          embedding,
        );
        
        print('RAG: Journal entry "${row['name']}" similarity: ${similarity.toStringAsFixed(3)}');
        
        if (similarity >= minSimilarity) {
          results.add(RetrievalResult(
            content: row['chunk_text'] as String,
            similarity: similarity,
            sourceId: row['file_id'] as String,
            sourceType: 'journal_entry',
            metadata: {
              'filename': row['name'] as String,
              'filePath': row['file_path'] as String,
              'createdAt': row['created_at'] as String,
              'updatedAt': row['updated_at'] as String,
            },
          ));
        }
      } catch (e) {
        print('Error processing journal embedding: $e');
        // Skip corrupted embeddings
        continue;
      }
    }
    
    print('RAG: Returning ${results.length} journal results with similarity >= $minSimilarity');
    return results;
  }

  // Search imported documents
  Future<List<RetrievalResult>> _searchImportedDocuments(
    List<double> queryEmbedding, {
    required int maxResults,
    required double minSimilarity,
  }) async {
    final db = await _dbService.database;
    final results = <RetrievalResult>[];
    
    // Get all imported document embeddings
    final embeddings = await db.rawQuery('''
      SELECT fe.*, ic.content, ic.page_number, ic.chunk_index, id.original_filename
      FROM file_embeddings fe
      JOIN imported_content ic ON fe.file_id = ic.id
      JOIN imported_documents id ON ic.document_id = id.id
      WHERE fe.embedding_version = 1
    ''');
    
    for (final row in embeddings) {
      try {
        // Convert bytes back to embedding
        final embeddingBytes = row['embedding'] as Uint8List;
        final embedding = Float64List.view(embeddingBytes.buffer).toList();
        
        // Validate embedding dimension
        if (embedding.length != queryEmbedding.length) {
          print('Skipping corrupted imported embedding: expected ${queryEmbedding.length}, got ${embedding.length}');
          continue;
        }
        
        // Calculate similarity
        final similarity = EmbeddingService.cosineSimilarity(
          queryEmbedding,
          embedding,
        );
        
        if (similarity >= minSimilarity) {
          results.add(RetrievalResult(
            content: row['content'] as String,
            similarity: similarity,
            sourceId: row['file_id'] as String,
            sourceType: 'imported_document',
            metadata: {
              'filename': row['original_filename'] as String,
              'pageNumber': row['page_number'] as int?,
              'chunkIndex': row['chunk_index'] as int,
            },
          ));
        }
      } catch (e) {
        print('Error processing imported document embedding: $e');
        // Skip corrupted embeddings
        continue;
      }
    }
    
    return results;
  }

  // Generate AI response with RAG context
  Future<String> generateContextualResponse(
    String query, {
    String? systemPrompt,
    int maxTokens = 512,
    double temperature = 0.7,
  }) async {
    if (!_isInitialized) await initialize();
    
    try {
      print('RAG: Generating contextual response for query: "$query"');
      
      // Retrieve relevant content
      final relevantContent = await retrieveRelevantContent(query);
      print('RAG: Retrieved ${relevantContent.length} relevant items');
      
      // Build context from retrieved content
      final context = _buildContext(relevantContent);
      print('RAG: Built context of ${context.length} characters');
      
      if (context.isEmpty) {
        print('RAG: No context available, falling back to basic AI response');
        return await _aiService.generateText(
          query,
          systemPrompt: systemPrompt,
          maxTokens: maxTokens,
          temperature: temperature,
        );
      }
      
      // Create enhanced system prompt
      final enhancedSystemPrompt = _buildEnhancedSystemPrompt(
        systemPrompt ?? 'You are a helpful AI assistant that analyzes journal entries.',
        context,
      );
      
      print('RAG: Using enhanced system prompt with context');
      
      // Generate response with context
      final response = await _aiService.generateText(
        query,
        systemPrompt: enhancedSystemPrompt,
        maxTokens: maxTokens,
        temperature: temperature,
      );
      
      return response;
    } catch (e) {
      print('Error generating contextual response: $e');
      // Fallback to basic AI response
      return await _aiService.generateText(
        query,
        systemPrompt: systemPrompt,
        maxTokens: maxTokens,
        temperature: temperature,
      );
    }
  }

  // Build context from retrieved content
  String _buildContext(List<RetrievalResult> results) {
    if (results.isEmpty) return '';
    
    final contextParts = <String>[];
    int totalLength = 0;
    
    for (final result in results) {
      final sourceInfo = result.sourceType == 'journal_entry' 
          ? 'Journal Entry: ${result.metadata['filename']}'
          : 'Imported Document: ${result.metadata['filename']}';
      
      final contextPart = '''
$sourceInfo (Relevance: ${(result.similarity * 100).toStringAsFixed(1)}%)
${result.content.trim()}
''';
      
      if (totalLength + contextPart.length > maxContextLength) {
        break;
      }
      
      contextParts.add(contextPart);
      totalLength += contextPart.length;
    }
    
    return contextParts.join('\n---\n');
  }

  // Build enhanced system prompt with context
  String _buildEnhancedSystemPrompt(String basePrompt, String context) {
    if (context.isEmpty) return basePrompt;
    
    return '''$basePrompt

You have access to the user's journal entries and imported documents. Use this context to provide more personalized and relevant responses:

CONTEXT:
$context

When responding:
1. Reference specific entries when relevant
2. Identify patterns across the user's writing
3. Provide insights based on their personal history
4. Be empathetic and understanding of their journey
5. Maintain privacy and confidentiality

''';
  }

  // Analyze writing patterns across all content
  Future<String> analyzeWritingPatterns() async {
    if (!_isInitialized) await initialize();
    
    try {
      const query = 'What are the main themes, emotions, and patterns in my writing?';
      
      const systemPrompt = '''
You are an expert journal analyst. Analyze the provided journal entries and imported documents to identify:

1. Main themes and topics
2. Emotional patterns and mood trends
3. Writing style and voice evolution
4. Recurring concerns or interests
5. Personal growth indicators
6. Significant life events or transitions

Provide a comprehensive but concise analysis that helps the user understand their journaling patterns and personal development.
''';
      
      return await generateContextualResponse(
        query,
        systemPrompt: systemPrompt,
        maxTokens: 800,
        temperature: 0.5,
      );
    } catch (e) {
      print('Error analyzing writing patterns: $e');
      return 'Unable to analyze writing patterns at this time.';
    }
  }

  // Get contextual writing suggestions
  Future<List<String>> getContextualWritingPrompts(String currentContent) async {
    if (!_isInitialized) await initialize();
    
    try {
      const query = 'Generate writing prompts based on my journal history and current thoughts';
      
      const systemPrompt = '''
You are a creative writing coach. Based on the user's journal history and current writing, generate 3-5 personalized writing prompts that:

1. Build on their existing themes and interests
2. Encourage deeper reflection on current topics
3. Help them explore new perspectives
4. Connect past experiences to present thoughts
5. Promote personal growth and self-discovery

Make each prompt engaging and thought-provoking.
''';
      
      final response = await generateContextualResponse(
        '$query\n\nCurrent writing: $currentContent',
        systemPrompt: systemPrompt,
        maxTokens: 300,
        temperature: 0.8,
      );
      
      // Parse response into individual prompts
      return response
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.replaceAll(RegExp(r'^\d+\.\s*'), '').trim())
          .where((line) => line.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error generating contextual writing prompts: $e');
      return [
        'What would you like to explore further from your recent thoughts?',
        'How do you feel about the patterns you\'ve noticed in your writing?',
        'What themes from your past entries resonate with you today?',
      ];
    }
  }

  // Get RAG system statistics
  Future<Map<String, dynamic>> getRAGStats() async {
    final db = await _dbService.database;
    
    final journalEmbeddingsCount = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM file_embeddings fe 
      JOIN files f ON fe.file_id = f.id
    ''');
    
    final importedEmbeddingsCount = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM file_embeddings fe 
      JOIN imported_content ic ON fe.file_id = ic.id
    ''');
    
    final vocabStats = _embeddingService.getVocabularyStats();
    final importStats = await _importService.getImportStats();
    
    return {
      'journalEntriesIndexed': journalEmbeddingsCount.first['count'] as int,
      'importedContentIndexed': importedEmbeddingsCount.first['count'] as int,
      'totalIndexedItems': (journalEmbeddingsCount.first['count'] as int) + 
                          (importedEmbeddingsCount.first['count'] as int),
      'vocabularyStats': vocabStats,
      'importStats': importStats,
      'isInitialized': _isInitialized,
      'isIndexing': _isIndexing,
    };
  }

  // Clear corrupted embeddings from database
  Future<void> clearCorruptedEmbeddings() async {
    final db = await _dbService.database;
    
    try {
      // Delete all existing embeddings
      await db.delete('file_embeddings');
      print('Cleared all corrupted embeddings from database');
    } catch (e) {
      print('Error clearing corrupted embeddings: $e');
    }
  }

  // Re-index all content (useful after updates)
  Future<void> reindexAllContent({
    Function(int current, int total)? progressCallback,
  }) async {
    if (!_isInitialized) await initialize();
    
    try {
      // Clear corrupted embeddings first
      await clearCorruptedEmbeddings();
      
      // Re-index journal entries
      await indexAllJournalEntries(progressCallback: progressCallback);
      
      // Re-index imported documents (they should already be processed)
      print('RAG re-indexing completed');
    } catch (e) {
      print('Error during re-indexing: $e');
      throw Exception('Failed to re-index content: $e');
    }
  }

  // Debug method to check what's in the database
  Future<Map<String, dynamic>> debugDatabaseStatus() async {
    final db = await _dbService.database;
    
    try {
      // Check journal files
      final files = await db.query('files');
      print('RAG DEBUG: Found ${files.length} journal files');
      
      // Check embeddings
      final embeddings = await db.query('file_embeddings');
      print('RAG DEBUG: Found ${embeddings.length} embeddings');
      
      // Check specific embeddings with file names
      final embeddingsWithFiles = await db.rawQuery('''
        SELECT fe.id, fe.file_id, f.name, f.created_at, 
               LENGTH(fe.embedding) as embedding_size,
               LENGTH(fe.chunk_text) as chunk_text_size
        FROM file_embeddings fe
        JOIN files f ON fe.file_id = f.id
        ORDER BY f.created_at DESC
      ''');
      
      print('RAG DEBUG: Embeddings details:');
      for (final row in embeddingsWithFiles) {
        print('  - File: ${row['name']}, Embedding size: ${row['embedding_size']} bytes, Text: ${row['chunk_text_size']} chars');
      }
      
      return {
        'totalFiles': files.length,
        'totalEmbeddings': embeddings.length,
        'embeddingsWithFiles': embeddingsWithFiles.length,
        'details': embeddingsWithFiles,
      };
    } catch (e) {
      print('RAG DEBUG ERROR: $e');
      return {'error': e.toString()};
    }
  }

  void dispose() {
    _embeddingService.dispose();
    _aiService.dispose();
    _isInitialized = false;
    _isIndexing = false;
  }
} 