import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/journal_file.dart';
import 'database_service.dart';
import 'ai_service.dart';

class TagSuggestion {
  final String tagId;
  final String tagName;
  final double confidence;
  final String source; // 'existing' or 'new'
  final String? color;
  final String? description;

  TagSuggestion({
    required this.tagId,
    required this.tagName,
    required this.confidence,
    required this.source,
    this.color,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'tagId': tagId,
      'tagName': tagName,
      'confidence': confidence,
      'source': source,
      'color': color,
      'description': description,
    };
  }

  factory TagSuggestion.fromMap(Map<String, dynamic> map) {
    return TagSuggestion(
      tagId: map['tagId'] as String,
      tagName: map['tagName'] as String,
      confidence: map['confidence'] as double,
      source: map['source'] as String,
      color: map['color'] as String?,
      description: map['description'] as String?,
    );
  }
}

class ThemeSuggestion {
  final String themeId;
  final String themeName;
  final double relevanceScore;
  final String source; // 'existing' or 'new'
  final String? category;
  final String? description;

  ThemeSuggestion({
    required this.themeId,
    required this.themeName,
    required this.relevanceScore,
    required this.source,
    this.category,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'themeId': themeId,
      'themeName': themeName,
      'relevanceScore': relevanceScore,
      'source': source,
      'category': category,
      'description': description,
    };
  }

  factory ThemeSuggestion.fromMap(Map<String, dynamic> map) {
    return ThemeSuggestion(
      themeId: map['themeId'] as String,
      themeName: map['themeName'] as String,
      relevanceScore: map['relevanceScore'] as double,
      source: map['source'] as String,
      category: map['category'] as String?,
      description: map['description'] as String?,
    );
  }
}

class AutoTaggingResult {
  final String fileId;
  final List<TagSuggestion> suggestedTags;
  final List<ThemeSuggestion> suggestedThemes;
  final double overallConfidence;
  final DateTime analyzedAt;
  final Map<String, dynamic>? metadata;

  AutoTaggingResult({
    required this.fileId,
    required this.suggestedTags,
    required this.suggestedThemes,
    required this.overallConfidence,
    DateTime? analyzedAt,
    this.metadata,
  }) : analyzedAt = analyzedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'fileId': fileId,
      'suggestedTags': suggestedTags.map((tag) => tag.toMap()).toList(),
      'suggestedThemes': suggestedThemes.map((theme) => theme.toMap()).toList(),
      'overallConfidence': overallConfidence,
      'analyzedAt': analyzedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory AutoTaggingResult.fromMap(Map<String, dynamic> map) {
    return AutoTaggingResult(
      fileId: map['fileId'] as String,
      suggestedTags: (map['suggestedTags'] as List)
          .map((tagMap) => TagSuggestion.fromMap(tagMap))
          .toList(),
      suggestedThemes: (map['suggestedThemes'] as List)
          .map((themeMap) => ThemeSuggestion.fromMap(themeMap))
          .toList(),
      overallConfidence: map['overallConfidence'] as double,
      analyzedAt: DateTime.parse(map['analyzedAt'] as String),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }
}

class AutoTaggingService {
  static final AutoTaggingService _instance = AutoTaggingService._internal();
  factory AutoTaggingService() => _instance;
  AutoTaggingService._internal();

