import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'ai_service.dart';
import 'database_service.dart';
import '../models/journal_file.dart';

/// Auto-generated tag data
@HiveType(typeId: 2)
class AutoTag {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String fileId;
  
  @HiveField(2)
  final String tag;
  
  @HiveField(3)
  final double confidence;
  
  @HiveField(4)
  final String category;
  
  @HiveField(5)
  final DateTime createdAt;
  
  @HiveField(6)
  final bool isUserApproved;

  AutoTag({
    required this.id,
    required this.fileId,
    required this.tag,
    required this.confidence,
    required this.category,
    required this.createdAt,
    required this.isUserApproved,
  });

  AutoTag copyWith({
    bool? isUserApproved,
  }) {
    return AutoTag(
      id: id,
      fileId: fileId,
      tag: tag,
      confidence: confidence,
      category: category,
      createdAt: createdAt,
      isUserApproved: isUserApproved ?? this.isUserApproved,
    );
  }
}

/// Tag suggestions for a file
class TagSuggestions {
  final String fileId;
  final List<AutoTag> suggestedTags;
  final List<AutoTag> approvedTags;
  final double overallConfidence;

  TagSuggestions({
    required this.fileId,
    required this.suggestedTags,
    required this.approvedTags,
    required this.overallConfidence,
  });
}

/// Tag analytics and insights
class TagAnalytics {
  final Map<String, int> tagFrequency;
  final Map<String, List<String>> categoryTags;
  final List<String> trendingTags;
  final Map<String, double> tagConfidence;

  TagAnalytics({
    required this.tagFrequency,
    required this.categoryTags,
    required this.trendingTags,
    required this.tagConfidence,
  });
}

/// Service for automatically generating tags for journal entries
class AutoTaggingService {
  static final AutoTaggingService _instance = AutoTaggingService._internal();
  factory AutoTaggingService() => _instance;
  AutoTaggingService._internal();

  final AIService _aiService = AIService();
  final DatabaseService _dbService = DatabaseService();
  Box<AutoTag>? _tagBox;
  
  bool _isInitialized = false;

  // Predefined tag categories
  static const Map<String, List<String>> _tagCategories = {
    'emotions': ['happy', 'sad', 'angry', 'excited', 'anxious', 'grateful', 'proud', 'lonely'],
    'activities': ['work', 'exercise', 'travel', 'cooking', 'reading', 'writing', 'socializing'],
    'relationships': ['family', 'friends', 'colleagues', 'romantic', 'children', 'parents'],
    'goals': ['career', 'health', 'fitness', 'learning', 'personal-growth', 'financial'],
    'themes': ['reflection', 'gratitude', 'challenges', 'achievements', 'dreams', 'memories'],
    'locations': ['home', 'office', 'outdoors', 'cafe', 'gym', 'vacation'],
    'time': ['morning', 'evening', 'weekend', 'weekday', 'holiday', 'birthday'],
  };

