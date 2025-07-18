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
      print('Error generating embedding: $e');
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

  // Find similar files using cosine similarity
  Future<List<JournalFile>> findSimilarFiles(String query, {int topK = 10}) async {
    final queryEmbedding = await generateEmbedding(query);
    
    final filesWithEmbeddings = await _dbService.getFilesWithEmbeddings(
      beforeDate: DateTime.now().subtract(Duration(days: 30))
    );
    
    final similarities = <_SimilarityResult>[];
    
    for (final file in filesWithEmbeddings) {
      final embedding = _parseStoredEmbedding(file.toMap()['embedding']);
      if (embedding.isNotEmpty) {
        final similarity = _cosineSimilarity(queryEmbedding, embedding);
        similarities.add(_SimilarityResult(file, similarity));
      }
    }
    
    // Sort by similarity and return top K
    similarities.sort((a, b) => b.similarity.compareTo(a.similarity));
    return similarities.take(topK).map((s) => s.file).toList();
  }

  // Parse stored embedding from database
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
    if (a.length != b.length) return 0.0;
    
    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    
    final norm = math.sqrt(normA) * math.sqrt(normB);
    return norm > 0 ? dot / norm : 0.0;
  }
}

class _SimilarityResult {
  final JournalFile file;
  final double similarity;
  
  _SimilarityResult(this.file, this.similarity);
} 