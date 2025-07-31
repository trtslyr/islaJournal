import 'dart:math' as math;
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'ai_service.dart';
import 'database_service.dart';
import '../models/journal_file.dart';

class EmbeddingService {
  static final EmbeddingService _instance = EmbeddingService._internal();
  factory EmbeddingService() => _instance;
  EmbeddingService._internal();

  final AIService _aiService = AIService();
  final DatabaseService _dbService = DatabaseService();
  
  // Common English stop words to ignore
  static const _stopWords = {
    'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 
    'of', 'with', 'by', 'is', 'are', 'was', 'were', 'be', 'been', 'have', 
    'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could', 'should',
    'this', 'that', 'these', 'those', 'i', 'me', 'my', 'we', 'our', 'you',
    'your', 'he', 'him', 'his', 'she', 'her', 'it', 'its', 'they', 'them'
  };

  // Generate semantic embedding using content analysis
  Future<List<double>> generateEmbedding(String text) async {
    if (text.trim().isEmpty) return List.filled(100, 0.0);
    
    try {
      // Preprocess text
      final processed = _preprocessText(text);
      final words = processed.split(' ').where((w) => w.isNotEmpty).toList();
      
      // Create embedding vector
      final embedding = List.filled(100, 0.0);
      
      // Use multiple techniques to create meaningful embeddings
      _addWordFrequencyFeatures(words, embedding);
      _addSemanticFeatures(words, embedding);
      _addStructuralFeatures(text, embedding);
      _addEmotionalFeatures(words, embedding);
      
      // Normalize vector
      _normalizeVector(embedding);
      
      return embedding;
    } catch (e) {

      return List.filled(100, 0.0);
    }
  }

  // Preprocess text for embedding generation
  String _preprocessText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // Add word frequency features to embedding
  void _addWordFrequencyFeatures(List<String> words, List<double> embedding) {
    final wordCounts = <String, int>{};
    final filteredWords = words.where((w) => !_stopWords.contains(w));
    
    for (final word in filteredWords) {
      wordCounts[word] = (wordCounts[word] ?? 0) + 1;
    }
    
    // Use top frequent words for features
    final sortedWords = wordCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    for (int i = 0; i < math.min(30, sortedWords.length); i++) {
      final word = sortedWords[i].key;
      final count = sortedWords[i].value;
      final hash = _hashToIndex(word, 30);
      embedding[hash] += count / words.length;
    }
  }

  // Add semantic features based on word categories
  void _addSemanticFeatures(List<String> words, List<double> embedding) {
    final emotionWords = {
      'happy', 'sad', 'angry', 'excited', 'depressed', 'anxious', 'calm',
      'stressed', 'relaxed', 'worried', 'confident', 'grateful', 'frustrated'
    };
    
    final timeWords = {
      'today', 'yesterday', 'tomorrow', 'morning', 'afternoon', 'evening',
      'night', 'week', 'month', 'year', 'recently', 'later', 'soon'
    };
    
    final relationshipWords = {
      'family', 'friend', 'work', 'colleague', 'partner', 'spouse', 'parent',
      'child', 'sibling', 'boss', 'team', 'relationship', 'love', 'conflict'
    };
    
    // Count semantic categories
    double emotionScore = 0;
    double timeScore = 0;
    double relationshipScore = 0;
    
    for (final word in words) {
      if (emotionWords.contains(word)) emotionScore++;
      if (timeWords.contains(word)) timeScore++;
      if (relationshipWords.contains(word)) relationshipScore++;
    }
    
    // Add to embedding
    embedding[30] = emotionScore / words.length;
    embedding[31] = timeScore / words.length;
    embedding[32] = relationshipScore / words.length;
  }

  // Add structural features
  void _addStructuralFeatures(String text, List<double> embedding) {
    final sentences = text.split(RegExp(r'[.!?]')).length;
    final paragraphs = text.split('\n\n').length;
    final questions = text.split('?').length - 1;
    final exclamations = text.split('!').length - 1;
    
    embedding[33] = sentences / 100.0; // Normalize
    embedding[34] = paragraphs / 50.0;
    embedding[35] = questions / 20.0;
    embedding[36] = exclamations / 20.0;
  }

  // Add emotional tone features
  void _addEmotionalFeatures(List<String> words, List<double> embedding) {
    final positiveWords = {
      'good', 'great', 'amazing', 'wonderful', 'excellent', 'perfect',
      'love', 'beautiful', 'happy', 'joy', 'success', 'win', 'achieve'
    };
    
    final negativeWords = {
      'bad', 'terrible', 'awful', 'horrible', 'worst', 'hate', 'sad',
      'angry', 'frustrated', 'fail', 'problem', 'issue', 'struggle'
    };
    
    double positiveScore = 0;
    double negativeScore = 0;
    
    for (final word in words) {
      if (positiveWords.contains(word)) positiveScore++;
      if (negativeWords.contains(word)) negativeScore++;
    }
    
    embedding[37] = positiveScore / words.length;
    embedding[38] = negativeScore / words.length;
  }