  /// Initialize the auto-tagging service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Register Hive adapter
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(AutoTagAdapter());
      }
      
      // Open the tags box
      _tagBox = await Hive.openBox<AutoTag>('auto_tags');
      
      _isInitialized = true;
      debugPrint('AutoTaggingService initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize AutoTaggingService: $e');
      throw Exception('Failed to initialize auto-tagging service: $e');
    }
  }

  /// Generate tags for a journal entry
  Future<TagSuggestions> generateTags(JournalFile file) async {
    if (!_isInitialized) {
      throw Exception('AutoTaggingService not initialized');
    }

    try {
      // Check if tags already exist
      final existingTags = await getFileTags(file.id);
      if (existingTags.isNotEmpty) {
        return _buildTagSuggestions(file.id, existingTags);
      }

      // Generate tags using AI
      final tagResponse = await _aiService.generateText(
        _buildTaggingPrompt(file),
        options: {
          'temperature': 0.4,
          'max_tokens': 300,
        },
      );

      // Parse the AI response
      final suggestedTags = _parseTagResponse(file.id, tagResponse);
      
      // Store the tags
      for (final tag in suggestedTags) {
        await _tagBox!.put(tag.id, tag);
      }
      
      return _buildTagSuggestions(file.id, suggestedTags);
    } catch (e) {
      debugPrint('Error generating tags: $e');
      throw Exception('Failed to generate tags: $e');
    }
  }

  /// Get all tags for a file
  Future<List<AutoTag>> getFileTags(String fileId) async {
    if (!_isInitialized) {
      throw Exception('AutoTaggingService not initialized');
    }

    return _tagBox!.values
        .where((tag) => tag.fileId == fileId)
        .toList();
  }

  /// Get approved tags for a file
  Future<List<AutoTag>> getApprovedTags(String fileId) async {
    final allTags = await getFileTags(fileId);
    return allTags.where((tag) => tag.isUserApproved).toList();
  }

  /// Get suggested (unapproved) tags for a file
  Future<List<AutoTag>> getSuggestedTags(String fileId) async {
    final allTags = await getFileTags(fileId);
    return allTags.where((tag) => !tag.isUserApproved).toList();
  }

  /// Approve a tag
  Future<void> approveTag(String tagId) async {
    if (!_isInitialized) {
      throw Exception('AutoTaggingService not initialized');
    }

    final tag = _tagBox!.get(tagId);
    if (tag != null) {
      await _tagBox!.put(tagId, tag.copyWith(isUserApproved: true));
    }
  }

  /// Reject a tag
  Future<void> rejectTag(String tagId) async {
    if (!_isInitialized) {
      throw Exception('AutoTaggingService not initialized');
    }

    await _tagBox!.delete(tagId);
  }

  /// Get tag analytics
  Future<TagAnalytics> getAnalytics() async {
    if (!_isInitialized) {
      throw Exception('AutoTaggingService not initialized');
    }

    final allTags = _tagBox!.values.toList();
    final approvedTags = allTags.where((tag) => tag.isUserApproved).toList();

    // Calculate frequency
    final tagFrequency = <String, int>{};
    final tagConfidence = <String, double>{};
    final categoryTags = <String, List<String>>{};

    for (final tag in approvedTags) {
      tagFrequency[tag.tag] = (tagFrequency[tag.tag] ?? 0) + 1;
      tagConfidence[tag.tag] = (tagConfidence[tag.tag] ?? 0.0) + tag.confidence;
      
      // Group by category
      categoryTags[tag.category] ??= [];
      if (!categoryTags[tag.category]!.contains(tag.tag)) {
        categoryTags[tag.category]!.add(tag.tag);
      }
    }

    // Calculate average confidence
    tagConfidence.forEach((tag, totalConfidence) {
      tagConfidence[tag] = totalConfidence / tagFrequency[tag]!;
    });

    // Get trending tags (most frequently used recently)
    final recentTags = allTags
        .where((tag) => tag.isUserApproved)
        .where((tag) => tag.createdAt.isAfter(
            DateTime.now().subtract(const Duration(days: 30))))
        .toList();
    
    final recentFrequency = <String, int>{};
    for (final tag in recentTags) {
      recentFrequency[tag.tag] = (recentFrequency[tag.tag] ?? 0) + 1;
    }

    final trendingTags = recentFrequency.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value))
        .take(10)
        .map((e) => e.key)
        .toList();

    return TagAnalytics(
      tagFrequency: tagFrequency,
      categoryTags: categoryTags,
      trendingTags: trendingTags,
      tagConfidence: tagConfidence,
    );
  }

  /// Get tag suggestions based on content similarity
  Future<List<String>> getSimilarTags(String content) async {
    if (!_isInitialized) {
      throw Exception('AutoTaggingService not initialized');
    }

    // Get all approved tags
    final allTags = _tagBox!.values
        .where((tag) => tag.isUserApproved)
        .toList();

    if (allTags.isEmpty) {
      return [];
    }

    // Simple content-based similarity (in production, use embeddings)
    final contentWords = content.toLowerCase().split(' ');
    final tagSimilarity = <String, int>{};

    for (final tag in allTags) {
      final tagWords = tag.tag.toLowerCase().split('-');
      int similarity = 0;
      
      for (final tagWord in tagWords) {
        if (contentWords.any((word) => word.contains(tagWord))) {
          similarity++;
        }
      }
      
      if (similarity > 0) {
        tagSimilarity[tag.tag] = (tagSimilarity[tag.tag] ?? 0) + similarity;
      }
    }

    // Return top similar tags
    return tagSimilarity.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value))
        .take(5)
        .map((e) => e.key)
        .toList();
  }

  /// Tag all journal entries
  Future<void> tagAllEntries() async {
    if (!_isInitialized) {
      throw Exception('AutoTaggingService not initialized');
    }

    try {
      final files = await _dbService.getFiles();
      
      for (final file in files) {
        final existingTags = await getFileTags(file.id);
        if (existingTags.isEmpty) {
          await generateTags(file);
        }
      }
    } catch (e) {
      debugPrint('Error tagging all entries: $e');
      throw Exception('Failed to tag all entries: $e');
    }
  }

  /// Build tagging prompt for AI
  String _buildTaggingPrompt(JournalFile file) {
    final availableTags = _tagCategories.values
        .expand((tags) => tags)
        .join(', ');

    return '''Analyze this journal entry and suggest relevant tags. Focus on the main themes, emotions, activities, and topics mentioned.

Journal Entry: "${file.name}"
Content:
---
${file.content}
---

Available tag categories and examples:
${_tagCategories.entries.map((entry) => '${entry.key}: ${entry.value.join(', ')}').join('\n')}

Please provide a JSON response with suggested tags:
{
  "tags": [
    {
      "tag": "work",
      "confidence": 0.85,
      "category": "activities"
    },
    {
      "tag": "stressed",
      "confidence": 0.75,
      "category": "emotions"
    }
  ]
}

Generate 3-6 relevant tags. Be specific and accurate. Confidence should be 0.0 to 1.0.

Response:''';
  }

  /// Parse tag response from AI
  List<AutoTag> _parseTagResponse(String fileId, String response) {
    try {
      // Extract JSON from response
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}');
      
      if (jsonStart == -1 || jsonEnd == -1) {
        throw Exception('No JSON found in response');
      }
      
      final jsonStr = response.substring(jsonStart, jsonEnd + 1);
      
      // Simple JSON parsing (use dart:convert in production)
      final tags = <AutoTag>[];
      
      // Extract tags array (basic parsing)
      final tagMatches = RegExp(r'"tag":\s*"([^"]+)"').allMatches(jsonStr);
      final confidenceMatches = RegExp(r'"confidence":\s*([0-9.]+)').allMatches(jsonStr);
      final categoryMatches = RegExp(r'"category":\s*"([^"]+)"').allMatches(jsonStr);
      
      final tagList = tagMatches.map((m) => m.group(1)!).toList();
      final confidenceList = confidenceMatches.map((m) => double.parse(m.group(1)!)).toList();
      final categoryList = categoryMatches.map((m) => m.group(1)!).toList();
      
      for (int i = 0; i < tagList.length; i++) {
        if (i < confidenceList.length && i < categoryList.length) {
          tags.add(AutoTag(
            id: 'tag_${DateTime.now().millisecondsSinceEpoch}_$i',
            fileId: fileId,
            tag: tagList[i],
            confidence: confidenceList[i],
            category: categoryList[i],
            createdAt: DateTime.now(),
            isUserApproved: false,
          ));
        }
      }
      
      return tags;
    } catch (e) {
      debugPrint('Error parsing tag response: $e');
      
      // Fallback: generate basic tags
      return [
        AutoTag(
          id: 'tag_${DateTime.now().millisecondsSinceEpoch}_fallback',
          fileId: fileId,
          tag: 'journal',
          confidence: 0.5,
          category: 'themes',
          createdAt: DateTime.now(),
          isUserApproved: false,
        ),
      ];
    }
  }

  /// Build tag suggestions response
  TagSuggestions _buildTagSuggestions(String fileId, List<AutoTag> tags) {
    final approvedTags = tags.where((tag) => tag.isUserApproved).toList();
    final suggestedTags = tags.where((tag) => !tag.isUserApproved).toList();
    
    final overallConfidence = tags.isEmpty
        ? 0.0
        : tags.map((tag) => tag.confidence).reduce((a, b) => a + b) / tags.length;

    return TagSuggestions(
      fileId: fileId,
      suggestedTags: suggestedTags,
      approvedTags: approvedTags,
      overallConfidence: overallConfidence,
    );
  }

  /// Delete all tags for a file
  Future<void> deleteFileTags(String fileId) async {
    if (!_isInitialized) {
      throw Exception('AutoTaggingService not initialized');
    }

    final tags = await getFileTags(fileId);
    for (final tag in tags) {
      await _tagBox!.delete(tag.id);
    }
  }

  /// Update tags for a file
  Future<TagSuggestions> updateFileTags(JournalFile file) async {
    // Delete existing tags
    await deleteFileTags(file.id);
    
    // Generate new tags
    return await generateTags(file);
  }

  /// Get all unique tags
  Future<List<String>> getAllTags() async {
    if (!_isInitialized) {
      throw Exception('AutoTaggingService not initialized');
    }

    final allTags = _tagBox!.values
        .where((tag) => tag.isUserApproved)
        .map((tag) => tag.tag)
        .toSet()
        .toList();
    
    allTags.sort();
    return allTags;
  }

  /// Cleanup resources
  Future<void> dispose() async {
    if (_tagBox != null) {
      await _tagBox!.close();
    }
    _isInitialized = false;
  }
}

/// Hive adapter for AutoTag
class AutoTagAdapter extends TypeAdapter<AutoTag> {
  @override
  final int typeId = 2;

  @override
  AutoTag read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AutoTag(
      id: fields[0] as String,
      fileId: fields[1] as String,
      tag: fields[2] as String,
      confidence: fields[3] as double,
      category: fields[4] as String,
      createdAt: fields[5] as DateTime,
      isUserApproved: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, AutoTag obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fileId)
      ..writeByte(2)
      ..write(obj.tag)
      ..writeByte(3)
      ..write(obj.confidence)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.isUserApproved);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AutoTagAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;

  @override
  int get hashCode => typeId.hashCode;
}