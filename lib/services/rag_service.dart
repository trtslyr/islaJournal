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
  static const double similarityThreshold = 0.15; // Lowered threshold for better TF-IDF results
  static const int maxContextLength = 3000; // Increased context length
  static const int maxChunkLength = 800; // Maximum length for individual chunks

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('RAG Service: Starting initialization...');
      
      // Initialize embedding service first (critical for RAG)
      print('RAG Service: Initializing embedding service...');
      await _embeddingService.initialize();
      print('RAG Service: ✅ Embedding service initialized');
      
      // Initialize import service (also critical for RAG)
      print('RAG Service: Initializing document import service...');
      await _importService.initialize();
      print('RAG Service: ✅ Document import service initialized');
      
      // Initialize AI service (optional - RAG can work without it for retrieval)
      print('RAG Service: Initializing AI service...');
      try {
        await _aiService.initialize();
        print('RAG Service: ✅ AI service initialized');
      } catch (e) {
        print('RAG Service: ⚠️ AI service initialization failed (will continue without AI responses): $e');
        // Don't fail the entire RAG initialization if AI service fails
        // The RAG system can still do retrieval without AI responses
      }
      
      _isInitialized = true;
      print('RAG Service: ✅ Initialized successfully');
      
    } catch (e) {
      print('RAG Service: ❌ Critical initialization error: $e');
      throw Exception('Failed to initialize RAG service: $e');
    }
  }

  // Generate embedding for a journal entry and store it
  Future<void> indexJournalEntry(JournalFile journalFile) async {
    if (!_isInitialized) await initialize();
    
    try {
      // Skip empty content
      if (journalFile.content.trim().isEmpty) {
        print('Skipping empty journal entry: ${journalFile.name}');
        return;
      }

      // Split long content into chunks for better retrieval
      final chunks = _chunkContent(journalFile.content);
      
      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        final chunkId = chunks.length > 1 ? '${journalFile.id}_chunk_$i' : journalFile.id;
        
        final embedding = await _embeddingService.generateEmbedding(chunk, chunkId);
        
        await _storeEmbedding(
          journalFile.id,
          embedding,
          chunk,
          'journal_entry',
          chunkIndex: i,
        );
      }
      
      print('Indexed journal entry: ${journalFile.name} (${chunks.length} chunks)');
    } catch (e) {
      print('Error indexing journal entry ${journalFile.id}: $e');
      rethrow;
    }
  }

  // Split content into manageable chunks
  List<String> _chunkContent(String content) {
    if (content.length <= maxChunkLength) {
      return [content];
    }

    final chunks = <String>[];
    final sentences = content.split(RegExp(r'[.!?]+\s+'));
    
    String currentChunk = '';
    
    for (final sentence in sentences) {
      if (currentChunk.length + sentence.length > maxChunkLength && currentChunk.isNotEmpty) {
        chunks.add(currentChunk.trim());
        currentChunk = sentence;
      } else {
        currentChunk += (currentChunk.isEmpty ? '' : '. ') + sentence;
      }
    }
    
    if (currentChunk.trim().isNotEmpty) {
      chunks.add(currentChunk.trim());
    }
    
    return chunks.isEmpty ? [content] : chunks;
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
        
        try {
          // Check if already indexed (check for any chunk of this file)
          final existing = await db.query(
            'file_embeddings',
            where: 'file_id LIKE ? AND embedding_version = ?',
            whereArgs: ['${file.id}%', 1],
            limit: 1,
          );
          
          if (existing.isEmpty) {
            // Load full content and index
            final fullFile = await _dbService.getFile(file.id);
            if (fullFile != null && fullFile.content.trim().isNotEmpty) {
              await indexJournalEntry(fullFile);
            }
          } else {
            print('Journal entry already indexed: ${file.name}');
          }
        } catch (e) {
          print('Error indexing file ${file.name}: $e');
          // Continue with other files
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

  // Store embedding in database with improved error handling
  Future<void> _storeEmbedding(
    String fileId,
    List<double> embedding,
    String content,
    String sourceType, {
    int chunkIndex = 0,
  }) async {
    final db = await _dbService.database;
    
    try {
      // Convert embedding to bytes for storage
      final embeddingBytes = Float64List.fromList(embedding).buffer.asUint8List();
      
      // Create unique ID for chunks
      final embeddingId = chunkIndex > 0 ? '${const Uuid().v4()}_chunk_$chunkIndex' : const Uuid().v4();
      
      await db.insert(
        'file_embeddings',
        {
          'id': embeddingId,
          'file_id': fileId,
          'embedding': embeddingBytes,
          'embedding_version': 1,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'chunk_index': chunkIndex,
          'chunk_text': content.substring(0, content.length.clamp(0, 1000)), // Store more text
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error storing embedding for $fileId: $e');
      rethrow;
    }
  }

  // Retrieve relevant content based on query with improved search
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
        maxResults: maxResults * 2, // Get more candidates initially
        minSimilarity: minSimilarity,
      );
      print('RAG: Found ${journalResults.length} relevant journal entries');
      results.addAll(journalResults);
      
      // Search imported documents
      print('RAG: Searching imported documents...');
      final importedResults = await _searchImportedDocuments(
        queryEmbedding,
        maxResults: maxResults * 2,
        minSimilarity: minSimilarity,
      );
      print('RAG: Found ${importedResults.length} relevant imported documents');
      results.addAll(importedResults);
      
      // Sort by similarity and take top results
      results.sort((a, b) => b.similarity.compareTo(a.similarity));
      
      // Remove duplicate file IDs, keeping highest similarity
      final uniqueResults = <String, RetrievalResult>{};
      for (final result in results) {
        final key = result.sourceId.split('_chunk_')[0]; // Base file ID
        if (!uniqueResults.containsKey(key) || 
            uniqueResults[key]!.similarity < result.similarity) {
          uniqueResults[key] = result;
        }
      }
      
      final finalResults = uniqueResults.values.toList()
        ..sort((a, b) => b.similarity.compareTo(a.similarity))
        ..take(maxResults).toList();
      
      print('RAG: Returning ${finalResults.length} unique results');
      
      return finalResults;
    } catch (e) {
      print('Error retrieving relevant content: $e');
      return [];
    }
  }

  // Search journal entries with improved error handling
  Future<List<RetrievalResult>> _searchJournalEntries(
    List<double> queryEmbedding, {
    required int maxResults,
    required double minSimilarity,
  }) async {
    final db = await _dbService.database;
    final results = <RetrievalResult>[];
    
    try {
      // Get all journal entry embeddings
      final embeddings = await db.rawQuery('''
        SELECT fe.*, f.name, f.file_path, f.created_at, f.updated_at
        FROM file_embeddings fe
        JOIN files f ON (fe.file_id = f.id OR fe.file_id LIKE f.id || '_chunk_%')
        WHERE fe.embedding_version = 1
        ORDER BY f.updated_at DESC
      ''');
      
      print('RAG: Found ${embeddings.length} journal embeddings in database');
      
      for (final row in embeddings) {
        try {
          // Convert bytes back to embedding
          final embeddingBytes = row['embedding'] as Uint8List;
          if (embeddingBytes.isEmpty) continue;
          
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
          
          if (similarity >= minSimilarity) {
            final chunkText = row['chunk_text'] as String? ?? '';
            if (chunkText.trim().isNotEmpty) {
              results.add(RetrievalResult(
                content: chunkText,
                similarity: similarity,
                sourceId: row['file_id'] as String,
                sourceType: 'journal_entry',
                metadata: {
                  'filename': row['name'] as String,
                  'filePath': row['file_path'] as String,
                  'createdAt': row['created_at'] as String,
                  'updatedAt': row['updated_at'] as String,
                  'chunkIndex': row['chunk_index'] as int? ?? 0,
                },
              ));
            }
          }
        } catch (e) {
          print('Error processing journal embedding: $e');
          continue;
        }
      }
      
      print('RAG: Returning ${results.length} journal results with similarity >= $minSimilarity');
      return results;
    } catch (e) {
      print('Error searching journal entries: $e');
      return [];
    }
  }

  // Search imported documents with improved error handling
  Future<List<RetrievalResult>> _searchImportedDocuments(
    List<double> queryEmbedding, {
    required int maxResults,
    required double minSimilarity,
  }) async {
    final db = await _dbService.database;
    final results = <RetrievalResult>[];
    
    try {
      // Get all imported document embeddings
      final embeddings = await db.rawQuery('''
        SELECT fe.*, ic.content, ic.page_number, ic.chunk_index, id.original_filename
        FROM file_embeddings fe
        JOIN imported_content ic ON fe.file_id = ic.id
        JOIN imported_documents id ON ic.document_id = id.id
        WHERE fe.embedding_version = 1
        ORDER BY id.import_date DESC
      ''');
      
      print('RAG: Found ${embeddings.length} imported document embeddings');
      
      for (final row in embeddings) {
        try {
          // Convert bytes back to embedding
          final embeddingBytes = row['embedding'] as Uint8List;
          if (embeddingBytes.isEmpty) continue;
          
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
            final content = row['content'] as String? ?? '';
            if (content.trim().isNotEmpty) {
              results.add(RetrievalResult(
                content: content,
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
          }
        } catch (e) {
          print('Error processing imported document embedding: $e');
          continue;
        }
      }
      
      print('RAG: Returning ${results.length} imported document results');
      return results;
    } catch (e) {
      print('Error searching imported documents: $e');
      return [];
    }
  }

  // Generate AI response with RAG context - improved context building
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
      final relevantContent = await retrieveRelevantContent(query, maxResults: 8);
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
        systemPrompt ?? 'You are a helpful AI assistant that analyzes journal entries and provides personalized insights.',
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
      try {
        return await _aiService.generateText(
          query,
          systemPrompt: systemPrompt,
          maxTokens: maxTokens,
          temperature: temperature,
        );
      } catch (fallbackError) {
        print('Fallback AI response also failed: $fallbackError');
        return 'I apologize, but I encountered an error while processing your request. Please try again.';
      }
    }
  }

  // Build context from retrieved content - improved formatting
  String _buildContext(List<RetrievalResult> results) {
    if (results.isEmpty) return '';
    
    final contextParts = <String>[];
    int totalLength = 0;
    
    for (final result in results) {
      final sourceInfo = result.sourceType == 'journal_entry' 
          ? 'Journal Entry: ${result.metadata['filename']}'
          : 'Document: ${result.metadata['filename']}';
      
      final relevanceScore = (result.similarity * 100).toStringAsFixed(1);
      
      final contextPart = '''
[$sourceInfo - Relevance: $relevanceScore%]
${result.content.trim()}
''';
      
      if (totalLength + contextPart.length > maxContextLength) {
        // Try to fit a truncated version
        final remainingSpace = maxContextLength - totalLength;
        if (remainingSpace > 200) { // Only if we have reasonable space left
          final truncatedContent = result.content.substring(0, 
            (remainingSpace - sourceInfo.length - 50).clamp(0, result.content.length));
          contextParts.add('''
[$sourceInfo - Relevance: $relevanceScore%]
${truncatedContent.trim()}...
''');
        }
        break;
      }
      
      contextParts.add(contextPart);
      totalLength += contextPart.length;
    }
    
    return contextParts.join('\n---\n');
  }

  // Build enhanced system prompt with context - improved instructions
  String _buildEnhancedSystemPrompt(String basePrompt, String context) {
    if (context.isEmpty) return basePrompt;
    
    return '''$basePrompt

You have access to the user's personal journal entries and documents. Use this context to provide highly personalized and relevant responses. The relevance scores indicate how closely each piece of content matches the current query.

CONTEXT:
$context

INSTRUCTIONS:
1. Reference specific entries when directly relevant to the query
2. Identify patterns and themes across the user's writing
3. Provide insights based on their personal history and growth
4. Be empathetic and understanding of their unique journey
5. Connect past experiences to current thoughts when appropriate
6. Maintain complete privacy and confidentiality
7. If context doesn't directly relate to the query, acknowledge this and provide general helpful advice

Remember: You are helping someone understand their own thoughts and experiences better.''';
  }

  // Analyze writing patterns across all content - enhanced analysis
  Future<String> analyzeWritingPatterns() async {
    if (!_isInitialized) await initialize();
    
    try {
      const query = 'patterns themes emotions writing style personal growth insights';
      
      const systemPrompt = '''
You are an expert personal journal analyst and life coach. Analyze the provided journal entries to create a comprehensive personal insight report covering:

EMOTIONAL PATTERNS:
- Dominant emotions and their triggers
- Emotional growth and changes over time
- Coping mechanisms and resilience indicators

THEMES & INTERESTS:
- Major life themes and recurring topics
- Personal values and priorities
- Goals and aspirations evolution

WRITING STYLE:
- Voice and tone changes
- Complexity and depth evolution
- Self-reflection capabilities

PERSONAL GROWTH:
- Challenges overcome
- Learning moments and insights
- Relationship patterns
- Decision-making evolution

Provide specific examples from the entries and offer encouraging insights about their personal development journey.''';
      
      return await generateContextualResponse(
        query,
        systemPrompt: systemPrompt,
        maxTokens: 1000,
        temperature: 0.4,
      );
    } catch (e) {
      print('Error analyzing writing patterns: $e');
      return 'I apologize, but I encountered an error while analyzing your writing patterns. Please try again later.';
    }
  }

  // Get contextual writing suggestions - improved prompts
  Future<List<String>> getContextualWritingPrompts(String currentContent) async {
    if (!_isInitialized) await initialize();
    
    try {
      final query = 'writing prompts inspiration creativity self-reflection ${currentContent.substring(0, currentContent.length.clamp(0, 200))}';
      
      const systemPrompt = '''
You are a creative writing coach specializing in personal development and self-reflection. Based on the user's journal history and current writing, generate 5 personalized writing prompts that:

1. Build naturally on their existing themes and interests
2. Encourage deeper exploration of current thoughts
3. Help them discover new perspectives on familiar topics
4. Connect past experiences to present insights
5. Promote emotional intelligence and self-awareness

Format each prompt as a complete, engaging question or statement that inspires thoughtful writing. Make them specific to their personal journey rather than generic.''';
      
      final response = await generateContextualResponse(
        query,
        systemPrompt: systemPrompt,
        maxTokens: 400,
        temperature: 0.7,
      );
      
      // Parse response into individual prompts
      final prompts = response
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.replaceAll(RegExp(r'^\d+[\.\)]\s*'), '').trim())
          .where((line) => line.isNotEmpty && line.length > 10)
          .take(5)
          .toList();
      
      return prompts.isEmpty ? _getDefaultPrompts() : prompts;
    } catch (e) {
      print('Error generating contextual writing prompts: $e');
      return _getDefaultPrompts();
    }
  }

  List<String> _getDefaultPrompts() {
    return [
      'What patterns do you notice in your recent thoughts and experiences?',
      'How have your perspectives changed since your last journal entry?',
      'What would you like to explore more deeply from your recent reflections?',
      'What themes from your past writing resonate most with you today?',
      'How do you feel about the growth you\'ve experienced lately?',
    ];
  }

  // Get RAG system statistics - enhanced stats
  Future<Map<String, dynamic>> getRAGStats() async {
    final db = await _dbService.database;
    
    try {
      final journalEmbeddingsCount = await db.rawQuery('''
        SELECT COUNT(*) as count 
        FROM file_embeddings fe 
        WHERE EXISTS (SELECT 1 FROM files f WHERE fe.file_id = f.id OR fe.file_id LIKE f.id || '_chunk_%')
      ''');
      
      final importedEmbeddingsCount = await db.rawQuery('''
        SELECT COUNT(*) as count 
        FROM file_embeddings fe 
        WHERE EXISTS (SELECT 1 FROM imported_content ic WHERE fe.file_id = ic.id)
      ''');
      
      final totalEmbeddings = await db.rawQuery('SELECT COUNT(*) as count FROM file_embeddings');
      
      final vocabStats = _embeddingService.getVocabularyStats();
      final importStats = await _importService.getImportStats();
      
      return {
        'journalEntriesIndexed': journalEmbeddingsCount.first['count'] as int,
        'importedContentIndexed': importedEmbeddingsCount.first['count'] as int,
        'totalEmbeddings': totalEmbeddings.first['count'] as int,
        'totalIndexedItems': (journalEmbeddingsCount.first['count'] as int) + 
                            (importedEmbeddingsCount.first['count'] as int),
        'vocabularyStats': vocabStats,
        'importStats': importStats,
        'isInitialized': _isInitialized,
        'isIndexing': _isIndexing,
        'embeddingDimension': EmbeddingService.embeddingDimension,
        'similarityThreshold': similarityThreshold,
      };
    } catch (e) {
      print('Error getting RAG stats: $e');
      return {
        'error': e.toString(),
        'isInitialized': _isInitialized,
        'isIndexing': _isIndexing,
      };
    }
  }

  // Clear corrupted embeddings from database
  Future<void> clearCorruptedEmbeddings() async {
    final db = await _dbService.database;
    
    try {
      // Delete all existing embeddings
      await db.delete('file_embeddings');
      
      // Clear embedding service state
      await _embeddingService.clearEmbeddings();
      
      print('Cleared all embeddings from database and service');
    } catch (e) {
      print('Error clearing corrupted embeddings: $e');
      rethrow;
    }
  }

  // Re-index all content (useful after updates) - improved process
  Future<void> reindexAllContent({
    Function(int current, int total)? progressCallback,
  }) async {
    if (!_isInitialized) await initialize();
    
    try {
      print('Starting complete re-indexing process...');
      
      // Clear corrupted embeddings first
      await clearCorruptedEmbeddings();
      
      // Re-index journal entries
      await indexAllJournalEntries(progressCallback: progressCallback);
      
      print('RAG re-indexing completed successfully');
    } catch (e) {
      print('Error during re-indexing: $e');
      throw Exception('Failed to re-index content: $e');
    }
  }

  // Debug method to check what's in the database - enhanced debugging
  Future<Map<String, dynamic>> debugDatabaseStatus() async {
    final db = await _dbService.database;
    
    try {
      // Check journal files
      final files = await db.query('files');
      print('RAG DEBUG: Found ${files.length} journal files');
      
      // Check embeddings
      final embeddings = await db.query('file_embeddings');
      print('RAG DEBUG: Found ${embeddings.length} embeddings');
      
      // Check embedding dimensions
      final embeddingSamples = await db.rawQuery('''
        SELECT file_id, LENGTH(embedding) as embedding_size
        FROM file_embeddings 
        LIMIT 5
      ''');
      
      for (final sample in embeddingSamples) {
        final bytes = sample['embedding_size'] as int;
        final dimensions = bytes ~/ 8; // 8 bytes per double
        print('RAG DEBUG: Sample embedding - File: ${sample['file_id']}, Dimensions: $dimensions');
      }
      
      // Check specific embeddings with file names
      final embeddingsWithFiles = await db.rawQuery('''
        SELECT fe.id, fe.file_id, f.name, f.created_at, 
               LENGTH(fe.embedding) as embedding_size,
               LENGTH(fe.chunk_text) as chunk_text_size,
               fe.chunk_index
        FROM file_embeddings fe
        LEFT JOIN files f ON (fe.file_id = f.id OR fe.file_id LIKE f.id || '_chunk_%')
        ORDER BY f.created_at DESC NULLS LAST
        LIMIT 10
      ''');
      
      print('RAG DEBUG: Recent embeddings:');
      for (final row in embeddingsWithFiles) {
        final embeddingDims = (row['embedding_size'] as int) ~/ 8;
        print('  - File: ${row['name'] ?? 'Unknown'}, Embedding dims: $embeddingDims, Text: ${row['chunk_text_size']} chars, Chunk: ${row['chunk_index']}');
      }
      
      return {
        'totalFiles': files.length,
        'totalEmbeddings': embeddings.length,
        'embeddingsWithFiles': embeddingsWithFiles.length,
        'sampleEmbeddings': embeddingSamples,
        'recentEmbeddings': embeddingsWithFiles,
        'vocabStats': _embeddingService.getVocabularyStats(),
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