  final DatabaseService _dbService = DatabaseService();
  final AIService _aiService = AIService();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _aiService.initialize();
      _isInitialized = true;
    } catch (e) {
      print('Error initializing auto-tagging service: $e');
      throw Exception('Failed to initialize auto-tagging service: $e');
    }
  }

  // Analyze and suggest tags for a journal entry
  Future<AutoTaggingResult> analyzeAndTagEntry(JournalFile journalFile) async {
    if (!_isInitialized) await initialize();
    
    try {
      // Get AI analysis
      final aiResponse = await _aiService.generateText(
        journalFile.content,
        systemPrompt: _getTaggingPrompt(),
        maxTokens: 300,
        temperature: 0.5,
      );

      // Parse AI response
      final analysisData = _parseTaggingResponse(aiResponse);
      
      // Get existing tags and themes from database
      final existingTags = await _getExistingTags();
      final existingThemes = await _getExistingThemes();

      // Process suggested tags
      final suggestedTags = <TagSuggestion>[];
      final suggestedThemes = <ThemeSuggestion>[];

      // Process tags from AI response
      for (final tagData in analysisData['tags']) {
        final tagName = tagData['name'] as String;
        final confidence = tagData['confidence'] as double;
        
        // Check if tag already exists
        final existingTag = existingTags.firstWhere(
          (tag) => tag['name'].toString().toLowerCase() == tagName.toLowerCase(),
          orElse: () => <String, dynamic>{},
        );

        if (existingTag.isNotEmpty) {
          // Use existing tag
          suggestedTags.add(TagSuggestion(
            tagId: existingTag['id'] as String,
            tagName: existingTag['name'] as String,
            confidence: confidence,
            source: 'existing',
            color: existingTag['color'] as String?,
            description: existingTag['description'] as String?,
          ));
        } else {
          // Suggest new tag
          suggestedTags.add(TagSuggestion(
            tagId: 'new_${const Uuid().v4()}',
            tagName: tagName,
            confidence: confidence,
            source: 'new',
            color: _generateTagColor(),
            description: tagData['description'] as String?,
          ));
        }
      }

      // Process themes from AI response
      for (final themeData in analysisData['themes']) {
        final themeName = themeData['name'] as String;
        final relevance = themeData['relevance'] as double;
        
        // Check if theme already exists
        final existingTheme = existingThemes.firstWhere(
          (theme) => theme['name'].toString().toLowerCase() == themeName.toLowerCase(),
          orElse: () => <String, dynamic>{},
        );

        if (existingTheme.isNotEmpty) {
          // Use existing theme
          suggestedThemes.add(ThemeSuggestion(
            themeId: existingTheme['id'] as String,
            themeName: existingTheme['name'] as String,
            relevanceScore: relevance,
            source: 'existing',
            category: existingTheme['category'] as String?,
            description: existingTheme['description'] as String?,
          ));
        } else {
          // Suggest new theme
          suggestedThemes.add(ThemeSuggestion(
            themeId: 'new_${const Uuid().v4()}',
            themeName: themeName,
            relevanceScore: relevance,
            source: 'new',
            category: themeData['category'] as String?,
            description: themeData['description'] as String?,
          ));
        }
      }

      // Calculate overall confidence
      final allConfidences = [
        ...suggestedTags.map((tag) => tag.confidence),
        ...suggestedThemes.map((theme) => theme.relevanceScore),
      ];
      
      final overallConfidence = allConfidences.isNotEmpty
          ? allConfidences.reduce((a, b) => a + b) / allConfidences.length
          : 0.0;

      return AutoTaggingResult(
        fileId: journalFile.id,
        suggestedTags: suggestedTags,
        suggestedThemes: suggestedThemes,
        overallConfidence: overallConfidence,
        metadata: {
          'analysis_method': 'ai_llama',
          'word_count': journalFile.wordCount,
          'content_length': journalFile.content.length,
        },
      );
    } catch (e) {
      print('Error analyzing entry for auto-tagging: $e');
      return AutoTaggingResult(
        fileId: journalFile.id,
        suggestedTags: [],
        suggestedThemes: [],
        overallConfidence: 0.0,
      );
    }
  }

  // Apply auto-tagging result to a file
  Future<void> applyAutoTagging(
    String fileId,
    AutoTaggingResult result, {
    bool autoApprove = false,
  }) async {
    if (!_isInitialized) await initialize();
    
    final db = await _dbService.database;
    final now = DateTime.now().toIso8601String();

    try {
      // Apply tags
      for (final tagSuggestion in result.suggestedTags) {
        String tagId = tagSuggestion.tagId;
        
        // Create new tag if needed
        if (tagSuggestion.source == 'new') {
          tagId = const Uuid().v4();
          await db.insert('tags', {
            'id': tagId,
            'name': tagSuggestion.tagName,
            'color': tagSuggestion.color,
            'description': tagSuggestion.description,
            'created_at': now,
            'usage_count': 0,
          });
        }
        
        // Apply tag to file
        await db.insert('file_tags', {
          'id': const Uuid().v4(),
          'file_id': fileId,
          'tag_id': tagId,
          'created_at': now,
          'confidence': tagSuggestion.confidence,
          'source': autoApprove ? 'auto_approved' : 'auto_suggested',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        
        // Update tag usage count
        await db.rawUpdate(
          'UPDATE tags SET usage_count = usage_count + 1 WHERE id = ?',
          [tagId],
        );
      }

      // Apply themes
      for (final themeSuggestion in result.suggestedThemes) {
        String themeId = themeSuggestion.themeId;
        
        // Create new theme if needed
        if (themeSuggestion.source == 'new') {
          themeId = const Uuid().v4();
          await db.insert('themes', {
            'id': themeId,
            'name': themeSuggestion.themeName,
            'category': themeSuggestion.category,
            'description': themeSuggestion.description,
            'created_at': now,
            'usage_count': 0,
          });
        }
        
        // Apply theme to file
        await db.insert('file_themes', {
          'id': const Uuid().v4(),
          'file_id': fileId,
          'theme_id': themeId,
          'relevance_score': themeSuggestion.relevanceScore,
          'created_at': now,
          'source': autoApprove ? 'auto_approved' : 'auto_suggested',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        
        // Update theme usage count
        await db.rawUpdate(
          'UPDATE themes SET usage_count = usage_count + 1 WHERE id = ?',
          [themeId],
        );
      }
    } catch (e) {
      print('Error applying auto-tagging: $e');
      throw Exception('Failed to apply auto-tagging: $e');
    }
  }

  // Batch auto-tag multiple files
  Future<void> batchAutoTag(
    List<JournalFile> files, {
    bool autoApprove = false,
    Function(int current, int total)? progressCallback,
  }) async {
    if (!_isInitialized) await initialize();
    
    for (int i = 0; i < files.length; i++) {
      try {
        final result = await analyzeAndTagEntry(files[i]);
        if (result.suggestedTags.isNotEmpty || result.suggestedThemes.isNotEmpty) {
          await applyAutoTagging(files[i].id, result, autoApprove: autoApprove);
        }
        progressCallback?.call(i + 1, files.length);
      } catch (e) {
        print('Error in batch auto-tagging for file ${files[i].id}: $e');
      }
    }
  }

  // Get existing tags from database
  Future<List<Map<String, dynamic>>> _getExistingTags() async {
    final db = await _dbService.database;
    return await db.query('tags', orderBy: 'usage_count DESC');
  }

  // Get existing themes from database
  Future<List<Map<String, dynamic>>> _getExistingThemes() async {
    final db = await _dbService.database;
    return await db.query('themes', orderBy: 'usage_count DESC');
  }

  // Get auto-tagging statistics
  Future<Map<String, dynamic>> getAutoTaggingStats() async {
    final db = await _dbService.database;
    
    final tagStats = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_tags,
        COUNT(DISTINCT file_id) as tagged_files,
        AVG(confidence) as avg_confidence
      FROM file_tags 
      WHERE source LIKE 'auto%'
    ''');
    
    final themeStats = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_themes,
        COUNT(DISTINCT file_id) as themed_files,
        AVG(relevance_score) as avg_relevance
      FROM file_themes 
      WHERE source LIKE 'auto%'
    ''');
    
    return {
      'autoTags': tagStats.first['total_tags'] as int,
      'autoTaggedFiles': tagStats.first['tagged_files'] as int,
      'avgTagConfidence': tagStats.first['avg_confidence'] as double? ?? 0.0,
      'autoThemes': themeStats.first['total_themes'] as int,
      'autoThemedFiles': themeStats.first['themed_files'] as int,
      'avgThemeRelevance': themeStats.first['avg_relevance'] as double? ?? 0.0,
    };
  }

  // Get system prompt for auto-tagging
  String _getTaggingPrompt() {
    return '''
You are an expert content analyzer. Analyze the given journal entry and suggest relevant tags and themes.

Respond with ONLY a JSON object in this exact format:

{
  "tags": [
    {
      "name": "Personal",
      "confidence": 0.9,
      "description": "Personal thoughts and reflections"
    },
    {
      "name": "Goals",
      "confidence": 0.7,
      "description": "Goal setting and achievement"
    }
  ],
  "themes": [
    {
      "name": "Self-Discovery",
      "relevance": 0.8,
      "category": "Personal Growth",
      "description": "Exploring identity and personal insights"
    }
  ]
}

Guidelines:
- Suggest 2-5 relevant tags based on the content
- Suggest 1-3 themes that capture the main topics
- Tags should be concise (1-2 words)
- Themes can be longer phrases
- Confidence/relevance: 0.0 to 1.0
- Common tag categories: Personal, Work, Goals, Reflection, Gratitude, Learning, Ideas, Memories, Health, Relationships
- Common theme categories: Personal Growth, Professional, Social, Creative, Lifestyle, Future, Routine

Respond with ONLY the JSON object, no other text.
''';
  }

  // Parse AI response for tagging data
  Map<String, dynamic> _parseTaggingResponse(String response) {
    try {
      final cleanResponse = response.trim();
      final json = jsonDecode(cleanResponse);
      
      return {
        'tags': (json['tags'] as List?)?.map((tag) => {
          'name': tag['name'] as String? ?? 'Unknown',
          'confidence': (tag['confidence'] as num?)?.toDouble() ?? 0.5,
          'description': tag['description'] as String?,
        }).toList() ?? [],
        'themes': (json['themes'] as List?)?.map((theme) => {
          'name': theme['name'] as String? ?? 'Unknown',
          'relevance': (theme['relevance'] as num?)?.toDouble() ?? 0.5,
          'category': theme['category'] as String?,
          'description': theme['description'] as String?,
        }).toList() ?? [],
      };
    } catch (e) {
      print('Error parsing tagging response: $e');
      return {
        'tags': <Map<String, dynamic>>[],
        'themes': <Map<String, dynamic>>[],
      };
    }
  }

  // Generate a random color for new tags
  String _generateTagColor() {
    final colors = [
      '#4A90E2', // Blue
      '#F5A623', // Orange
      '#7ED321', // Green
      '#9013FE', // Purple
      '#FF6B6B', // Red
      '#4ECDC4', // Teal
      '#95E1D3', // Mint
      '#F38BA8', // Pink
      '#FFD93D', // Yellow
      '#6C5CE7', // Indigo
    ];
    return colors[DateTime.now().millisecondsSinceEpoch % colors.length];
  }

  void dispose() {
    _isInitialized = false;
  }
} 