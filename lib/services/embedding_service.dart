import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';

class EmbeddingService {
  static final EmbeddingService _instance = EmbeddingService._internal();
  factory EmbeddingService() => _instance;
  EmbeddingService._internal();

  // Simple embedding model using TF-IDF + cosine similarity
  // In a full implementation, you'd use a local sentence-transformer model
  final Map<String, double> _vocabulary = {};
  final Map<String, Map<String, double>> _termFrequency = {};
  final Map<String, double> _inverseDocumentFrequency = {};
  final Set<String> _processedDocuments = {}; // Track processed documents to avoid double counting
  int _documentCount = 0;
  bool _isInitialized = false;

  // Embedding dimension (384 is common for sentence transformers)
  static const int embeddingDimension = 384;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _loadVocabulary();
      _isInitialized = true;
      print('Embedding service initialized with vocabulary size: ${_vocabulary.length}, documents: $_documentCount');
    } catch (e) {
      print('Error initializing embedding service: $e');
      throw Exception('Failed to initialize embedding service: $e');
    }
  }

  Future<void> _loadVocabulary() async {
    // Load existing vocabulary from disk if available
    final vocabFile = await _getVocabularyFile();
    if (await vocabFile.exists()) {
      try {
        final contents = await vocabFile.readAsString();
        final data = jsonDecode(contents);
        _vocabulary.addAll(Map<String, double>.from(data['vocabulary'] ?? {}));
        _termFrequency.addAll(Map<String, Map<String, double>>.from(
          (data['termFrequency'] as Map<String, dynamic>? ?? {}).map(
            (key, value) => MapEntry(key, Map<String, double>.from(value)),
          ),
        ));
        _inverseDocumentFrequency.addAll(
          Map<String, double>.from(data['inverseDocumentFrequency'] ?? {}),
        );
        _processedDocuments.addAll(Set<String>.from(data['processedDocuments'] ?? []));
        _documentCount = data['documentCount'] ?? 0;
        
        print('Loaded vocabulary: ${_vocabulary.length} words, ${_processedDocuments.length} documents');
      } catch (e) {
        print('Error loading vocabulary: $e');
        // Continue with empty vocabulary
      }
    }
  }

  Future<void> _saveVocabulary() async {
    final vocabFile = await _getVocabularyFile();
    final data = {
      'vocabulary': _vocabulary,
      'termFrequency': _termFrequency,
      'inverseDocumentFrequency': _inverseDocumentFrequency,
      'processedDocuments': _processedDocuments.toList(),
      'documentCount': _documentCount,
    };
    await vocabFile.writeAsString(jsonEncode(data));
  }

  Future<File> _getVocabularyFile() async {
    final appDir = await getApplicationDocumentsDirectory();
    final embeddingDir = Directory('${appDir.path}/isla_journal_embeddings');
    
    if (!await embeddingDir.exists()) {
      await embeddingDir.create(recursive: true);
    }
    
    return File('${embeddingDir.path}/vocabulary.json');
  }

  // Preprocess text for embedding
  List<String> _preprocessText(String text) {
    // Convert to lowercase and remove special characters
    final cleaned = text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), ' ');
    
    // Split into words and remove empty strings
    final words = cleaned.split(RegExp(r'\s+'))
        .where((word) => word.length > 2) // Remove short words
        .where((word) => !_isStopWord(word)) // Remove stop words
        .toList();
    
    return words;
  }

  bool _isStopWord(String word) {
    const stopWords = {
      'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
      'of', 'with', 'by', 'is', 'are', 'was', 'were', 'be', 'been', 'have',
      'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could', 'should',
      'this', 'that', 'these', 'those', 'i', 'me', 'my', 'myself', 'we',
      'our', 'ours', 'ourselves', 'you', 'your', 'yours', 'yourself',
      'yourselves', 'he', 'him', 'his', 'himself', 'she', 'her', 'hers',
      'herself', 'it', 'its', 'itself', 'they', 'them', 'their', 'theirs',
      'themselves'
    };
    return stopWords.contains(word);
  }

  // Generate embedding for a text
  Future<List<double>> generateEmbedding(String text, String documentId) async {
    if (!_isInitialized) await initialize();
    
    final words = _preprocessText(text);
    if (words.isEmpty) {
      return List.filled(embeddingDimension, 0.0);
    }

    // Update vocabulary and term frequency - ONLY if this is a new document
    final isNewDocument = !_processedDocuments.contains(documentId);
    if (isNewDocument) {
      _updateVocabulary(words, documentId);
      _processedDocuments.add(documentId);
      print('Added new document to vocabulary: $documentId (total documents: $_documentCount)');
    } else {
      // For existing documents, just update the term frequency without affecting global stats
      _updateTermFrequencyOnly(words, documentId);
    }

    // Generate TF-IDF based embedding
    final embedding = _generateTfIdfEmbedding(words, documentId);
    
    // Save updated vocabulary (but not on every call to avoid performance issues)
    if (isNewDocument) {
      await _saveVocabulary();
    }
    
    return embedding;
  }

  void _updateVocabulary(List<String> words, String documentId) {
    // Add words to vocabulary
    for (final word in words) {
      _vocabulary[word] = (_vocabulary[word] ?? 0) + 1;
    }

    // Calculate term frequency for this document
    final termFreq = <String, double>{};
    for (final word in words) {
      termFreq[word] = (termFreq[word] ?? 0) + 1;
    }

    // Normalize term frequency
    final maxFreq = termFreq.values.isNotEmpty ? termFreq.values.reduce(max) : 1.0;
    for (final entry in termFreq.entries) {
      termFreq[entry.key] = entry.value / maxFreq;
    }

    _termFrequency[documentId] = termFreq;
    _documentCount++; // Only increment for NEW documents

    // Recalculate IDF
    _updateInverseDocumentFrequency();
  }

  void _updateTermFrequencyOnly(List<String> words, String documentId) {
    // Calculate term frequency for this document (for existing documents)
    final termFreq = <String, double>{};
    for (final word in words) {
      termFreq[word] = (termFreq[word] ?? 0) + 1;
    }

    // Normalize term frequency
    final maxFreq = termFreq.values.isNotEmpty ? termFreq.values.reduce(max) : 1.0;
    for (final entry in termFreq.entries) {
      termFreq[entry.key] = entry.value / maxFreq;
    }

    _termFrequency[documentId] = termFreq;
    // DON'T increment document count or update vocabulary for existing documents
  }

  void _updateInverseDocumentFrequency() {
    if (_documentCount == 0) return;
    
    for (final word in _vocabulary.keys) {
      final documentsContainingWord = _termFrequency.values
          .where((tf) => tf.containsKey(word))
          .length;
      
      if (documentsContainingWord > 0) {
        _inverseDocumentFrequency[word] = 
            log(_documentCount / documentsContainingWord);
      }
    }
  }

  List<double> _generateTfIdfEmbedding(List<String> words, String documentId) {
    final tfMap = _termFrequency[documentId] ?? {};
    final embedding = List.filled(embeddingDimension, 0.0);
    
    // Improved hash-based approach to map words to embedding dimensions
    for (final word in words) {
      final tf = tfMap[word] ?? 0.0;
      final idf = _inverseDocumentFrequency[word] ?? 0.0;
      final tfidf = tf * idf;
      
      if (tfidf == 0.0) continue; // Skip words with no weight
      
      // Map word to multiple dimensions using hash (improved distribution)
      final hash = word.hashCode.abs();
      for (int i = 0; i < 8; i++) { // Each word affects 8 dimensions (increased for better distribution)
        final dim = (hash + i * 7919) % embeddingDimension; // Use prime number for better distribution
        embedding[dim] += tfidf * (1.0 / (i + 1)); // Diminishing weight for each dimension
      }
    }
    
    // Normalize the embedding vector
    final magnitude = sqrt(embedding.fold<double>(0, (sum, val) => sum + val * val));
    if (magnitude > 0) {
      for (int i = 0; i < embedding.length; i++) {
        embedding[i] /= magnitude;
      }
    }
    
    return embedding;
  }

  // Calculate cosine similarity between two embeddings
  static double cosineSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      throw ArgumentError('Embeddings must have the same dimension');
    }
    
    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;
    
    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
      norm1 += embedding1[i] * embedding1[i];
      norm2 += embedding2[i] * embedding2[i];
    }
    
    if (norm1 == 0.0 || norm2 == 0.0) return 0.0;
    
    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }

  // Generate embedding for a query (without updating vocabulary)
  Future<List<double>> generateQueryEmbedding(String query) async {
    if (!_isInitialized) await initialize();
    
    final words = _preprocessText(query);
    if (words.isEmpty) {
      return List.filled(embeddingDimension, 0.0);
    }

    // Generate embedding without updating vocabulary
    final embedding = List.filled(embeddingDimension, 0.0);
    
    for (final word in words) {
      final idf = _inverseDocumentFrequency[word] ?? 0.0;
      final tf = words.where((w) => w == word).length / words.length;
      final tfidf = tf * idf;
      
      if (tfidf == 0.0) continue; // Skip words with no weight
      
      // Map word to multiple dimensions using hash (same improved distribution)
      final hash = word.hashCode.abs();
      for (int i = 0; i < 8; i++) {
        final dim = (hash + i * 7919) % embeddingDimension;
        embedding[dim] += tfidf * (1.0 / (i + 1));
      }
    }
    
    // Normalize the embedding vector
    final magnitude = sqrt(embedding.fold<double>(0, (sum, val) => sum + val * val));
    if (magnitude > 0) {
      for (int i = 0; i < embedding.length; i++) {
        embedding[i] /= magnitude;
      }
    }
    
    return embedding;
  }

  // Reindex all documents (useful when vocabulary changes significantly)
  Future<void> reindexDocuments(Map<String, String> documents) async {
    print('Reindexing ${documents.length} documents...');
    
    _vocabulary.clear();
    _termFrequency.clear();
    _inverseDocumentFrequency.clear();
    _processedDocuments.clear();
    _documentCount = 0;
    
    for (final entry in documents.entries) {
      await generateEmbedding(entry.value, entry.key);
    }
    
    print('Reindexing completed. Vocabulary size: ${_vocabulary.length}, Documents: $_documentCount');
  }

  // Get vocabulary statistics
  Map<String, dynamic> getVocabularyStats() {
    return {
      'vocabularySize': _vocabulary.length,
      'documentCount': _documentCount,
      'processedDocuments': _processedDocuments.length,
      'embeddingDimension': embeddingDimension,
      'isInitialized': _isInitialized,
      'averageWordsPerDocument': _documentCount > 0 ? (_vocabulary.values.reduce((a, b) => a + b) / _documentCount).toStringAsFixed(2) : '0',
    };
  }

  // Clear all embeddings and start fresh
  Future<void> clearEmbeddings() async {
    _vocabulary.clear();
    _termFrequency.clear();
    _inverseDocumentFrequency.clear();
    _processedDocuments.clear();
    _documentCount = 0;
    
    // Delete vocabulary file
    final vocabFile = await _getVocabularyFile();
    if (await vocabFile.exists()) {
      await vocabFile.delete();
    }
    
    print('Cleared all embeddings and vocabulary');
  }

  void dispose() {
    _vocabulary.clear();
    _termFrequency.clear();
    _inverseDocumentFrequency.clear();
    _processedDocuments.clear();
    _documentCount = 0;
    _isInitialized = false;
  }
} 