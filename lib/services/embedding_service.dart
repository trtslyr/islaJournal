import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'ai_service.dart';

/// Data class for storing embeddings
@HiveType(typeId: 0)
class EmbeddingData {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String text;
  
  @HiveField(2)
  final List<double> embedding;
  
  @HiveField(3)
  final DateTime createdAt;
  
  @HiveField(4)
  final Map<String, dynamic> metadata;

  EmbeddingData({
    required this.id,
    required this.text,
    required this.embedding,
    required this.createdAt,
    required this.metadata,
  });
}

/// Service for managing text embeddings and semantic search
class EmbeddingService {
  static final EmbeddingService _instance = EmbeddingService._internal();
  factory EmbeddingService() => _instance;
  EmbeddingService._internal();

  final AIService _aiService = AIService();
  Box<EmbeddingData>? _embeddingBox;
  
  bool _isInitialized = false;

  /// Initialize the embedding service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Register Hive adapter for EmbeddingData
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(EmbeddingDataAdapter());
      }
      
      // Open the embeddings box
      _embeddingBox = await Hive.openBox<EmbeddingData>('embeddings');
      
      _isInitialized = true;
      debugPrint('EmbeddingService initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize EmbeddingService: $e');
      throw Exception('Failed to initialize embedding service: $e');
    }
  }

  /// Generate and store embeddings for a text chunk
  Future<String> storeEmbedding(
    String text, {
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isInitialized) {
      throw Exception('EmbeddingService not initialized');
    }

    try {
      // Generate embedding using AI service
      final embedding = await _aiService.generateEmbeddings(text);
      
      // Create embedding data
      final embeddingData = EmbeddingData(
        id: _generateEmbeddingId(),
        text: text,
        embedding: embedding,
        createdAt: DateTime.now(),
        metadata: metadata ?? {},
      );

      // Store in Hive
      await _embeddingBox!.put(embeddingData.id, embeddingData);
      
      return embeddingData.id;
    } catch (e) {
      debugPrint('Error storing embedding: $e');
      throw Exception('Failed to store embedding: $e');
    }
  }

  /// Store embeddings for a journal file
  Future<List<String>> storeFileEmbeddings(
    String fileId,
    String fileName,
    String content,
  ) async {
    if (!_isInitialized) {
      throw Exception('EmbeddingService not initialized');
    }

    try {
      // Split content into chunks for better semantic search
      final chunks = _splitTextIntoChunks(content);
      final embeddingIds = <String>[];

      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        if (chunk.trim().isNotEmpty) {
          final embeddingId = await storeEmbedding(
            chunk,
            metadata: {
              'fileId': fileId,
              'fileName': fileName,
              'chunkIndex': i,
              'chunkCount': chunks.length,
            },
          );
          embeddingIds.add(embeddingId);
        }
      }

      return embeddingIds;
    } catch (e) {
      debugPrint('Error storing file embeddings: $e');
      throw Exception('Failed to store file embeddings: $e');
    }
  }

  /// Perform semantic search using embeddings
  Future<List<EmbeddingSearchResult>> semanticSearch(
    String query, {
    int limit = 10,
    double threshold = 0.5,
    String? fileId,
  }) async {
    if (!_isInitialized) {
      throw Exception('EmbeddingService not initialized');
    }

    try {
      // Generate embedding for the query
      final queryEmbedding = await _aiService.generateEmbeddings(query);
      
      // Get all embeddings
      final allEmbeddings = _embeddingBox!.values.toList();
      
      // Filter by file ID if specified
      final filteredEmbeddings = fileId != null
          ? allEmbeddings.where((e) => e.metadata['fileId'] == fileId).toList()
          : allEmbeddings;

      // Calculate similarities
      final results = <EmbeddingSearchResult>[];
      
      for (final embedding in filteredEmbeddings) {
        final similarity = _calculateCosineSimilarity(
          queryEmbedding,
          embedding.embedding,
        );
        
        if (similarity >= threshold) {
          results.add(EmbeddingSearchResult(
            embedding: embedding,
            similarity: similarity,
          ));
        }
      }

      // Sort by similarity and limit results
      results.sort((a, b) => b.similarity.compareTo(a.similarity));
      return results.take(limit).toList();
    } catch (e) {
      debugPrint('Error performing semantic search: $e');
      throw Exception('Failed to perform semantic search: $e');
    }
  }

  /// Get embeddings for a specific file
  Future<List<EmbeddingData>> getFileEmbeddings(String fileId) async {
    if (!_isInitialized) {
      throw Exception('EmbeddingService not initialized');
    }

    return _embeddingBox!.values
        .where((e) => e.metadata['fileId'] == fileId)
        .toList();
  }

  /// Delete embeddings for a file
  Future<void> deleteFileEmbeddings(String fileId) async {
    if (!_isInitialized) {
      throw Exception('EmbeddingService not initialized');
    }

    final embeddings = await getFileEmbeddings(fileId);
    for (final embedding in embeddings) {
      await _embeddingBox!.delete(embedding.id);
    }
  }

  /// Update embeddings for a file
  Future<List<String>> updateFileEmbeddings(
    String fileId,
    String fileName,
    String content,
  ) async {
    // Delete existing embeddings
    await deleteFileEmbeddings(fileId);
    
    // Store new embeddings
    return await storeFileEmbeddings(fileId, fileName, content);
  }

  /// Get embedding statistics
  Future<EmbeddingStats> getStats() async {
    if (!_isInitialized) {
      throw Exception('EmbeddingService not initialized');
    }

    final allEmbeddings = _embeddingBox!.values.toList();
    final fileIds = allEmbeddings
        .map((e) => e.metadata['fileId'] as String?)
        .where((id) => id != null)
        .toSet();

    return EmbeddingStats(
      totalEmbeddings: allEmbeddings.length,
      uniqueFiles: fileIds.length,
      totalSize: _embeddingBox!.length,
    );
  }

  /// Split text into chunks for better embeddings
  List<String> _splitTextIntoChunks(String text, {int chunkSize = 500}) {
    final words = text.split(' ');
    final chunks = <String>[];
    
    for (int i = 0; i < words.length; i += chunkSize) {
      final chunk = words
          .skip(i)
          .take(chunkSize)
          .join(' ');
      chunks.add(chunk);
    }
    
    return chunks;
  }

  /// Calculate cosine similarity between two vectors
  double _calculateCosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) {
      throw Exception('Vectors must have the same length');
    }

    double dotProduct = 0;
    double normA = 0;
    double normB = 0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) {
      return 0;
    }

    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// Generate a unique embedding ID
  String _generateEmbeddingId() {
    return 'emb_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  /// Cleanup resources
  Future<void> dispose() async {
    if (_embeddingBox != null) {
      await _embeddingBox!.close();
    }
    _isInitialized = false;
  }
}

/// Search result with similarity score
class EmbeddingSearchResult {
  final EmbeddingData embedding;
  final double similarity;

  EmbeddingSearchResult({
    required this.embedding,
    required this.similarity,
  });
}

/// Statistics about embeddings
class EmbeddingStats {
  final int totalEmbeddings;
  final int uniqueFiles;
  final int totalSize;

  EmbeddingStats({
    required this.totalEmbeddings,
    required this.uniqueFiles,
    required this.totalSize,
  });
}

/// Hive adapter for EmbeddingData
class EmbeddingDataAdapter extends TypeAdapter<EmbeddingData> {
  @override
  final int typeId = 0;

  @override
  EmbeddingData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EmbeddingData(
      id: fields[0] as String,
      text: fields[1] as String,
      embedding: List<double>.from(fields[2]),
      createdAt: fields[3] as DateTime,
      metadata: Map<String, dynamic>.from(fields[4]),
    );
  }

  @override
  void write(BinaryWriter writer, EmbeddingData obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.embedding)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.metadata);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmbeddingDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;

  @override
  int get hashCode => typeId.hashCode;
}