  // Hash string to index
  int _hashToIndex(String text, int maxIndex) {
    final bytes = utf8.encode(text);
    final digest = sha256.convert(bytes);
    return digest.bytes.first % maxIndex;
  }

  // Normalize vector to unit length
  void _normalizeVector(List<double> vector) {
    double magnitude = 0;
    for (final value in vector) {
      magnitude += value * value;
    }
    magnitude = math.sqrt(magnitude);
    
    if (magnitude > 0) {
      for (int i = 0; i < vector.length; i++) {
        vector[i] /= magnitude;
      }
    }
  }

  // Store embedding for a file
  Future<void> storeEmbedding(String fileId, String content) async {
    final embedding = await generateEmbedding(content);
    await _dbService.storeEmbedding(fileId, embedding);
  }

  // Find similar files using cosine similarity with chunked embeddings
  Future<List<JournalFile>> findSimilarFiles(String query, {int topK = 10}) async {

    
    final queryEmbedding = await generateEmbedding(query);

    
    // Get all file chunks with embeddings from file_embeddings table
    final db = await _dbService.database;
    final chunkRows = await db.rawQuery('''
      SELECT fe.file_id, fe.content, fe.embedding, f.name, f.file_path, f.folder_id, 
             f.created_at, f.updated_at, f.last_opened, f.word_count, f.journal_date
      FROM file_embeddings fe
      JOIN files f ON fe.file_id = f.id
      ORDER BY fe.file_id, fe.chunk_index
    ''');
    
    if (chunkRows.isEmpty) {
      debugPrint('   ⚠️ No chunked embeddings found in database');
      return [];
    }
    
    debugPrint('🔍 Found ${chunkRows.length} chunks to search across files');
    
    // Group chunks by file and calculate similarity per file
    final fileChunks = <String, List<Map<String, dynamic>>>{};
    final fileInfos = <String, Map<String, dynamic>>{};
    
    for (final row in chunkRows) {
      final fileId = row['file_id'] as String;
      if (!fileChunks.containsKey(fileId)) {
        fileChunks[fileId] = [];
        fileInfos[fileId] = {
          'name': row['name'],
          'file_path': row['file_path'], 
          'folder_id': row['folder_id'],
          'created_at': row['created_at'],
          'updated_at': row['updated_at'],
          'last_opened': row['last_opened'],
          'word_count': row['word_count'],
          'journal_date': row['journal_date'],
        };
      }
      fileChunks[fileId]!.add(row);
    }
    
    debugPrint('🔍 Grouped chunks into ${fileChunks.length} unique files');
    
    final similarities = <_SimilarityResult>[];
    int chunkCount = 0;
    int dimensionMismatches = 0;
    int emptyEmbeddings = 0;
    int validSimilarityCalculations = 0;
    
    for (final fileId in fileChunks.keys) {
      final chunks = fileChunks[fileId]!;
      final fileInfo = fileInfos[fileId]!;
      
      // Calculate similarity for each chunk and take the best match
      double maxSimilarity = -1.0;
      String? bestChunkContent;
      
      debugPrint('🔍 Processing file "${fileInfo['name']}" with ${chunks.length} chunks');
      
      for (final chunk in chunks) {
        chunkCount++;
        final embedding = _parseChunkedEmbedding(chunk['embedding']);
        
        if (embedding.isEmpty) {
          debugPrint('🔍 Chunk $chunkCount: EMPTY EMBEDDING!');
          emptyEmbeddings++;
          continue;
        }
        
        if (embedding.length != queryEmbedding.length) {
          debugPrint('🔍 DIMENSION MISMATCH: query=${queryEmbedding.length}, chunk=${embedding.length}');
          dimensionMismatches++;
          continue;
        }
        
        validSimilarityCalculations++;
        final similarity = _cosineSimilarity(queryEmbedding, embedding);
        final chunkPreview = chunk['content'].toString().substring(0, math.min(50, chunk['content'].toString().length));
        debugPrint('🔍 Chunk $chunkCount similarity: ${similarity.toStringAsFixed(6)} for "$chunkPreview..."');
        
        if (similarity > maxSimilarity) {
          maxSimilarity = similarity;
          bestChunkContent = chunk['content'] as String?;
        }
      }
      
      debugPrint('🔍 File "${fileInfo['name']}" max similarity: ${maxSimilarity.toStringAsFixed(6)}');
      
      // Accept any similarity > -1.0 (essentially all results)
      if (maxSimilarity > -1.0 && bestChunkContent != null) {
        // Create JournalFile with the most relevant chunk content
        final journalFile = JournalFile(
          id: fileId,
          name: fileInfo['name'] as String,
          folderId: fileInfo['folder_id'] as String?,
          filePath: fileInfo['file_path'] as String,
          content: bestChunkContent, // Use the most relevant chunk
          wordCount: fileInfo['word_count'] as int? ?? 0,
          createdAt: DateTime.parse(fileInfo['created_at'] as String),
          updatedAt: DateTime.parse(fileInfo['updated_at'] as String),
          lastOpened: fileInfo['last_opened'] != null 
              ? DateTime.parse(fileInfo['last_opened'] as String) 
              : null,
          journalDate: fileInfo['journal_date'] != null
              ? DateTime.parse(fileInfo['journal_date'] as String)
              : null,
        );
        
        similarities.add(_SimilarityResult(journalFile, maxSimilarity));
      } else {
        debugPrint('🔍 File "${fileInfo['name']}" EXCLUDED: maxSimilarity=${maxSimilarity.toStringAsFixed(6)}, hasContent=${bestChunkContent != null}');
      }
    }
    
    debugPrint('🔍 SIMILARITY SEARCH SUMMARY:');
    debugPrint('   - Total chunks processed: $chunkCount');
    debugPrint('   - Empty embeddings: $emptyEmbeddings');
    debugPrint('   - Dimension mismatches: $dimensionMismatches');
    debugPrint('   - Valid similarity calculations: $validSimilarityCalculations');
    debugPrint('   - Files with valid similarities: ${similarities.length}');
    
    // Sort by similarity and return top K
    similarities.sort((a, b) => b.similarity.compareTo(a.similarity));
    final results = similarities.take(topK).map((s) => s.file).toList();
    
    debugPrint('🔍 FINAL RESULTS: ${results.length} files returned (requested top $topK)');
    for (int i = 0; i < results.length; i++) {
      final similarity = similarities[i].similarity;
      debugPrint('   ${i + 1}. "${results[i].name}" - similarity: ${similarity.toStringAsFixed(6)}');
    }
    
    return results;
  }

  // Parse chunked embedding from binary storage (Float32List bytes) - PUBLIC for testing
  List<double> parseChunkedEmbedding(dynamic embeddingBytes) {
    if (embeddingBytes == null) return [];
    try {
      if (embeddingBytes is Uint8List) {
        // FIXED: Use Float32List.fromList with proper length constraint
        final expectedFloats = 100; // Our embeddings should be 100 dimensions
        final maxFloats = embeddingBytes.length ~/ 4; // 4 bytes per float
        final actualFloats = math.min(expectedFloats, maxFloats);
        
        final float32List = Float32List.view(
          embeddingBytes.buffer, 
          embeddingBytes.offsetInBytes, 
          actualFloats
        );
        
        final result = float32List.cast<double>();
        debugPrint('🔍 PARSE DEBUG: Parsed ${result.length} floats from ${embeddingBytes.length} bytes (expected: $expectedFloats)');
        return result;
      }
      return [];
    } catch (e) {
      debugPrint('Error parsing chunked embedding: $e');
      return [];
    }
  }

  // Private wrapper for internal use
  List<double> _parseChunkedEmbedding(dynamic embeddingBytes) {
    return parseChunkedEmbedding(embeddingBytes);
  }

  // Parse stored embedding from database (legacy comma-separated format)
  List<double> _parseStoredEmbedding(String? embeddingStr) {
    if (embeddingStr == null || embeddingStr.isEmpty) return [];
    try {
      return embeddingStr.split(',').map((s) => double.parse(s)).toList();
    } catch (e) {
      return [];
    }
  }

  // Calculate cosine similarity between two vectors
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) {
      debugPrint('🔍 COSINE: Length mismatch a=${a.length}, b=${b.length}');
      return 0.0;
    }
    
    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    
    final sqrtNormA = math.sqrt(normA);
    final sqrtNormB = math.sqrt(normB);
    final norm = sqrtNormA * sqrtNormB;
    
    final result = norm > 0 ? dot / norm : 0.0;
    
    // Only log detailed cosine info for very low or very high similarities (to reduce spam)
    if (result < 0.1 || result > 0.5) {
      debugPrint('🔍 COSINE (notable): similarity=${result.toStringAsFixed(6)}, dot=${dot.toStringAsFixed(4)}, norm=${norm.toStringAsFixed(4)}');
    }
    
    return result;
  }
}

class _SimilarityResult {
  final JournalFile file;
  final double similarity;
  
  _SimilarityResult(this.file, this.similarity);
} 